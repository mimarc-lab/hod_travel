import '../../data/models/scheduled_task_result.dart';
import '../../data/models/trip_complexity_profile.dart';
import '../../data/models/workflow_task_schedule_rule.dart';
import 'dependency_resolver.dart';
import 'duration_calculator.dart';
import 'planning_deadline_helper.dart';
import 'schedule_validator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HybridScheduleEngine
//
// Replaces BackwardPlanningService + WorkflowScheduleEngine.
//
// Algorithm (7 steps):
//   1. Compute planning_complete_by = tripStartDate − bufferDays
//   2. Compute effective duration per task:
//        effective = base + complexity_adjustment + buffer
//   3. Resolve execution order (phase ordering + dependency graph)
//   4. Schedule backward from planning_complete_by
//   5. Validate feasibility; produce human-readable warnings
//
// Parallel execution is implicit: tasks in the same phase that share no
// dependencies are not chained, so they overlap in wall-clock time.
// The cursor only advances for sequentially chained tasks.
// ─────────────────────────────────────────────────────────────────────────────

class HybridScheduleEngine {
  // ── Public entry points ────────────────────────────────────────────────────

  /// Used by [CreateTripScreen] with built-in or saved templates converted to maps.
  /// Each map must contain: 'group', 'title', 'priority', and optionally
  /// 'duration' (int), 'buffer_days' (int), 'scheduling_mode' (String),
  /// 'latest_finish_offset_days' (int), 'assignee_id' (String).
  static ScheduleAnalysis scheduleFromTemplateMaps({
    required List<Map<String, dynamic>> templateTasks,
    required DateTime tripStartDate,
    TripComplexityProfile complexity = const TripComplexityProfile(),
    int planningBufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) {
    final rules = templateTasks.asMap().entries.map((e) {
      final t = e.value;
      return WorkflowTaskScheduleRule(
        id:                     'builtin_${e.key}',
        groupName:              t['group']                    as String? ?? 'Logistics',
        title:                  t['title']                    as String? ?? '',
        priority:               t['priority']                 as String? ?? 'medium',
        sortOrder:              e.key,
        estimatedDurationDays:  t['duration']                 as int?    ?? 2,
        schedulingMode:         SchedulingMode.fromDb(
          t['scheduling_mode'] as String? ?? 'backward_from_deadline',
        ),
        bufferDays:             t['buffer_days']              as int?    ?? 0,
        latestFinishOffsetDays: t['latest_finish_offset_days'] as int?,
        dependencyTaskIds:      const [],
        defaultAssigneeId:      t['assignee_id']              as String?,
      );
    }).toList();

    return _run(
      rules:              rules,
      tripStartDate:      tripStartDate,
      complexity:         complexity,
      planningBufferDays: planningBufferDays,
    );
  }

  /// Used when scheduling from DB-saved custom templates
  /// ([WorkflowTaskScheduleRule] objects from [TripTemplateRepository]).
  static ScheduleAnalysis scheduleFromRules({
    required List<WorkflowTaskScheduleRule> rules,
    required DateTime tripStartDate,
    TripComplexityProfile complexity = const TripComplexityProfile(),
    int planningBufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) =>
      _run(
        rules:              rules,
        tripStartDate:      tripStartDate,
        complexity:         complexity,
        planningBufferDays: planningBufferDays,
      );

  // ── Core pipeline ──────────────────────────────────────────────────────────

  static ScheduleAnalysis _run({
    required List<WorkflowTaskScheduleRule> rules,
    required DateTime tripStartDate,
    required TripComplexityProfile complexity,
    required int planningBufferDays,
  }) {
    final planningStart    = PlanningDeadlineHelper.planningStart();
    final planningDeadline = PlanningDeadlineHelper.computeDeadline(
      tripStartDate,
      planningBufferDays,
    );

    if (rules.isEmpty) {
      return ScheduleAnalysis(
        tasks:            const [],
        planningStart:    planningStart,
        planningDeadline: planningDeadline,
        isPossible:       true,
        isCompressed:     false,
        availableDays:    PlanningDeadlineHelper.availableDays(planningDeadline),
        requiredDays:     0,
        warnings:         const [],
      );
    }

    // Step 2: Effective duration per task
    final durations = {
      for (final r in rules) r.id: DurationCalculator.compute(r, complexity),
    };

    // Step 3: Execution order
    final ordered = DependencyResolver.resolve(rules);

    // Step 4: Backward scheduling
    final results = _scheduleBackward(
      ordered:          ordered,
      durations:        durations,
      planningStart:    planningStart,
      planningDeadline: planningDeadline,
    );

    // Step 5: Validate + build analysis
    return ScheduleValidator.validate(
      tasks:            results,
      planningDeadline: planningDeadline,
      bufferDays:       planningBufferDays,
    );
  }

  // ── Backward scheduler ─────────────────────────────────────────────────────

  static List<ScheduledTaskResult> _scheduleBackward({
    required List<WorkflowTaskScheduleRule> ordered,
    required Map<String, DurationBreakdown> durations,
    required DateTime planningStart,
    required DateTime planningDeadline,
  }) {
    final built  = <ScheduledTaskResult>[];
    var   cursor = planningDeadline;

    // `ordered` arrives in phase-descending order (phase 4 → 1).
    // We walk it sequentially, moving the cursor backward for each task.
    // Tasks in the same phase that are topo-independent do NOT share the
    // cursor advance, so they naturally overlap (parallel execution).
    int? lastPhase;

    for (final task in ordered) {
      final breakdown = durations[task.id]!;
      final effective = breakdown.effectiveDays;
      final phase     = DependencyResolver.phaseFor(task.groupName);

      // Insert a 1-day phase gap when we cross a phase boundary
      if (lastPhase != null && phase != lastPhase) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      lastPhase = phase;

      final DateTime due;
      final DateTime start;

      if (task.schedulingMode == SchedulingMode.milestoneAligned &&
          task.latestFinishOffsetDays != null) {
        // Pin this task to a fixed offset from the deadline
        due   = planningDeadline
            .subtract(Duration(days: task.latestFinishOffsetDays!));
        start = due.subtract(Duration(days: effective - 1));
        // Milestone-pinned tasks do NOT advance the cursor
      } else {
        due    = cursor;
        start  = cursor.subtract(Duration(days: effective - 1));
        cursor = start.subtract(const Duration(days: 1));
      }

      final compressed = start.isBefore(planningStart);
      built.add(ScheduledTaskResult(
        templateTaskId:        task.id,
        groupName:             task.groupName,
        title:                 task.title,
        priority:              task.priority,
        sortOrder:             task.sortOrder,
        scheduledStartDate:    compressed ? planningStart : start,
        dueDate:               due,
        baseDurationDays:      breakdown.baseDays,
        complexityAdjDays:     breakdown.complexityDays,
        bufferDays:            breakdown.bufferDays,
        effectiveDurationDays: effective,
        isCompressed:          compressed,
        scheduleNote:          compressed
            ? 'Timeline compressed — start adjusted to today.'
            : null,
        defaultAssigneeId:     task.defaultAssigneeId,
      ));
    }

    // Reverse to chronological order (earliest task first).
    return built.reversed.toList();
  }
}
