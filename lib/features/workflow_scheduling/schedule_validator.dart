import 'package:flutter/foundation.dart';
import '../../data/models/scheduled_task_result.dart';
import 'planning_deadline_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScheduleValidator
//
// Validates the output of HybridScheduleEngine and produces human-readable
// warnings for impossible or compressed schedules.
//
// Severity levels:
//   IMPOSSIBLE  — deadline already passed; tasks cannot fit before departure
//   COMPRESSED  — required days > available days; timeline is over-committed
//   TIGHT       — required > 85% of available; low margin, start immediately
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleValidator {
  static ScheduleAnalysis validate({
    required List<ScheduledTaskResult> tasks,
    required DateTime planningDeadline,
    int bufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) {
    final planningStart   = PlanningDeadlineHelper.planningStart();
    final available       = PlanningDeadlineHelper.availableDays(planningDeadline);

    // Use the actual schedule SPAN (latest due − earliest start), not the sum
    // of durations.  Summing inflates the number when parallel tasks overlap.
    final required = tasks.isEmpty ? 0 : (() {
      final earliest = tasks
          .map((t) => t.scheduledStartDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final latest = tasks
          .map((t) => t.dueDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final span = latest.difference(earliest).inDays + 1;
      final effort = tasks.fold(0, (s, t) => s + t.effectiveDurationDays);
      debugPrint('[ScheduleValidator] earliestStart=$earliest latestDue=$latest span=$span days totalEffort=$effort task-days available=$available');
      return span;
    })();

    final compressedTasks = tasks.where((t) => t.isCompressed).toList();
    final compressed      = compressedTasks.isNotEmpty;
    final impossible      = available <= 0;
    final warnings        = <String>[];

    if (impossible) {
      warnings.add(
        'Planning deadline has already passed. '
        'Trip starts in fewer than $bufferDays days — '
        'tasks cannot be scheduled before departure. '
        'Consider extending the planning buffer or adjusting the trip date.',
      );
    } else if (required > available) {
      final groups = compressedTasks
          .map((t) => t.groupName)
          .toSet()
          .join(', ');
      warnings.add(
        'Schedule too compressed — $required days of work must fit into '
        '$available available days. '
        'Affected phases: ${groups.isEmpty ? "multiple" : groups}. '
        'Start planning immediately or reduce task scope.',
      );
    } else if (required > (available * 0.85).floor()) {
      warnings.add(
        'Planning window is tight ($required days required, '
        '$available days available). '
        'Start tasks as soon as possible to avoid slipping.',
      );
    }

    return ScheduleAnalysis(
      tasks:            tasks,
      planningStart:    planningStart,
      planningDeadline: planningDeadline,
      isPossible:       !impossible,
      isCompressed:     compressed,
      availableDays:    available,
      requiredDays:     required,
      warnings:         warnings,
    );
  }
}
