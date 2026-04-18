import '../../data/models/operational_alert.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// SupplierResponseDetector
//
// Detects tasks stuck in "awaiting_reply".
// Uses task due date as a staleness proxy — no separate last-activity needed.
//
//   Stale:   awaiting_reply AND past due date → High
//   Pending: awaiting_reply, not yet past due  → Medium
// ─────────────────────────────────────────────────────────────────────────────

class SupplierResponseDetector {
  const SupplierResponseDetector._();

  static List<OperationalAlert> detect(Trip trip, List<Task> tasks) {
    final now     = DateTime.now();
    final waiting = tasks.where(
      (t) => t.tripId == trip.id && t.status == TaskStatus.awaitingReply,
    ).toList();

    if (waiting.isEmpty) return [];

    final stale   = waiting.where(
      (t) => t.dueDate != null && t.dueDate!.isBefore(now),
    ).toList();
    final pending = waiting.length - stale.length;

    final alerts = <OperationalAlert>[];

    if (stale.isNotEmpty) {
      final n = stale.length;
      alerts.add(OperationalAlert(
        id:       'supplier_stale_${trip.id}',
        tripId:   trip.id,
        type:     AlertType.supplierNonResponse,
        severity: AlertSeverity.high,
        title:    '${utils.nOf(n, 'Supplier Follow-Up')} Overdue',
        message:  '${utils.nAre(n, 'task')} awaiting supplier reply '
                  'and past due for ${trip.name}.',
        suggestedAction: 'Follow up with suppliers on these overdue tasks.',
      ));
    }

    if (pending > 0) {
      alerts.add(OperationalAlert(
        id:       'supplier_pending_${trip.id}',
        tripId:   trip.id,
        type:     AlertType.supplierNonResponse,
        severity: AlertSeverity.medium,
        title:    '${utils.nOf(pending, 'Supplier Response')} Pending',
        message:  '${utils.nAre(pending, 'task')} awaiting a supplier reply for ${trip.name}.',
        suggestedAction: 'Check for supplier replies and follow up if needed.',
      ));
    }

    return alerts;
  }
}
