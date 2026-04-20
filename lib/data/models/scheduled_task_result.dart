/// Output of the HybridScheduleEngine for a single task.
class ScheduledTaskResult {
  final String   templateTaskId;
  final String   groupName;
  final String   title;
  final String   priority;
  final int      sortOrder;
  final DateTime scheduledStartDate;
  final DateTime dueDate;

  // ── Duration breakdown ─────────────────────────────────────────────────────
  final int baseDurationDays;      // from task template (or group fallback)
  final int complexityAdjDays;     // added by ComplexityRules
  final int bufferDays;            // from task.bufferDays
  final int effectiveDurationDays; // = base + complexityAdj + buffer

  /// Legacy alias kept so existing DB-write code requires no change.
  int get estimatedDurationDays => effectiveDurationDays;

  final bool     isCompressed;
  final String?  scheduleNote;
  final String?  defaultAssigneeId;

  const ScheduledTaskResult({
    required this.templateTaskId,
    required this.groupName,
    required this.title,
    required this.priority,
    required this.sortOrder,
    required this.scheduledStartDate,
    required this.dueDate,
    required this.effectiveDurationDays,
    this.baseDurationDays     = 0,
    this.complexityAdjDays    = 0,
    this.bufferDays           = 0,
    this.isCompressed         = false,
    this.scheduleNote,
    this.defaultAssigneeId,
  });
}

// ── ScheduleAnalysis ──────────────────────────────────────────────────────────

/// Summary of an entire schedule computation.
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
