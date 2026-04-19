// Output of the WorkflowScheduleEngine for a single task.

class ScheduledTaskResult {
  final String   templateTaskId;
  final String   groupName;
  final String   title;
  final String   priority;
  final int      sortOrder;
  final DateTime scheduledStartDate;
  final DateTime dueDate;
  final int      estimatedDurationDays;
  final bool     isCompressed;
  final String?  scheduleNote;

  const ScheduledTaskResult({
    required this.templateTaskId,
    required this.groupName,
    required this.title,
    required this.priority,
    required this.sortOrder,
    required this.scheduledStartDate,
    required this.dueDate,
    required this.estimatedDurationDays,
    this.isCompressed = false,
    this.scheduleNote,
  });
}

// Summary of an entire schedule computation.
class ScheduleAnalysis {
  final List<ScheduledTaskResult> tasks;
  final DateTime planningStart;
  final DateTime planningDeadline;
  final bool     isPossible;
  final bool     isCompressed;
  final int      availableDays;
  final int      requiredDays;
  final List<String> warnings;

  const ScheduleAnalysis({
    required this.tasks,
    required this.planningStart,
    required this.planningDeadline,
    required this.isPossible,
    required this.isCompressed,
    required this.availableDays,
    required this.requiredDays,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
