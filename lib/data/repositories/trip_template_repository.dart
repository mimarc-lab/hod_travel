import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_template_model.dart';
import '../models/workflow_task_schedule_rule.dart';

// =============================================================================
// TripTemplateRepository
// =============================================================================

abstract class TripTemplateRepository {
  Future<List<TripTemplate>> fetchAll(String teamId);
  Future<TripTemplate> create({
    required String teamId,
    required String userId,
    required String name,
    String? description,
  });
  Future<void> updateName({required String id, required String name, String? description});
  Future<void> delete(String id);

  // Task operations
  Future<TripTemplateTask> addTask({
    required String templateId,
    required String groupName,
    required String title,
    required String priority,
    required int sortOrder,
    int estimatedDurationDays = 1,
    String? defaultAssigneeId,
    List<String> defaultCollaboratorIds = const [],
  });
  Future<void> updateTask(TripTemplateTask task);
  Future<void> deleteTask(String taskId);
  Future<void> reorderTasks(List<TripTemplateTask> tasks);
}

// =============================================================================
// Supabase implementation
// =============================================================================

class SupabaseTripTemplateRepository implements TripTemplateRepository {
  final SupabaseClient _client;
  SupabaseTripTemplateRepository(this._client);

  // ── Mappers ─────────────────────────────────────────────────────────────────

  static TripTemplateTask _taskFromRow(Map<String, dynamic> r) =>
      TripTemplateTask(
        id:         r['id']         as String,
        templateId: r['template_id'] as String,
        groupName:  r['group_name'] as String,
        title:      r['title']      as String,
        priority:   r['priority']   as String? ?? 'medium',
        sortOrder:  (r['sort_order'] as num?)?.toInt() ?? 0,
        defaultAssigneeId: r['default_assignee_id'] as String?,
        defaultCollaboratorIds: (r['default_collaborator_ids'] as List?)
            ?.map((e) => e as String).toList() ?? const [],
        estimatedDurationDays: (r['estimated_duration_days'] as num?)?.toInt() ?? 1,
        schedulingMode: SchedulingMode.values.firstWhere(
          (m) => m.name == _toCamel(r['scheduling_mode'] as String? ?? ''),
          orElse: () => SchedulingMode.backwardFromDeadline,
        ),
        dependencyTaskIds: (r['dependency_task_ids'] as List?)
            ?.map((e) => e as String).toList() ?? const [],
        bufferDays: (r['buffer_days'] as num?)?.toInt() ?? 0,
        latestFinishOffsetDays:  (r['latest_finish_offset_days']  as num?)?.toInt(),
        earliestStartOffsetDays: (r['earliest_start_offset_days'] as num?)?.toInt(),
      );

  // DB stores snake_case scheduling_mode values; convert to camelCase for enum lookup
  static String _toCamel(String snake) {
    if (snake.isEmpty) return snake;
    final parts = snake.split('_');
    return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static TripTemplate _templateFromRow(
      Map<String, dynamic> r, List<TripTemplateTask> tasks) =>
      TripTemplate(
        id:          r['id']          as String,
        teamId:      r['team_id']     as String,
        name:        r['name']        as String,
        description: r['description'] as String?,
        tasks:       tasks,
        createdAt:   DateTime.parse(r['created_at'] as String),
      );

  // ── Fetch ────────────────────────────────────────────────────────────────────

  @override
  Future<List<TripTemplate>> fetchAll(String teamId) async {
    final templateRows = await _client
        .from('trip_templates')
        .select()
        .eq('team_id', teamId)
        .order('created_at') as List;

    if (templateRows.isEmpty) return [];

    final ids = templateRows.map((r) => (r as Map)['id'] as String).toList();
    final taskRows = await _client
        .from('trip_template_tasks')
        .select()
        .inFilter('template_id', ids)
        .order('sort_order') as List;

    final tasksByTemplate = <String, List<TripTemplateTask>>{};
    for (final r in taskRows) {
      final row  = r as Map<String, dynamic>;
      final tid  = row['template_id'] as String;
      tasksByTemplate.putIfAbsent(tid, () => []).add(_taskFromRow(row));
    }

    return templateRows.map((r) {
      final row = r as Map<String, dynamic>;
      return _templateFromRow(row, tasksByTemplate[row['id']] ?? []);
    }).toList();
  }

  // ── Create ───────────────────────────────────────────────────────────────────

  @override
  Future<TripTemplate> create({
    required String teamId,
    required String userId,
    required String name,
    String? description,
  }) async {
    final row = await _client.from('trip_templates').insert({
      'team_id':     teamId,
      'created_by':  userId,
      'name':        name,
      'description': description,
    }).select().single();
    return _templateFromRow(row, []);
  }

  // ── Update ───────────────────────────────────────────────────────────────────

  @override
  Future<void> updateName({
    required String id,
    required String name,
    String? description,
  }) async {
    await _client.from('trip_templates').update({
      'name':        name,
      'description': description,
      'updated_at':  DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  @override
  Future<void> delete(String id) async {
    // Tasks cascade via FK
    await _client.from('trip_templates').delete().eq('id', id);
  }

  // ── Task operations ──────────────────────────────────────────────────────────

  @override
  Future<TripTemplateTask> addTask({
    required String templateId,
    required String groupName,
    required String title,
    required String priority,
    required int sortOrder,
    int estimatedDurationDays = 1,
    String? defaultAssigneeId,
    List<String> defaultCollaboratorIds = const [],
  }) async {
    final row = await _client.from('trip_template_tasks').insert({
      'template_id':              templateId,
      'group_name':               groupName,
      'title':                    title,
      'priority':                 priority,
      'sort_order':               sortOrder,
      'estimated_duration_days':  estimatedDurationDays,
      'default_assignee_id':      defaultAssigneeId,
      'default_collaborator_ids': defaultCollaboratorIds,
    }).select().single();
    return _taskFromRow(row);
  }

  @override
  Future<void> updateTask(TripTemplateTask task) async {
    await _client.from('trip_template_tasks').update({
      'group_name':               task.groupName,
      'title':                    task.title,
      'priority':                 task.priority,
      'sort_order':               task.sortOrder,
      'default_assignee_id':         task.defaultAssigneeId,
      'default_collaborator_ids':    task.defaultCollaboratorIds,
      'estimated_duration_days':     task.estimatedDurationDays,
      'scheduling_mode':          _toSnake(task.schedulingMode.name),
      'dependency_task_ids':      task.dependencyTaskIds,
      'buffer_days':              task.bufferDays,
      'latest_finish_offset_days':  task.latestFinishOffsetDays,
      'earliest_start_offset_days': task.earliestStartOffsetDays,
    }).eq('id', task.id);
  }

  static String _toSnake(String camel) => camel.replaceAllMapped(
        RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');

  @override
  Future<void> deleteTask(String taskId) async {
    await _client.from('trip_template_tasks').delete().eq('id', taskId);
  }

  @override
  Future<void> reorderTasks(List<TripTemplateTask> tasks) async {
    for (var i = 0; i < tasks.length; i++) {
      await _client.from('trip_template_tasks')
          .update({'sort_order': i})
          .eq('id', tasks[i].id);
    }
  }
}
