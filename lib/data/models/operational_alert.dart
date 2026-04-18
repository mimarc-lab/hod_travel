import 'package:flutter/material.dart';
import 'notification_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum AlertType {
  missingTask,
  overdueTask,
  supplierNonResponse,
  itineraryGap,
  budgetGap,
}

enum AlertSeverity { low, medium, high, critical }

// ─────────────────────────────────────────────────────────────────────────────
// OperationalAlert — computed in-memory; never persisted in this phase.
// ─────────────────────────────────────────────────────────────────────────────

class OperationalAlert {
  final String id;
  final String? tripId;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String? suggestedAction;

  OperationalAlert({
    required this.id,
    this.tripId,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.suggestedAction,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Display extensions
// ─────────────────────────────────────────────────────────────────────────────

extension AlertSeverityDisplay on AlertSeverity {
  String get label => switch (this) {
        AlertSeverity.low      => 'Low',
        AlertSeverity.medium   => 'Medium',
        AlertSeverity.high     => 'High',
        AlertSeverity.critical => 'Critical',
      };

  Color get color => switch (this) {
        AlertSeverity.low      => const Color(0xFF6B7280),
        AlertSeverity.medium   => const Color(0xFFF59E0B),
        AlertSeverity.high     => const Color(0xFFEF4444),
        AlertSeverity.critical => const Color(0xFF991B1B),
      };

  Color get bgColor => switch (this) {
        AlertSeverity.low      => const Color(0xFFF3F4F6),
        AlertSeverity.medium   => const Color(0xFFFEF3C7),
        AlertSeverity.high     => const Color(0xFFFEE2E2),
        AlertSeverity.critical => const Color(0xFFFEE2E2),
      };

  /// Higher weight = shown first in sorted lists.
  int get sortWeight => switch (this) {
        AlertSeverity.critical => 4,
        AlertSeverity.high     => 3,
        AlertSeverity.medium   => 2,
        AlertSeverity.low      => 1,
      };
}

extension AlertTypeDisplay on AlertType {
  String get label => switch (this) {
        AlertType.missingTask         => 'Missing Task',
        AlertType.overdueTask         => 'Overdue',
        AlertType.supplierNonResponse => 'Supplier Follow-up',
        AlertType.itineraryGap        => 'Itinerary Gap',
        AlertType.budgetGap           => 'Budget Gap',
      };

  IconData get icon => switch (this) {
        AlertType.missingTask         => Icons.add_task_rounded,
        AlertType.overdueTask         => Icons.schedule_rounded,
        AlertType.supplierNonResponse => Icons.storefront_outlined,
        AlertType.itineraryGap        => Icons.map_outlined,
        AlertType.budgetGap           => Icons.account_balance_wallet_outlined,
      };

  /// Maps an operational alert type to its corresponding notification type.
  /// Keeps the mapping co-located with the source enum.
  NotificationType get toNotificationType => switch (this) {
        AlertType.missingTask         => NotificationType.missingCriticalTask,
        AlertType.overdueTask         => NotificationType.overdueTask,
        AlertType.supplierNonResponse => NotificationType.supplierFollowup,
        AlertType.itineraryGap        => NotificationType.itineraryGap,
        AlertType.budgetGap           => NotificationType.budgetGap,
      };
}

extension AlertSeverityBridge on AlertSeverity {
  /// Maps operational severity to notification severity.
  /// Both enums share identical values — this makes the relationship explicit.
  NotificationSeverity get toNotificationSeverity => switch (this) {
        AlertSeverity.low      => NotificationSeverity.low,
        AlertSeverity.medium   => NotificationSeverity.medium,
        AlertSeverity.high     => NotificationSeverity.high,
        AlertSeverity.critical => NotificationSeverity.critical,
      };

  /// True for severities that warrant persisting a notification.
  /// Low-severity alerts are informational and should not generate noise.
  bool get isNotifiable => this != AlertSeverity.low;
}
