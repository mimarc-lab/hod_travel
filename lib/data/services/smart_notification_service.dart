import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartNotificationService
//
// Wraps NotificationRepository with per-user deduplication.
// A notification is skipped if an unread row with the same (type + relatedId)
// already exists for that user, preventing alert spam on every intelligence
// reload.
//
// Error handling:
//   notify()     — propagates errors; callers decide how to handle them.
//   notifyAll()  — swallows per-user errors so one failing write doesn't
//                  block the rest of the batch.
// ─────────────────────────────────────────────────────────────────────────────

class SmartNotificationService {
  final NotificationRepository _repo;

  SmartNotificationService(this._repo);

  /// Creates [notification] for [userId] only if no matching unread exists.
  /// Returns true if the row was written, false if deduplicated.
  /// Throws on unexpected repository errors.
  Future<bool> notify({
    required AppNotification notification,
    required String userId,
    required String teamId,
  }) async {
    final exists = await _repo.existsUnread(
      userId,
      notification.type,
      notification.relatedId,
    );
    if (exists) return false;
    await _repo.create(notification, userId, teamId);
    return true;
  }

  /// Notifies all [userIds] concurrently, running dedup per user.
  /// Individual user failures are suppressed so one bad write doesn't block
  /// the rest of the batch.
  Future<void> notifyAll({
    required AppNotification notification,
    required List<String> userIds,
    required String teamId,
  }) async {
    await Future.wait(
      userIds.map((uid) async {
        try {
          await notify(notification: notification, userId: uid, teamId: teamId);
        } catch (_) {
          // Suppress per-user errors — other users still receive the notification.
        }
      }),
    );
  }
}
