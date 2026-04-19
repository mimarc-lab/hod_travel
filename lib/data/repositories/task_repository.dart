import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_model.dart';
import '../models/board_group_model.dart';
import '../models/task_comment_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TeamActivityItem — a single entry in the team activity feed
// ─────────────────────────────────────────────────────────────────────────────

class TeamActivityItem {
  final AppUser actor;
  /// Human-readable verb phrase, e.g. "changed status on" / "created task".
  final String action;
  /// The subject, e.g. the task title.
  final String subject;
  final DateTime time;

  const TeamActivityItem({
    required this.actor,
    required this.action,
    required this.subject,
    required this.time,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TaskRepository {
  Future<List<BoardGroup>> fetchGroupsForTrip(String tripId);
  Future<Task> createTask(Task task, String tripId, String teamId);
  Future<Task> updateTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<List<TaskComment>> fetchComments(String taskId);
  Future<TaskComment> createComment(TaskComment comment);

  /// Fetches all tasks assigned to [userId] within a team — single query, no N+1.
  Future<List<Task>> fetchTasksForUser(String teamId, String userId);

  /// Fetches all tasks for the team — used by the Global Task Center.
  Future<List<Task>> fetchAllForTeam(String teamId);

  /// Realtime stream — emits all tasks for the team whenever any task changes.
  Stream<List<Task>> watchAllForTeam(String teamId);

  /// Realtime stream — emits refreshed board groups on any task change for this trip.
  Stream<List<BoardGroup>> watchGroupsForTrip(String tripId);

  /// Realtime stream — emits refreshed comments+activity whenever either table
  /// changes for [taskId]. Unsubscribes automatically when stream is cancelled.
  Stream<List<TaskComment>> watchComments(String taskId);

  /// Fetches the [limit] most recent activity events across all team tasks.
  /// Returns an empty list on error (silently degrades).
  Future<List<TeamActivityItem>> fetchRecentActivity(String teamId, {int limit = 10});
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

Task _taskFromRow(Map<String, dynamic> row, Map<String, AppUser> profiles) {
  final assigneeId = row['assigned_to'] as String?;
  return Task(
    id: row['id'] as String,
    tripId: row['trip_id'] as String?,
    teamId: row['team_id'] as String?,
    boardGroupId: row['board_group_id'] as String? ?? '',
    name: row['title'] as String,
    description: row['description'] as String?,
    category: row['category'] as String?,
    status: TaskStatusLabel.fromDb(row['status'] as String? ?? 'not_started'),
    priority: TaskPriorityLabel.fromDb(row['priority'] as String? ?? 'medium'),
    costStatus: TaskCostStatusLabel.fromDb(
      row['cost_status'] as String? ?? 'pending',
    ),
    assignedTo: assigneeId != null ? profiles[assigneeId] : null,
    destination: row['destination_city'] as String?,
    travelDate: row['travel_date'] != null
        ? DateTime.parse(row['travel_date'] as String)
        : null,
    dueDate: row['due_date'] != null
        ? DateTime.parse(row['due_date'] as String)
        : null,
    supplierId: row['supplier_id'] as String?,
    clientVisible: row['is_client_visible'] as bool? ?? false,
    approvalStatus: approvalStatusFromDb(row['approval_status'] as String? ?? 'draft'),
    estimatedDurationDays: row['estimated_duration_days'] as int?,
  );
}

Map<String, dynamic> _taskToRow(Task t, {String? tripId, String? teamId}) => {
  'trip_id': ?tripId,
  'team_id': ?teamId,
  'board_group_id': t.boardGroupId.isEmpty ? null : t.boardGroupId,
  'title': t.name,
  'description': t.description,
  'category': t.category,
  'status': t.status.dbValue,
  'priority': t.priority.dbValue,
  'assigned_to': t.assignedTo?.id,
  'destination_city': t.destination,
  'travel_date': t.travelDate?.toIso8601String().substring(0, 10),
  'due_date': t.dueDate?.toIso8601String().substring(0, 10),
  'supplier_id': t.supplierId,
  'cost_status': t.costStatus.dbValue,
  'is_client_visible': t.clientVisible,
  'approval_status': t.approvalStatus.dbValue,
  if (t.estimatedDurationDays != null)
    'estimated_duration_days': t.estimatedDurationDays,
};

// Default group names/colors live in board_group_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _client;
  SupabaseTaskRepository(this._client);

  @override
  Future<List<BoardGroup>> fetchGroupsForTrip(String tripId) async {
    final groupRows = await _client
        .from('board_groups')
        .select()
        .eq('trip_id', tripId)
        .order('sort_order');

    List groups = groupRows as List;

    // If no groups yet (trigger may not have run), create defaults
    if (groups.isEmpty) {
      await _createDefaultGroups(tripId);
      final fresh = await _client
          .from('board_groups')
          .select()
          .eq('trip_id', tripId)
          .order('sort_order');
      groups = fresh as List;
    }

    final taskRows = await _client
        .from('tasks')
        .select()
        .eq('trip_id', tripId)
        .order('sort_order');

    final profiles = await loadProfilesAsMap(_client);

    final tasksByGroup = <String, List<Task>>{};
    for (final r in taskRows as List) {
      final row = r as Map<String, dynamic>;
      final gId = row['board_group_id'] as String? ?? '';
      tasksByGroup.putIfAbsent(gId, () => []).add(_taskFromRow(row, profiles));
    }

    return groups.asMap().entries.map((e) {
      final g = e.value as Map<String, dynamic>;
      final gId = g['id'] as String;
      return BoardGroup(
        id: gId,
        name: g['name'] as String,
        accentColor: defaultBoardGroupColors[e.key % defaultBoardGroupColors.length],
        tasks: tasksByGroup[gId] ?? [],
      );
    }).toList();
  }

  Future<void> _createDefaultGroups(String tripId) async {
    final rows = defaultBoardGroupNames
        .asMap()
        .entries
        .map((e) => {'trip_id': tripId, 'name': e.value, 'sort_order': e.key})
        .toList();
    await _client.from('board_groups').insert(rows);
  }

  @override
  Future<Task> createTask(Task task, String tripId, String teamId) async {
    final row = await _client
        .from('tasks')
        .insert({
          ..._taskToRow(task, tripId: tripId, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    final profiles = await loadProfilesAsMap(_client);
    return _taskFromRow(row, profiles);
  }

  @override
  Future<Task> updateTask(Task task) async {
    final row = await _client
        .from('tasks')
        .update(_taskToRow(task))
        .eq('id', task.id)
        .select()
        .single();
    final profiles = await loadProfilesAsMap(_client);
    return _taskFromRow(row, profiles);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  @override
  Future<List<TaskComment>> fetchComments(String taskId) async {
    // Fetch user comments and system activity entries separately
    // task_comments = user messages, task_activities = system events
    final commentRows = await _client
        .from('task_comments')
        .select('*, profiles(id, full_name, email, avatar_url)')
        .eq('task_id', taskId)
        .order('created_at');

    final activityRows = await _client
        .from('task_activities')
        .select('*, profiles(id, full_name, email, avatar_url)')
        .eq('task_id', taskId)
        .order('created_at');

    // Profile data comes from the join above — no separate profiles fetch needed.
    AppUser resolveAuthor(String? authorId, Map<String, dynamic>? profileMap) {
      if (profileMap != null) {
        return ProfileRow.fromJson(profileMap).toAppUser();
      }
      return AppUser(
        id: authorId ?? 'system',
        name: 'System',
        initials: 'S',
        avatarColor: avatarColorFor(0),
        role: 'System',
      );
    }

    final comments = (commentRows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final authorId = row['author_id'] as String?;
      return TaskComment(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        author: resolveAuthor(
          authorId,
          row['profiles'] as Map<String, dynamic>?,
        ),
        message: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        isActivity: false,
      );
    }).toList();

    final activities = (activityRows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final actorId = row['actor_id'] as String?;
      return TaskComment(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        author: resolveAuthor(
          actorId,
          row['profiles'] as Map<String, dynamic>?,
        ),
        message: row['message'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        isActivity: true,
      );
    }).toList();

    // Merge and sort by createdAt
    final all = [...comments, ...activities];
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  @override
  Future<TaskComment> createComment(TaskComment comment) async {
    final row = await _client
        .from('task_comments')
        .insert({
          'task_id': comment.taskId,
          'author_id': comment.author.id,
          'body': comment.message,
        })
        .select()
        .single();

    return TaskComment(
      id: row['id'] as String,
      taskId: row['task_id'] as String,
      author: comment.author,
      message: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      isActivity: false,
    );
  }

  @override
  Future<List<Task>> fetchAllForTeam(String teamId) async {
    final taskRows = await _client
        .from('tasks')
        .select()
        .eq('team_id', teamId)
        .order('due_date', ascending: true, referencedTable: null);
    final profiles = await loadProfilesAsMap(_client);
    return (taskRows as List)
        .map((r) => _taskFromRow(r as Map<String, dynamic>, profiles))
        .toList();
  }

  @override
  Stream<List<Task>> watchAllForTeam(String teamId) {
    final controller = StreamController<List<Task>>.broadcast();

    Future<void> emit() async {
      try {
        final tasks = await fetchAllForTeam(teamId);
        if (!controller.isClosed) controller.add(tasks);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('tasks:team:$teamId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<List<Task>> fetchTasksForUser(String teamId, String userId) async {
    final taskRows = await _client
        .from('tasks')
        .select()
        .eq('team_id', teamId)
        .eq('assigned_to', userId)
        .order('due_date', ascending: true, referencedTable: null);
    final profiles = await loadProfilesAsMap(_client);
    return (taskRows as List)
        .map((r) => _taskFromRow(r as Map<String, dynamic>, profiles))
        .toList();
  }

  @override
  Stream<List<TaskComment>> watchComments(String taskId) {
    final controller = StreamController<List<TaskComment>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchComments(taskId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    // Single channel listening to both task_comments and task_activities —
    // halves the Supabase channel count vs two separate channels.
    final channel = _client
        .channel('task_feed:$taskId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: taskId,
          ),
          callback: (_) => emit(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'task_activities',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: taskId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ── Realtime ────────────────────────────────────────────────────────────────

  @override
  Stream<List<BoardGroup>> watchGroupsForTrip(String tripId) {
    final controller = StreamController<List<BoardGroup>>.broadcast();

    Future<void> emit() async {
      try {
        final groups = await fetchGroupsForTrip(tripId);
        if (!controller.isClosed) controller.add(groups);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('tasks:trip:$tripId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ── Team activity feed ─────────────────────────────────────────────────────

  @override
  Future<List<TeamActivityItem>> fetchRecentActivity(
    String teamId, {
    int limit = 10,
  }) async {
    try {
      // Join task_activities → tasks (inner, filters to team) → profiles
      final rows = await _client
          .from('task_activities')
          .select(
            'id, message, created_at, '
            'task:tasks!inner(title, team_id), '
            'actor:profiles!task_activities_actor_id_fkey(id, full_name, email, avatar_url)',
          )
          .eq('tasks.team_id', teamId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List).map((r) {
        final row       = r as Map<String, dynamic>;
        final taskMap   = row['task'] as Map<String, dynamic>?;
        final actorMap  = row['actor'] as Map<String, dynamic>?;
        final subject   = taskMap?['title'] as String? ?? 'a task';
        final message   = row['message'] as String? ?? 'updated';
        final createdAt = DateTime.parse(row['created_at'] as String);

        final AppUser actor;
        if (actorMap != null) {
          actor = ProfileRow.fromJson(actorMap).toAppUser();
        } else {
          actor = AppUser(
            id:          'system',
            name:        'System',
            initials:    'S',
            avatarColor: avatarColorFor(0),
            role:        '',
          );
        }

        return TeamActivityItem(
          actor:   actor,
          action:  message,
          subject: subject,
          time:    createdAt,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
