import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchForUser(String userId);
  Future<void> markRead(String notificationId);
  Future<void> markAllRead(String userId);
  Future<void> create(AppNotification notification, String userId, String teamId);

  /// Returns true if an unread notification of the same [type] and [relatedId]
  /// already exists for [userId] — used to deduplicate smart alerts.
  Future<bool> existsUnread(String userId, NotificationType type, String? relatedId);

  /// Realtime stream of notifications for [userId].
  /// Emits a full refreshed list on every INSERT for this user.
  /// Call .cancel() on the subscription when done.
  Stream<List<AppNotification>> watchForUser(String userId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

AppNotification _fromRow(Map<String, dynamic> r) => AppNotification(
  id:              r['id'] as String,
  teamId:          r['team_id'] as String?,
  type:            NotificationTypeDisplay.fromDb(r['type'] as String? ?? 'comment'),
  severity:        NotificationSeverityDisplay.fromDb(r['severity'] as String? ?? 'medium'),
  title:           r['title'] as String? ?? '',
  message:         r['message'] as String,
  relatedTable:    r['related_table'] as String?,
  relatedId:       r['related_id'] as String?,
  suggestedAction: r['suggested_action'] as String?,
  createdAt:       DateTime.parse(r['created_at'] as String),
  isRead:          r['is_read'] as bool? ?? false,
);

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient _client;
  SupabaseNotificationRepository(this._client);

  @override
  Future<List<AppNotification>> fetchForUser(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  @override
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  @override
  Future<void> create(
      AppNotification notification, String userId, String teamId) async {
    await _client.from('notifications').insert({
      'user_id':          userId,
      'team_id':          teamId,
      'type':             notification.type.dbValue,
      'severity':         notification.severity.dbValue,
      'title':            notification.title,
      'message':          notification.message,
      'related_table':    notification.relatedTable,
      'related_id':       notification.relatedId,
      'suggested_action': notification.suggestedAction,
      'is_read':          false,
    });
  }

  @override
  Future<bool> existsUnread(
      String userId, NotificationType type, String? relatedId) async {
    var query = _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', type.dbValue)
        .eq('is_read', false);
    if (relatedId != null) {
      query = query.eq('related_id', relatedId);
    }
    final rows = await query.limit(1);
    return (rows as List).isNotEmpty;
  }

  // ── Realtime ────────────────────────────────────────────────────────────────

  @override
  Stream<List<AppNotification>> watchForUser(String userId) {
    final controller = StreamController<List<AppNotification>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchForUser(userId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    // INSERT only — markRead/markAllRead are handled optimistically in the
    // provider; no refetch needed for those UPDATE events.
    final channel = _client
        .channel('notifications:$userId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
