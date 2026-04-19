import '../../data/models/scheduled_task_result.dart';
import 'planning_deadline_helper.dart';

class ScheduleConflictDetector {
  static ScheduleAnalysis analyze({
    required List<ScheduledTaskResult> tasks,
    required DateTime planningDeadline,
    int bufferDays = PlanningDeadlineHelper.defaultBufferDays,
  }) {
    final planningStart = PlanningDeadlineHelper.planningStart();
    final available     = PlanningDeadlineHelper.availableDays(planningDeadline);
    final required      = tasks.fold(0, (sum, t) => sum + t.estimatedDurationDays);
    final compressed    = tasks.any((t) => t.isCompressed);
    final impossible    = available <= 0;
    final warnings      = <String>[];

    if (impossible) {
      warnings.add(
        'Planning deadline has already passed. '
        'Trip starts in fewer than $bufferDays days — '
        'tasks cannot be scheduled before departure.',
      );
    } else if (compressed) {
      final groups = tasks
          .where((t) => t.isCompressed)
          .map((t) => t.groupName)
          .toSet()
          .join(', ');
      warnings.add(
        'Schedule is compressed — $required days of work '
        'must fit into $available available days. '
        'Affected areas: $groups. '
        'Consider starting immediately or reducing scope.',
      );
    } else if (required > (available * 0.85).floor()) {
      warnings.add(
        'Planning window is tight ($required days required, '
        '$available days available). Start tasks as soon as possible.',
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
