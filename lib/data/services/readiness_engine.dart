import '../models/milestone_status.dart';
import '../models/task_model.dart';
import '../models/trip_component_model.dart';
import '../models/trip_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReadinessEngine
//
// Computes a 0–100 readiness score using a weighted formula:
//
//   task_completion        × 0.35
//   milestone_completion   × 0.25
//   component_completion   × 0.20
//   no_overdue_bonus       × 0.10   (binary: 1 if no overdue tasks)
//   low_exceptions_bonus   × 0.10   (binary: 1 if ≤ 2 high-severity exceptions)
// ─────────────────────────────────────────────────────────────────────────────

class ReadinessResult {
  final int    score;
  final double taskCompletion;
  final double milestoneCompletion;
  final double componentCompletion;
  final bool   noOverdueBonus;
  final bool   lowExceptionsBonus;

  const ReadinessResult({
    required this.score,
    required this.taskCompletion,
    required this.milestoneCompletion,
    required this.componentCompletion,
    required this.noOverdueBonus,
    required this.lowExceptionsBonus,
  });

  static const ReadinessResult zero = ReadinessResult(
    score:                0,
    taskCompletion:       0,
    milestoneCompletion:  0,
    componentCompletion:  0,
    noOverdueBonus:       false,
    lowExceptionsBonus:   false,
  );
}

class ReadinessEngine {
  const ReadinessEngine._();

  static ReadinessResult compute({
    required List<Task>            tasks,
    required List<MilestoneStatus> milestones,
    required List<TripComponent>   components,
    required List<TripException>   exceptions,
  }) {
    final now = DateTime.now();

    // ── Task completion ───────────────────────────────────────────────────────
    final active = tasks.where((t) => t.status != TaskStatus.cancelled).toList();
    final done   = active.where((t) =>
        t.status == TaskStatus.approved ||
        t.status == TaskStatus.confirmed ||
        t.status == TaskStatus.sentToClient).length;
    final taskCompletion = active.isEmpty ? 0.0 : done / active.length;

    // ── Milestone completion ──────────────────────────────────────────────────
    final completedMs = milestones
        .where((m) => m.completion == MilestoneCompletion.complete)
        .length;
    final milestoneCompletion =
        milestones.isEmpty ? 0.0 : completedMs / milestones.length;

    // ── Component completion ──────────────────────────────────────────────────
    final activeComps = components
        .where((c) => c.status != ComponentStatus.cancelled)
        .toList();
    final confirmedComps = activeComps.where((c) =>
        c.status == ComponentStatus.confirmed ||
        c.status == ComponentStatus.booked).length;
    // No components yet → treat as neutral (1.0) — don't penalise early-stage trips
    final componentCompletion =
        activeComps.isEmpty ? 1.0 : confirmedComps / activeComps.length;

    // ── No overdue bonus ──────────────────────────────────────────────────────
    final hasOverdue = active.any((t) =>
        t.dueDate != null &&
        t.dueDate!.isBefore(now) &&
        t.status != TaskStatus.approved &&
        t.status != TaskStatus.confirmed);
    final noOverdueBonus = !hasOverdue;

    // ── Low exceptions bonus ──────────────────────────────────────────────────
    final highExcCount = exceptions
        .where((e) => e.severity == TripExceptionSeverity.high)
        .length;
    final lowExceptionsBonus = highExcCount <= 2;

    // ── Weighted sum ──────────────────────────────────────────────────────────
    final raw =
        taskCompletion      * 0.35 +
        milestoneCompletion * 0.25 +
        componentCompletion * 0.20 +
        (noOverdueBonus      ? 0.10 : 0.0) +
        (lowExceptionsBonus  ? 0.10 : 0.0);

    return ReadinessResult(
      score:               (raw * 100).round().clamp(0, 100),
      taskCompletion:      taskCompletion,
      milestoneCompletion: milestoneCompletion,
      componentCompletion: componentCompletion,
      noOverdueBonus:      noOverdueBonus,
      lowExceptionsBonus:  lowExceptionsBonus,
    );
  }
}
