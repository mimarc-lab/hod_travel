import 'workflow_task_schedule_rule.dart';

// =============================================================================
// TripTemplate + TripTemplateTask
// =============================================================================

class TripTemplateTask {
  final String id;
  final String templateId;
  final String groupName;
  final String title;
  final String priority;
  final int    sortOrder;

  // ── Scheduling metadata ───────────────────────────────────────────────────
  final int            estimatedDurationDays;
  final SchedulingMode schedulingMode;
  final List<String>   dependencyTaskIds;
  final int            bufferDays;
  final int?           latestFinishOffsetDays;
  final int?           earliestStartOffsetDays;

  const TripTemplateTask({
    required this.id,
    required this.templateId,
    required this.groupName,
    required this.title,
    required this.priority,
    required this.sortOrder,
    this.estimatedDurationDays  = 2,
    this.schedulingMode         = SchedulingMode.backwardFromDeadline,
    this.dependencyTaskIds      = const [],
    this.bufferDays             = 0,
    this.latestFinishOffsetDays,
    this.earliestStartOffsetDays,
  });

  TripTemplateTask copyWith({
    String?        groupName,
    String?        title,
    String?        priority,
    int?           sortOrder,
    int?           estimatedDurationDays,
    SchedulingMode? schedulingMode,
    List<String>?  dependencyTaskIds,
    int?           bufferDays,
  }) =>
      TripTemplateTask(
        id:                    id,
        templateId:            templateId,
        groupName:             groupName             ?? this.groupName,
        title:                 title                 ?? this.title,
        priority:              priority              ?? this.priority,
        sortOrder:             sortOrder             ?? this.sortOrder,
        estimatedDurationDays: estimatedDurationDays ?? this.estimatedDurationDays,
        schedulingMode:        schedulingMode        ?? this.schedulingMode,
        dependencyTaskIds:     dependencyTaskIds     ?? this.dependencyTaskIds,
        bufferDays:            bufferDays            ?? this.bufferDays,
        latestFinishOffsetDays:  latestFinishOffsetDays,
        earliestStartOffsetDays: earliestStartOffsetDays,
      );
}

class TripTemplate {
  final String id;
  final String teamId;
  final String name;
  final String? description;
  final List<TripTemplateTask> tasks;
  final DateTime createdAt;

  const TripTemplate({
    required this.id,
    required this.teamId,
    required this.name,
    this.description,
    required this.tasks,
    required this.createdAt,
  });

  int get taskCount => tasks.length;

  List<TripTemplateTask> tasksForGroup(String groupName) =>
      tasks.where((t) => t.groupName == groupName).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
