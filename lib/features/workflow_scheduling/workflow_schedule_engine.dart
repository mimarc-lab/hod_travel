import '../../data/models/workflow_task_schedule_rule.dart';
import '../../data/models/scheduled_task_result.dart';

// Phase assignment — lower number = earlier in the planning timeline.
const _groupPhase = <String, int>{
  'Pre-Planning':    1,
  'Accommodation':   2,
  'Experiences':     2,
  'Logistics':       3,
  'Finance':         3,
  'Client Delivery': 4,
};

int _phaseFor(String groupName) => _groupPhase[groupName] ?? 3;

// ─────────────────────────────────────────────────────────────────────────────
// WorkflowScheduleEngine
//
// Backward planning algorithm:
//
//   cursor = planningDeadline
//   For phases 4 → 1 (latest to earliest):
//     Topologically sort tasks within phase (deps-first)
//     Process in REVERSE topo order so:
//       • last-in-chain gets the latest date (closest to cursor)
//       • first task (no deps) ends up earliest
//     For each task:
//       due_date   = cursor
//       start_date = cursor - duration + 1
//       cursor     = start_date - 1   (1-day gap between tasks)
//     cursor -= 1  (1-day phase separator)
//   Reverse result list → chronological order (earliest first)
// ─────────────────────────────────────────────────────────────────────────────

class WorkflowScheduleEngine {
  static List<ScheduledTaskResult> compute({
    required List<WorkflowTaskScheduleRule> rules,
    required DateTime planningStart,
    required DateTime planningDeadline,
  }) {
    if (rules.isEmpty) return [];

    final byId   = {for (final r in rules) r.id: r};
    final built  = <ScheduledTaskResult>[];
    var   cursor = planningDeadline;

    for (int phase = 4; phase >= 1; phase--) {
      final phaseTasks = rules
          .where((r) => _phaseFor(r.groupName) == phase)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (phaseTasks.isEmpty) continue;

      final sorted = _topoSort(phaseTasks, byId);

      for (final task in sorted.reversed) {
        final DateTime due;
        final DateTime start;

        if (task.schedulingMode == SchedulingMode.milestoneAligned &&
            task.latestFinishOffsetDays != null) {
          // Pin to a fixed offset from deadline instead of following cursor.
          due   = planningDeadline
              .subtract(Duration(days: task.latestFinishOffsetDays!));
          start = due.subtract(Duration(days: task.estimatedDurationDays - 1));
        } else {
          due   = cursor;
          start = cursor.subtract(Duration(days: task.estimatedDurationDays - 1));
          cursor = start.subtract(Duration(days: 1 + task.bufferDays));
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
          estimatedDurationDays: task.estimatedDurationDays,
          isCompressed:          compressed,
          scheduleNote:          compressed
              ? 'Timeline compressed — start adjusted to today.'
              : null,
        ));
      }

      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Reverse so results are in chronological order (earliest task first).
    return built.reversed.toList();
  }

  // Kahn's topological sort — within-phase dependencies only.
  // Tasks with no in-phase dependencies come first.
  static List<WorkflowTaskScheduleRule> _topoSort(
    List<WorkflowTaskScheduleRule> phase,
    Map<String, WorkflowTaskScheduleRule> byId,
  ) {
    final phaseIds = {for (final t in phase) t.id};
    final inDegree = <String, int>{for (final t in phase) t.id: 0};
    final graph    = <String, List<String>>{for (final t in phase) t.id: []};

    for (final task in phase) {
      for (final depId in task.dependencyTaskIds) {
        if (phaseIds.contains(depId)) {
          graph[depId]!.add(task.id);
          inDegree[task.id] = (inDegree[task.id] ?? 0) + 1;
        }
      }
    }

    final queue = phase
        .where((t) => (inDegree[t.id] ?? 0) == 0)
        .map((t) => t.id)
        .toList();
    final result = <WorkflowTaskScheduleRule>[];

    while (queue.isNotEmpty) {
      final id   = queue.removeAt(0);
      final task = byId[id];
      if (task == null) continue;
      result.add(task);
      for (final next in graph[id] ?? []) {
        inDegree[next] = (inDegree[next] ?? 1) - 1;
        if (inDegree[next] == 0) queue.add(next);
      }
    }

    // Append any tasks not reached (cycle guard).
    final placed = {for (final t in result) t.id};
    for (final t in phase) {
      if (!placed.contains(t.id)) result.add(t);
    }

    return result;
  }
}
