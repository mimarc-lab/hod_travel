import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/board_group_model.dart';
import '../../../data/models/task_comment_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/task_repository.dart';

/// Holds all mutable board state for one trip.
/// Consumed via ListenableBuilder — no external package required.
///
/// Realtime strategy:
///   • [watchGroupsForTrip] — streams board groups whenever any task in the
///     trip changes; replaces the full group list on each emission.
///   • [watchComments] — streams comments+activity for the selected task;
///     subscription is created/replaced whenever [selectTask] is called and
///     cancelled when [clearSelection] is called.
class BoardProvider extends ChangeNotifier {
  final Trip trip;
  final TaskRepository? _repo;
  final String? _teamId;
  final String? _currentUserId;

  List<BoardGroup> _groups = [];
  List<AppUser> _members = [];
  Task? _selectedTask;
  String? _pendingInitialTaskId;
  final Map<String, List<TaskComment>> _comments = {};
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<BoardGroup>>? _groupsSub;
  StreamSubscription<List<TaskComment>>? _commentsSub;

  BoardProvider(
    this.trip, {
    TaskRepository? repository,
    String? teamId,
    String? currentUserId,
    String? initialTaskId,
  })  : _repo = repository,
        _teamId = teamId,
        _currentUserId = currentUserId,
        _pendingInitialTaskId = initialTaskId {
    _subscribeToBoard();
    _loadMembers();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<BoardGroup> get groups  => _groups;
  List<AppUser>    get members => _members;
  Task? get selectedTask       => _selectedTask;
  bool get isLoading           => _isLoading;
  String? get error            => _error;

  // ── Board subscription ────────────────────────────────────────────────────

  void _subscribeToBoard() {
    if (_repo == null) return;
    _isLoading = true;
    notifyListeners();
    _groupsSub?.cancel();
    _groupsSub = _repo.watchGroupsForTrip(trip.id).listen(
      (groups) {
        _groups = groups;
        _isLoading = false;
        _error = null;
        // Keep selected task in sync with fresh data
        if (_selectedTask != null) {
          final allTasks = groups.expand((g) => g.tasks);
          _selectedTask = allTasks.cast<Task?>().firstWhere(
            (t) => t?.id == _selectedTask!.id,
            orElse: () => null,
          );
        }
        // Auto-select task requested by Task Center deep-link (consumed once)
        if (_pendingInitialTaskId != null && _selectedTask == null) {
          final allTasks = groups.expand((g) => g.tasks);
          _selectedTask = allTasks.cast<Task?>().firstWhere(
            (t) => t?.id == _pendingInitialTaskId,
            orElse: () => null,
          );
          if (_selectedTask != null) {
            _subscribeToComments(_selectedTask!.id);
            _pendingInitialTaskId = null;
          }
        }
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load board data.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _groupsSub?.cancel();
    _subscribeToBoard();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final repos = AppRepositories.instance;
    if (repos == null || _teamId == null) return;
    try {
      final teamMembers = await repos.teams.fetchMembers(_teamId);
      _members = teamMembers
          .where((m) => m.profile != null)
          .map((m) => m.profile!)
          .toList();
      notifyListeners();
    } catch (_) {
      // Non-fatal: assignee list just stays empty
    }
  }

  // ── Task selection ────────────────────────────────────────────────────────

  void selectTask(Task task) {
    _selectedTask = task;
    notifyListeners();
    _subscribeToComments(task.id);
  }

  void clearSelection() {
    _selectedTask = null;
    _commentsSub?.cancel();
    _commentsSub = null;
    notifyListeners();
  }

  // ── Comment subscription ──────────────────────────────────────────────────

  void _subscribeToComments(String taskId) {
    _commentsSub?.cancel();
    if (_repo == null) return;
    _commentsSub = _repo.watchComments(taskId).listen((comments) {
      _comments[taskId] = comments;
      notifyListeners();
    });
  }

  // ── Task CRUD ─────────────────────────────────────────────────────────────

  Future<void> createTask(Task task) async {
    if (_repo == null || _teamId == null) return;
    // Optimistic insert — append to the target group immediately so the
    // row appears without waiting for the realtime subscription to fire.
    _groups = _groups.map((g) {
      if (g.id != task.boardGroupId) return g;
      return BoardGroup(
        id: g.id, name: g.name, accentColor: g.accentColor,
        tasks: [...g.tasks, task],
      );
    }).toList();
    notifyListeners();
    try {
      final saved = await _repo.createTask(task, trip.id, _teamId);
      // Swap the optimistic placeholder (id='') with the real DB task.
      _groups = _groups.map((g) {
        if (g.id != saved.boardGroupId) return g;
        return BoardGroup(
          id: g.id, name: g.name, accentColor: g.accentColor,
          tasks: g.tasks
              .map((t) => t.id == task.id ? saved : t)
              .toList(),
        );
      }).toList();
      notifyListeners();
    } catch (_) {
      // Rollback the optimistic entry.
      _groups = _groups.map((g) {
        if (g.id != task.boardGroupId) return g;
        return BoardGroup(
          id: g.id, name: g.name, accentColor: g.accentColor,
          tasks: g.tasks.where((t) => t.id != task.id).toList(),
        );
      }).toList();
      _error = 'Could not create task.';
      notifyListeners();
    }
  }

  void updateTask(Task updated) {
    // Apply optimistically; realtime will confirm/reconcile
    _applyTaskUpdate(updated);
    _repo?.updateTask(updated).catchError((e) {
      _error = 'Could not update task.';
      notifyListeners();
      return updated;
    });
  }

  void _applyTaskUpdate(Task updated) {
    _groups = _groups.map((g) {
      if (g.id != updated.boardGroupId) return g;
      return BoardGroup(
        id: g.id, name: g.name, accentColor: g.accentColor,
        tasks: g.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
      );
    }).toList();
    if (_selectedTask?.id == updated.id) _selectedTask = updated;
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    if (_repo == null) return;
    // Optimistic: remove the task immediately so the UI updates without
    // waiting for the realtime subscription to fire.
    final prevGroups = List<BoardGroup>.from(_groups);
    _groups = [
      for (final g in _groups)
        BoardGroup(
          id:          g.id,
          name:        g.name,
          accentColor: g.accentColor,
          tasks:       g.tasks.where((t) => t.id != taskId).toList(),
        ),
    ];
    if (_selectedTask?.id == taskId) _selectedTask = null;
    notifyListeners();
    try {
      await _repo.deleteTask(taskId);
      // Realtime will confirm — nothing further needed.
    } catch (_) {
      // Rollback on failure.
      _groups = prevGroups;
      _error = 'Could not delete task.';
      notifyListeners();
    }
  }

  // ── Higher-level helpers — update + auto-log activity ─────────────────────

  void updateTaskStatus(Task task, TaskStatus newStatus) {
    _logActivity(task.id, 'Status changed to "${newStatus.label}"');
    updateTask(task.copyWith(status: newStatus));
  }

  void updateTaskPriority(Task task, TaskPriority priority) {
    _logActivity(task.id, 'Priority set to "${priority.label}"');
    updateTask(task.copyWith(priority: priority));
  }

  void updateTaskApproval(Task task, ApprovalStatus status) {
    final msg = switch (status) {
      ApprovalStatus.pendingReview => 'Submitted for review',
      ApprovalStatus.approved      => 'Approved',
      ApprovalStatus.rejected      => 'Rejected',
      ApprovalStatus.draft         => 'Returned to draft',
    };
    _logActivity(task.id, msg);
    updateTask(task.copyWith(approvalStatus: status));
  }

  void updateTaskAssignee(Task task, AppUser? user) {
    final msg = user != null ? 'Assigned to ${user.name}' : 'Removed assignee';
    _logActivity(task.id, msg);
    updateTask(task.copyWith(
      assignedTo: user,
      clearAssignedTo: user == null,
    ));
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  List<TaskComment> commentsFor(String taskId) =>
      List.unmodifiable(_comments[taskId] ?? []);

  void addComment(String taskId, String message) {
    if (message.trim().isEmpty) return;

    final author = _resolveCurrentUser();
    final comment = TaskComment(
      id:        'c${DateTime.now().millisecondsSinceEpoch}',
      taskId:    taskId,
      author:    author,
      message:   message.trim(),
      createdAt: DateTime.now(),
      isActivity: false,
    );
    // Optimistic add — realtime subscription will deliver the persisted version
    _comments[taskId] = [...(_comments[taskId] ?? []), comment];
    notifyListeners();

    _repo?.createComment(comment).catchError((_) => comment);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _logActivity(String taskId, String message) {
    final entry = TaskComment(
      id:        'a${DateTime.now().millisecondsSinceEpoch}',
      taskId:    taskId,
      author:    _resolveCurrentUser(),
      message:   message,
      createdAt: DateTime.now(),
      isActivity: true,
    );
    _comments[taskId] = [...(_comments[taskId] ?? []), entry];
    // caller notifies via updateTask*
  }

  AppUser _resolveCurrentUser() {
    return AppRepositories.instance?.currentAppUser ??
        AppUser(
          id:          _currentUserId ?? 'anon',
          name:        'You',
          initials:    'Y',
          avatarColor: avatarColorFor(0),
          role:        'Staff',
        );
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    _commentsSub?.cancel();
    super.dispose();
  }
}
