import '../models/notification_model.dart';
import '../models/operational_alert.dart';
import '../repositories/notification_repository.dart';
import '../repositories/team_repository.dart';
import 'smart_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IntelligenceNotificationBridge
//
// Converts OperationalAlerts (computed in-memory by detectors) into persisted
// AppNotification rows for all active members of the trip's team.
//
// Routing rules:
//   - Only alerts with severity >= medium are bridged (low = informational only).
//   - Each alert uses its own stable ID as relatedId for per-alert dedup:
//       type='overdueTask' + relatedId='overdue_<tripId>' → 1 unread per user.
//   - SmartNotificationService skips the insert if a matching unread already
//     exists, so it is safe to call bridge() on every intelligence reload.
//   - Team members are fetched once per bridge() call, not per alert.
// ─────────────────────────────────────────────────────────────────────────────

class IntelligenceNotificationBridge {
  IntelligenceNotificationBridge._();

  static Future<void> bridge({
    required List<OperationalAlert> alerts,
    required String tripId,
    required String teamId,
    required NotificationRepository notifications,
    required TeamRepository teams,
  }) async {
    // Filter: only medium+ severity (low alerts are ambient, not actionable).
    final notifiable = alerts.where((a) => a.severity.isNotifiable).toList();
    if (notifiable.isEmpty) return;

    // Fetch active member IDs once for the whole batch.
    final List<String> userIds;
    try {
      final members = await teams.fetchMembers(teamId);
      userIds = members
          .where((m) => m.isActive)
          .map((m) => m.userId)
          .toList();
    } catch (_) {
      return; // Can't route without members; fail silently.
    }
    if (userIds.isEmpty) return;

    final service = SmartNotificationService(notifications);

    for (final alert in notifiable) {
      // id is ignored by repository.create() — Supabase generates it.
      // alert.id is used as relatedId for per-alert dedup granularity:
      // a separate unread slot per distinct alert (e.g. 'budget_empty_<tripId>'
      // vs 'budget_noaccom_<tripId>') rather than collapsing all budget alerts
      // into one slot.
      final notification = AppNotification(
        id:              '',
        teamId:          teamId,
        type:            alert.type.toNotificationType,
        severity:        alert.severity.toNotificationSeverity,
        title:           alert.title,
        message:         alert.message,
        relatedTable:    'trips',
        relatedId:       alert.id, // stable, deterministic per detector
        suggestedAction: alert.suggestedAction,
        createdAt:       DateTime.now().toUtc(),
      );

      await service.notifyAll(
        notification: notification,
        userIds:      userIds,
        teamId:       teamId,
      );
    }
  }
}
