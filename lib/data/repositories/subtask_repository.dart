import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subtask.dart';
import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SubtaskRepository {
  Future<List<Subtask>>         fetchSubtasks(String taskId);
  Stream<List<Subtask>>         watchSubtasks(String taskId);
  Future<Subtask>               createSubtask(Subtask subtask);
  Future<Subtask>               updateSubtask(Subtask subtask);
  Future<void>                  deleteSubtask(String subtaskId);
  Future<void>                  reorderSubtasks(List<({String id, int orderIndex})> updates);
  Future<List<SubtaskTemplate>> fetchTemplatesForType(String taskType);
  Future<List<SubtaskTemplate>> fetchAllTemplates();
  Future<List<SubtaskTemplate>> fetchTemplatesForTemplateTask(String templateTaskId);
  Future<List<SubtaskTemplate>> fetchTemplatesForTemplateTaskIds(List<String> templateTaskIds);
  Future<SubtaskTemplate>       createTemplate({required String taskType, required String title, required int orderIndex});
  Future<SubtaskTemplate>       createTemplateForTask({required String templateTaskId, required String title, required int orderIndex});
  Future<SubtaskTemplate>       updateTemplate(SubtaskTemplate template);
  Future<void>                  deleteTemplate(String templateId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

Subtask _subtaskFromRow(Map<String, dynamic> row, Map<String, AppUser> profiles) {
  final assigneeId = row['assigned_to'] as String?;
  return Subtask(
    id:           row['id']             as String,
    parentTaskId: row['parent_task_id'] as String,
    teamId:       row['team_id']        as String,
    title:        row['title']          as String,
    isCompleted:  row['is_completed']   as bool? ?? false,
    assignedTo:   assigneeId != null ? profiles[assigneeId] : null,
    orderIndex:   row['order_index']    as int?  ?? 0,
    createdAt:    DateTime.parse(row['created_at'] as String),
  );
}

Map<String, dynamic> _subtaskToRow(Subtask s) => {
  'parent_task_id': s.parentTaskId,
  'team_id':        s.teamId,
  'title':          s.title,
  'is_completed':   s.isCompleted,
  'assigned_to':    s.assignedTo?.id,
  'order_index':    s.orderIndex,
};

SubtaskTemplate _templateFromRow(Map<String, dynamic> row) => SubtaskTemplate(
  id:                 row['id']                    as String,
  taskType:           row['task_type']             as String?,
  tripTemplateTaskId: row['trip_template_task_id'] as String?,
  title:              row['title']                 as String,
  orderIndex:         row['order_index']           as int? ?? 0,
);

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseSubtaskRepository implements SubtaskRepository {
  final SupabaseClient _client;
  SupabaseSubtaskRepository(this._client);

  // ── Profile cache helper ──────────────────────────────────────────────────

  Future<Map<String, AppUser>> _profiles() async {
    final rows = await _client.from('profiles').select('id, full_name, email, avatar_url');
    return {
      for (final r in rows)
        r['id'] as String: AppUser(
          id:          r['id']        as String,
          name:        r['full_name'] as String? ?? 'Unknown',
          initials:    _initials(r['full_name'] as String? ?? '?'),
          avatarColor: avatarColorFor(0),
          role:        '',
        ),
    };
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  @override
  Future<List<Subtask>> fetchSubtasks(String taskId) async {
    final rows     = await _client
        .from('subtasks')
        .select()
        .eq('parent_task_id', taskId)
        .order('order_index');
    final profiles = await _profiles();
    return rows.map((r) => _subtaskFromRow(r, profiles)).toList();
  }

  @override
  Stream<List<Subtask>> watchSubtasks(String taskId) {
    final controller = StreamController<List<Subtask>>.broadcast();

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        final subtasks = await fetchSubtasks(taskId);
        if (!controller.isClosed) controller.add(subtasks);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Initial fetch
    emit();

    // Realtime subscription
    final channel = _client
        .channel('subtasks:$taskId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'subtasks',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'parent_task_id',
            value:  taskId,
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
  Future<Subtask> createSubtask(Subtask subtask) async {
    final row      = await _client.from('subtasks').insert(_subtaskToRow(subtask)).select().single();
    final profiles = await _profiles();
    return _subtaskFromRow(row, profiles);
  }

  @override
  Future<Subtask> updateSubtask(Subtask subtask) async {
    final row = await _client
        .from('subtasks')
        .update(_subtaskToRow(subtask))
        .eq('id', subtask.id)
        .select()
        .single();
    final profiles = await _profiles();
    return _subtaskFromRow(row, profiles);
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    await _client.from('subtasks').delete().eq('id', subtaskId);
  }

  @override
  Future<void> reorderSubtasks(List<({String id, int orderIndex})> updates) async {
    for (final u in updates) {
      await _client.from('subtasks').update({'order_index': u.orderIndex}).eq('id', u.id);
    }
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  @override
  Future<List<SubtaskTemplate>> fetchTemplatesForType(String taskType) async {
    final rows = await _client
        .from('subtask_templates')
        .select()
        .eq('task_type', taskType)
        .order('order_index');
    return rows.map(_templateFromRow).toList();
  }

  @override
  Future<List<SubtaskTemplate>> fetchAllTemplates() async {
    final rows = await _client
        .from('subtask_templates')
        .select()
        .order('task_type')
        .order('order_index');
    return rows.map(_templateFromRow).toList();
  }

  @override
  Future<List<SubtaskTemplate>> fetchTemplatesForTemplateTask(String templateTaskId) async {
    final rows = await _client
        .from('subtask_templates')
        .select()
        .eq('trip_template_task_id', templateTaskId)
        .order('order_index');
    return rows.map(_templateFromRow).toList();
  }

  @override
  Future<List<SubtaskTemplate>> fetchTemplatesForTemplateTaskIds(List<String> templateTaskIds) async {
    if (templateTaskIds.isEmpty) return [];
    final rows = await _client
        .from('subtask_templates')
        .select()
        .inFilter('trip_template_task_id', templateTaskIds)
        .order('order_index');
    return rows.map(_templateFromRow).toList();
  }

  @override
  Future<SubtaskTemplate> createTemplate({
    required String taskType,
    required String title,
    required int orderIndex,
  }) async {
    final row = await _client.from('subtask_templates').insert({
      'task_type':   taskType,
      'title':       title,
      'order_index': orderIndex,
    }).select().single();
    return _templateFromRow(row);
  }

  @override
  Future<SubtaskTemplate> createTemplateForTask({
    required String templateTaskId,
    required String title,
    required int orderIndex,
  }) async {
    final row = await _client.from('subtask_templates').insert({
      'trip_template_task_id': templateTaskId,
      'title':                 title,
      'order_index':           orderIndex,
    }).select().single();
    return _templateFromRow(row);
  }

  @override
  Future<SubtaskTemplate> updateTemplate(SubtaskTemplate template) async {
    final row = await _client
        .from('subtask_templates')
        .update({'title': template.title, 'order_index': template.orderIndex})
        .eq('id', template.id)
        .select()
        .single();
    return _templateFromRow(row);
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    await _client.from('subtask_templates').delete().eq('id', templateId);
  }
}
