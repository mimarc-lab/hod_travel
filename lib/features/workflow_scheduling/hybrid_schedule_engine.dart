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
  //
  // Processes tasks PHASE BY PHASE (4 → 1).  Within each phase, tasks that
  // share no dependency run in PARALLEL — they all receive `due = phaseCursor`
  // and only the longest dependency chain (critical path) advances the cursor.
  //
  // This prevents the old bug where every task advanced the cursor, turning
  // parallel work into a sequential chain and inflating the total span.

  static List<ScheduledTaskResult> _scheduleBackward({
    required List<WorkflowTaskScheduleRule> ordered,
    required Map<String, DurationBreakdown> durations,
    required DateTime planningStart,
    required DateTime planningDeadline,
  }) {
    // Group tasks by phase while preserving topo order within each phase.
    // ordered already arrives phase-desc (4→1) from DependencyResolver.
    final phaseGroups = <int, List<WorkflowTaskScheduleRule>>{};
    for (final task in ordered) {
      (phaseGroups[DependencyResolver.phaseFor(task.groupName)] ??= [])
          .add(task);
    }

    final allResults = <ScheduledTaskResult>[];
    var   cursor     = planningDeadline;
    bool  firstPhase = true;

    for (int phase = 4; phase >= 1; phase--) {
      final phaseTasks = phaseGroups[phase];
      if (phaseTasks == null || phaseTasks.isEmpty) continue;

      // 1-day gap between phases (skip for the very first phase)
      if (!firstPhase) cursor = cursor.subtract(const Duration(days: 1));
      firstPhase = false;

      final result = _schedulePhase(
        phaseTasks:    phaseTasks,
        durations:     durations,
        phaseDue:      cursor,
        planningStart: planningStart,
        planningDeadline: planningDeadline,
      );

      allResults.addAll(result.results);
      // Cursor moves to the day before the earliest task start in this phase.
      cursor = result.earliestStart.subtract(const Duration(days: 1));
    }

    return allResults.reversed.toList();
  }

  // Schedules one phase's tasks with parallel execution.
  //
  // Algorithm (backward):
  //   1. Build a successor map (which tasks depend on task X).
  //   2. Walk tasks in reverse-topo order (leaves first).
  //      • Leaf (no in-phase successors): due = phaseDue.
  //      • Predecessor: due = earliest(successor.start) − 1.
  //   3. Cursor for the next phase = earliest task start in this phase.
  //
  // Result: parallel tasks share the same due date; only dependency chains
  // push predecessors further back — exactly the critical-path behaviour.
  static ({List<ScheduledTaskResult> results, DateTime earliestStart})
      _schedulePhase({
    required List<WorkflowTaskScheduleRule> phaseTasks,
    required Map<String, DurationBreakdown> durations,
    required DateTime phaseDue,
    required DateTime planningStart,
    required DateTime planningDeadline,
  }) {
    final phaseIds = {for (final t in phaseTasks) t.id};

    // successorsOf[X] = list of tasks in this phase that depend on X
    final successorsOf = <String, List<String>>{
      for (final t in phaseTasks) t.id: [],
    };
    for (final task in phaseTasks) {
      for (final depId in task.dependencyTaskIds) {
        if (phaseIds.contains(depId)) successorsOf[depId]!.add(task.id);
      }
    }

    // phaseTasks is topo-sorted roots-first; reversing gives leaves first.
    final dates = <String, ({DateTime start, DateTime due})>{};

    for (final task in phaseTasks.reversed) {
      final eff          = durations[task.id]!.effectiveDays;
      final mySuccessors = successorsOf[task.id]!
          .where((s) => dates.containsKey(s))
          .toList();

      final DateTime due;
      if (task.schedulingMode == SchedulingMode.milestoneAligned &&
          task.latestFinishOffsetDays != null) {
        due = planningDeadline
            .subtract(Duration(days: task.latestFinishOffsetDays!));
      } else if (mySuccessors.isEmpty) {
        due = phaseDue;
      } else {
        // Due the day before the earliest successor's start
        due = mySuccessors
            .map((s) => dates[s]!.start.subtract(const Duration(days: 1)))
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }

      dates[task.id] = (start: due.subtract(Duration(days: eff - 1)), due: due);
    }

    final earliestStart = dates.values
        .map((d) => d.start)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final results = phaseTasks.map((task) {
      final d          = dates[task.id]!;
      final bd         = durations[task.id]!;
      final compressed = d.start.isBefore(planningStart);
      return ScheduledTaskResult(
        templateTaskId:        task.id,
        groupName:             task.groupName,
        title:                 task.title,
        priority:              task.priority,
        sortOrder:             task.sortOrder,
        scheduledStartDate:    compressed ? planningStart : d.start,
        dueDate:               d.due,
        baseDurationDays:      bd.baseDays,
        complexityAdjDays:     bd.complexityDays,
        bufferDays:            bd.bufferDays,
        effectiveDurationDays: bd.effectiveDays,
        isCompressed:          compressed,
        scheduleNote:          compressed
            ? 'Timeline compressed — start adjusted to today.'
            : null,
        defaultAssigneeId:     task.defaultAssigneeId,
      );
    }).toList();

    return (results: results, earliestStart: earliestStart);
  }
}
