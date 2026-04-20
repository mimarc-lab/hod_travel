import '../../data/models/workflow_task_schedule_rule.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DependencyResolver
//
// Determines task execution order for backward scheduling.
//
// Phase order (lower = earlier in planning → scheduled last in backward pass):
//   1  Pre-Planning
//   2  Accommodation, Experiences, Dining
//   3  Logistics, Finance
//   4  Client Delivery, Finalization
//
// Within each phase, Kahn's topological sort respects dependency edges.
// Cross-phase dependency edges are honoured by the phase ordering itself.
// Cycle guard: any unreachable task is appended at the end of its phase.
// ─────────────────────────────────────────────────────────────────────────────

class DependencyResolver {
  static const _groupPhase = <String, int>{
    'Pre-Planning':    1,
    'Accommodation':   2,
    'Experiences':     2,
    'Dining':          2,
    'Logistics':       3,
    'Finance':         3,
    'Client Delivery': 4,
    'Finalization':    4,
  };

  static int phaseFor(String groupName) => _groupPhase[groupName] ?? 3;

  /// Returns tasks in backward-scheduling order (phase 4 → 1, topo-sorted within).
  ///
  /// Reversing this list gives chronological (earliest-first) order.
  static List<WorkflowTaskScheduleRule> resolve(
    List<WorkflowTaskScheduleRule> tasks,
  ) {
    final byId   = {for (final t in tasks) t.id: t};
    final result = <WorkflowTaskScheduleRule>[];

    // Iterate phases from latest to earliest so the cursor walks backward.
    for (int phase = 4; phase >= 1; phase--) {
      final phaseTasks = tasks
          .where((t) => phaseFor(t.groupName) == phase)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (phaseTasks.isNotEmpty) {
        result.addAll(_topoSort(phaseTasks, byId));
      }
    }

    return result;
  }

  // Kahn's algorithm — within-phase only.
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
    final sorted = <WorkflowTaskScheduleRule>[];

    while (queue.isNotEmpty) {
      final id   = queue.removeAt(0);
      final task = byId[id];
      if (task == null) continue;
      sorted.add(task);
      for (final next in graph[id] ?? []) {
        inDegree[next] = (inDegree[next] ?? 1) - 1;
        if (inDegree[next] == 0) queue.add(next);
      }
    }

    // Cycle guard: append any tasks not reached by topo walk.
    final placed = {for (final t in sorted) t.id};
    for (final t in phase) {
      if (!placed.contains(t.id)) sorted.add(t);
    }

    return sorted;
  }
}
