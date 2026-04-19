import '../../data/models/workflow_task_schedule_rule.dart';
import '../../data/models/scheduled_task_result.dart';
import 'planning_deadline_helper.dart';
import 'workflow_schedule_engine.dart';
import 'schedule_conflict_detector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BackwardPlanningService
//
// Entry point for the scheduling engine.
// Call during trip creation to auto-schedule template tasks.
// ─────────────────────────────────────────────────────────────────────────────

class BackwardPlanningService {
  // Schedules tasks from built-in template maps (trip_templates.dart).
  // Each map must have: 'group', 'title', 'priority', 'duration' (int).
  static ScheduleAnalysis scheduleFromTemplateMaps({
    required List<Map<String, dynamic>> templateTasks,
    required DateTime tripStartDate,
    int planningBufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) {
    final rules = templateTasks.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      return WorkflowTaskScheduleRule(
        id:                    'builtin_$i',
        groupName:             t['group']           as String? ?? 'Logistics',
        title:                 t['title']           as String? ?? '',
        priority:              t['priority']        as String? ?? 'medium',
        sortOrder:             i,
        estimatedDurationDays: t['duration']        as int?    ?? 2,
        schedulingMode:        SchedulingMode.fromDb(
          t['scheduling_mode'] as String? ?? 'backward_from_deadline',
        ),
        bufferDays:             t['buffer_days']               as int? ?? 0,
        latestFinishOffsetDays: t['latest_finish_offset_days'] as int?,
        dependencyTaskIds:      const [],
      );
    }).toList();

    return _run(
      rules:              rules,
      tripStartDate:      tripStartDate,
      planningBufferDays: planningBufferDays,
    );
  }

  // Schedules tasks from explicit WorkflowTaskScheduleRule objects (DB templates).
  static ScheduleAnalysis scheduleFromRules({
    required List<WorkflowTaskScheduleRule> rules,
    required DateTime tripStartDate,
    int planningBufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) =>
      _run(
        rules:              rules,
        tripStartDate:      tripStartDate,
        planningBufferDays: planningBufferDays,
      );

  static ScheduleAnalysis _run({
    required List<WorkflowTaskScheduleRule> rules,
    required DateTime tripStartDate,
    required int planningBufferDays,
  }) {
    final planningStart    = PlanningDeadlineHelper.planningStart();
    final planningDeadline = PlanningDeadlineHelper.computeDeadline(
      tripStartDate,
      planningBufferDays,
    );

    final tasks = WorkflowScheduleEngine.compute(
      rules:            rules,
      planningStart:    planningStart,
      planningDeadline: planningDeadline,
    );

    return ScheduleConflictDetector.analyze(
      tasks:            tasks,
      planningDeadline: planningDeadline,
      bufferDays:       planningBufferDays,
    );
  }
}
