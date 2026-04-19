// Scheduling metadata for a single template task.
// Used as input to WorkflowScheduleEngine.

enum SchedulingMode {
  backwardFromDeadline,
  sequentialAfterDependency,
  earlyPhaseTask,
  milestoneAligned;

  String get dbValue => switch (this) {
    backwardFromDeadline      => 'backward_from_deadline',
    sequentialAfterDependency => 'sequential_after_dependency',
    earlyPhaseTask            => 'early_phase_task',
    milestoneAligned          => 'milestone_aligned',
  };

  static SchedulingMode fromDb(String v) => switch (v) {
    'sequential_after_dependency' => SchedulingMode.sequentialAfterDependency,
    'early_phase_task'            => SchedulingMode.earlyPhaseTask,
    'milestone_aligned'           => SchedulingMode.milestoneAligned,
    _                             => SchedulingMode.backwardFromDeadline,
  };
}

class WorkflowTaskScheduleRule {
  final String id;           // templateTaskId
  final String groupName;
  final String title;
  final String priority;
  final int    sortOrder;
  final int    estimatedDurationDays;
  final SchedulingMode schedulingMode;
  final List<String>   dependencyTaskIds;
  final int            bufferDays;
  final int?           latestFinishOffsetDays;
  final int?           earliestStartOffsetDays;
  final String?        defaultAssigneeId;

  const WorkflowTaskScheduleRule({
    required this.id,
    required this.groupName,
    required this.title,
    required this.priority,
    required this.sortOrder,
    this.estimatedDurationDays  = 1,
    this.schedulingMode         = SchedulingMode.backwardFromDeadline,
    this.dependencyTaskIds      = const [],
    this.bufferDays             = 0,
    this.latestFinishOffsetDays,
    this.earliestStartOffsetDays,
    this.defaultAssigneeId,
  });
}
