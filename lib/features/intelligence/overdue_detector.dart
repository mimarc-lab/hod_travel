import '../../data/models/operational_alert.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// OverdueDetector
//
// Detects two conditions:
//   1. Tasks past their due date (terminal statuses excluded).
//   2. High-priority tasks due within the next 48 hours.
// ─────────────────────────────────────────────────────────────────────────────

class OverdueDetector {
  const OverdueDetector._();

  static const _urgentWindowHours = 48;

  static List<OperationalAlert> detect(Trip trip, List<Task> tasks) {
    final now    = DateTime.now();
    final active = tasks.where(
      (t) => t.tripId == trip.id && !utils.isTerminalStatus(t.status),
    ).toList();

    final alerts = <OperationalAlert>[];

    // ── 1. Overdue ────────────────────────────────────────────────────────────
    final overdue = active
        .where((t) => t.dueDate != null && t.dueDate!.isBefore(now))
        .toList();

    if (overdue.isNotEmpty) {
      final n         = overdue.length;
      final highCount = overdue.where((t) => t.priority == TaskPriority.high).length;
      alerts.add(OperationalAlert(
        id:       'overdue_${trip.id}',
        tripId:   trip.id,
        type:     AlertType.overdueTask,
        severity: highCount > 0 ? AlertSeverity.critical : AlertSeverity.high,
        title:    utils.nOf(n, 'Overdue Task'),
        message:  '${utils.nAre(n, 'task')} overdue for ${trip.name}.'
                  '${highCount > 0 ? ' ($highCount high-priority)' : ''}',
        suggestedAction: 'Review and update overdue tasks on the board.',
      ));
    }

    // ── 2. Urgent upcoming ────────────────────────────────────────────────────
    final cutoff  = now.add(const Duration(hours: _urgentWindowHours));
    final urgent  = active.where((t) =>
        t.priority == TaskPriority.high &&
        t.dueDate  != null &&
        t.dueDate!.isAfter(now) &&
        t.dueDate!.isBefore(cutoff)).toList();

    if (urgent.isNotEmpty) {
      final n = urgent.length;
      alerts.add(OperationalAlert(
        id:       'urgent_${trip.id}',
        tripId:   trip.id,
        type:     AlertType.overdueTask,
        severity: AlertSeverity.high,
        title:    '${utils.nOf(n, 'Urgent Task')} Due Within 48 h',
        message:  '${utils.nAre(n, 'high-priority task')} due in the next 48 hours.',
        suggestedAction: 'Complete or reassign these tasks immediately.',
      ));
    }

    return alerts;
  }
}
