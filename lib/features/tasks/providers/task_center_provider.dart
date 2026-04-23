import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/trip_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Due-date filter options
// ─────────────────────────────────────────────────────────────────────────────

enum DueDateFilter { overdue, today, thisWeek }

extension DueDateFilterLabel on DueDateFilter {
  String get label {
    switch (this) {
      case DueDateFilter.overdue:
        return 'Overdue';
      case DueDateFilter.today:
        return 'Due Today';
      case DueDateFilter.thisWeek:
        return 'This Week';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaskCenterProvider
// ─────────────────────────────────────────────────────────────────────────────

class TaskCenterProvider extends ChangeNotifier {
  final TaskRepository? _taskRepo;
  final TripRepository? _tripRepo;
  final String _teamId;
  final String? _currentUserId;

  List<Task> _allTasks = [];
  Map<String, Trip> _tripsById = {};
  bool isLoading = false;
  String? error;

  String _search = '';
  TaskStatus? _filterStatus;
  TaskPriority? _filterPriority;
  String? _filterTripId;
  DueDateFilter? _filterDueDate;

  StreamSubscription<List<Task>>? _tasksSub;

  TaskCenterProvider({
    required TaskRepository? taskRepo,
    required TripRepository? tripRepo,
    required String teamId,
    String? currentUserId,
  }) : _taskRepo = taskRepo,
       _tripRepo = tripRepo,
       _teamId = teamId,
       _currentUserId = currentUserId {
    _load();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  String get search => _search;
  TaskStatus? get filterStatus => _filterStatus;
  TaskPriority? get filterPriority => _filterPriority;
  String? get filterTripId => _filterTripId;
  DueDateFilter? get filterDueDate => _filterDueDate;
  Map<String, Trip> get tripsById => _tripsById;
  List<Trip> get allTrips => _tripsById.values.toList();

  bool get hasActiveFilters =>
      _search.isNotEmpty ||
      _filterStatus != null ||
      _filterPriority != null ||
      _filterTripId != null ||
      _filterDueDate != null;

  // ── Filter setters ─────────────────────────────────────────────────────────

  void setSearch(String v) {
    _search = v;
    notifyListeners();
  }

  void setFilterStatus(TaskStatus? v) {
    _filterStatus = v;
    notifyListeners();
  }

  void setFilterPriority(TaskPriority? v) {
    _filterPriority = v;
    notifyListeners();
  }

  void setFilterTripId(String? v) {
    _filterTripId = v;
    notifyListeners();
  }

  void setFilterDueDate(DueDateFilter? v) {
    _filterDueDate = v;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _filterStatus = null;
    _filterPriority = null;
    _filterTripId = null;
    _filterDueDate = null;
    notifyListeners();
  }

  // ── Derived views ──────────────────────────────────────────────────────────

  /// Tasks assigned to the current user, sorted by due date.
  List<Task> get myTasks =>
      _filtered().where((t) => t.assignedTo?.id == _currentUserId).toList()
        ..sort(_byDueDate);

  /// All tasks with a past due date and non-terminal status, sorted by due date.
  List<Task> get overdueTasks {
    final today = _todayStart();
    return _allTasks.where((t) {
      if (t.dueDate == null || _isTerminal(t.status)) return false;
      return t.dueDate!.isBefore(today);
    }).toList()..sort(_byDueDate);
  }

  /// Filtered tasks grouped by tripId, sorted by due date within each group.
  Map<String, List<Task>> get tasksByTrip {
    final result = <String, List<Task>>{};
    for (final t in _filtered()) {
      result.putIfAbsent(t.tripId ?? '__no_trip__', () => []).add(t);
    }
    for (final list in result.values) {
      list.sort(_byDueDate);
    }
    return result;
  }

  /// Filtered tasks grouped by status, in workflow order.
  Map<TaskStatus, List<Task>> get tasksByStatus {
    final result = <TaskStatus, List<Task>>{};
    for (final s in TaskStatus.values) {
      final tasks = _filtered().where((t) => t.status == s).toList()
        ..sort(_byDueDate);
      if (tasks.isNotEmpty) result[s] = tasks;
    }
    return result;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  List<Task> _filtered() {
    var tasks = _allTasks;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      tasks = tasks.where((t) {
        final tripName = t.tripId != null
            ? (_tripsById[t.tripId]?.name ?? '')
            : '';
        return t.name.toLowerCase().contains(q) ||
            tripName.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterStatus != null) {
      tasks = tasks.where((t) => t.status == _filterStatus).toList();
    }
    if (_filterPriority != null) {
      tasks = tasks.where((t) => t.priority == _filterPriority).toList();
    }
    if (_filterTripId != null) {
      tasks = tasks.where((t) => t.tripId == _filterTripId).toList();
    }
    if (_filterDueDate != null) {
      tasks = tasks
          .where((t) => _matchesDueFilter(t, _filterDueDate!))
          .toList();
    }

    return tasks;
  }

  bool _matchesDueFilter(Task t, DueDateFilter f) {
    if (t.dueDate == null) return false;
    final today = _todayStart();
    switch (f) {
      case DueDateFilter.overdue:
        return t.dueDate!.isBefore(today) && !_isTerminal(t.status);
      case DueDateFilter.today:
        final tomorrow = today.add(const Duration(days: 1));
        return !t.dueDate!.isBefore(today) && t.dueDate!.isBefore(tomorrow);
      case DueDateFilter.thisWeek:
        final nextWeek = today.add(const Duration(days: 7));
        return !t.dueDate!.isBefore(today) && t.dueDate!.isBefore(nextWeek);
    }
  }

  bool _isTerminal(TaskStatus s) =>
      s == TaskStatus.confirmed || s == TaskStatus.cancelled;

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _byDueDate(Task a, Task b) {
    if (a.dueDate == null && b.dueDate == null) return 0;
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  }

  Future<void> _load() async {
    isLoading = true;
    notifyListeners();
    try {
      final trips = await _tripRepo?.fetchAll(_teamId) ?? [];
      _tripsById = {for (final t in trips) t.id: t};
      _subscribeToTasks();
    } catch (_) {
      error = 'Could not load tasks.';
      isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToTasks() {
    _tasksSub?.cancel();
    if (_taskRepo == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    _tasksSub = _taskRepo
        .watchAllForTeam(_teamId)
        .listen(
          (tasks) {
            _allTasks = tasks;
            isLoading = false;
            error = null;
            notifyListeners();
          },
          onError: (_) {
            error = 'Could not load tasks.';
            isLoading = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
  }
}
