import '../../data/models/task_duration_profile.dart';
import '../../data/models/trip_complexity_profile.dart';
import '../../data/models/workflow_task_schedule_rule.dart';
import 'complexity_rules.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DurationCalculator
//
// Computes the effective duration for one task:
//
//   effective = base + complexity_adjustment + buffer
//
//   base              — stored estimatedDurationDays, or group fallback when ≤ 1
//   complexity_adj    — from ComplexityRules based on trip profile
//   buffer            — task.bufferDays (supplier response / review wait)
// ─────────────────────────────────────────────────────────────────────────────

class DurationBreakdown {
  final int baseDays;
  final int complexityDays;
  final int bufferDays;

  const DurationBreakdown({
    required this.baseDays,
    required this.complexityDays,
    required this.bufferDays,
  });

  int get effectiveDays => baseDays + complexityDays + bufferDays;

  @override
  String toString() =>
      'DurationBreakdown(base=$baseDays, complexity=$complexityDays, '
      'buffer=$bufferDays → effective=$effectiveDays)';
}

class DurationCalculator {
  static DurationBreakdown compute(
    WorkflowTaskScheduleRule task,
    TripComplexityProfile complexity,
  ) {
    final base       = TaskDurationProfile.baseDaysFor(
      task.groupName,
      task.estimatedDurationDays,
    );
    final complexAdj = ComplexityRules.adjustmentFor(task, complexity);
    final buffer     = task.bufferDays;

    return DurationBreakdown(
      baseDays:       base,
      complexityDays: complexAdj,
      bufferDays:     buffer,
    );
  }
}
