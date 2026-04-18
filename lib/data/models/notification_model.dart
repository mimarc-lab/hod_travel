import 'package:flutter/material.dart';

// =============================================================================
// NotificationType — all event-driven + intelligence alert types
// =============================================================================

enum NotificationType {
  // ── Workflow events ──────────────────────────────────────────────────────
  taskAssigned,
  approvalRequested,
  approvalDecision,
  statusChanged,
  comment,
  budgetUpdate,
  supplierUpdate,

  // ── Smart / intelligence-driven alerts ──────────────────────────────────
  overdueTask,
  taskDueSoon,
  supplierFollowup,
  missingCriticalTask,
  itineraryGap,
  budgetGap,
  tripAtRisk,
  systemWarning,
}

extension NotificationTypeDisplay on NotificationType {
  IconData get icon => switch (this) {
    NotificationType.taskAssigned       => Icons.person_add_alt_1_outlined,
    NotificationType.approvalRequested  => Icons.hourglass_empty_rounded,
    NotificationType.approvalDecision   => Icons.check_circle_outline_rounded,
    NotificationType.statusChanged      => Icons.swap_horiz_rounded,
    NotificationType.comment            => Icons.chat_bubble_outline_rounded,
    NotificationType.budgetUpdate       => Icons.account_balance_wallet_outlined,
    NotificationType.supplierUpdate     => Icons.storefront_outlined,
    NotificationType.overdueTask        => Icons.schedule_rounded,
    NotificationType.taskDueSoon        => Icons.alarm_rounded,
    NotificationType.supplierFollowup   => Icons.reply_rounded,
    NotificationType.missingCriticalTask=> Icons.add_task_rounded,
    NotificationType.itineraryGap       => Icons.map_outlined,
    NotificationType.budgetGap          => Icons.money_off_rounded,
    NotificationType.tripAtRisk         => Icons.warning_amber_rounded,
    NotificationType.systemWarning      => Icons.info_outline_rounded,
  };

  Color get color => switch (this) {
    NotificationType.taskAssigned       => const Color(0xFF6366F1),
    NotificationType.approvalRequested  => const Color(0xFFF59E0B),
    NotificationType.approvalDecision   => const Color(0xFF10B981),
    NotificationType.statusChanged      => const Color(0xFF0EA5E9),
    NotificationType.comment            => const Color(0xFF8B5CF6),
    NotificationType.budgetUpdate       => const Color(0xFFEC4899),
    NotificationType.supplierUpdate     => const Color(0xFFC9A96E),
    NotificationType.overdueTask        => const Color(0xFFEF4444),
    NotificationType.taskDueSoon        => const Color(0xFFF59E0B),
    NotificationType.supplierFollowup   => const Color(0xFFC9A96E),
    NotificationType.missingCriticalTask=> const Color(0xFFEF4444),
    NotificationType.itineraryGap       => const Color(0xFF0EA5E9),
    NotificationType.budgetGap          => const Color(0xFFEC4899),
    NotificationType.tripAtRisk         => const Color(0xFF991B1B),
    NotificationType.systemWarning      => const Color(0xFF6B7280),
  };

  String get dbValue => switch (this) {
    NotificationType.taskAssigned        => 'task_assigned',
    NotificationType.approvalRequested   => 'approval_requested',
    NotificationType.approvalDecision    => 'approval_decision',
    NotificationType.statusChanged       => 'status_changed',
    NotificationType.comment             => 'comment',
    NotificationType.budgetUpdate        => 'budget_update',
    NotificationType.supplierUpdate      => 'supplier_update',
    NotificationType.overdueTask         => 'overdue_task',
    NotificationType.taskDueSoon         => 'task_due_soon',
    NotificationType.supplierFollowup    => 'supplier_followup',
    NotificationType.missingCriticalTask => 'missing_critical_task',
    NotificationType.itineraryGap        => 'itinerary_gap',
    NotificationType.budgetGap           => 'budget_gap',
    NotificationType.tripAtRisk          => 'trip_at_risk',
    NotificationType.systemWarning       => 'system_warning',
  };

  static NotificationType fromDb(String raw) => switch (raw) {
    'task_assigned'         => NotificationType.taskAssigned,
    'approval_requested'    => NotificationType.approvalRequested,
    'approval_decision'     => NotificationType.approvalDecision,
    'status_changed'        => NotificationType.statusChanged,
    'budget_update'         => NotificationType.budgetUpdate,
    'supplier_update'       => NotificationType.supplierUpdate,
    'overdue_task'          => NotificationType.overdueTask,
    'task_due_soon'         => NotificationType.taskDueSoon,
    'supplier_followup'     => NotificationType.supplierFollowup,
    'missing_critical_task' => NotificationType.missingCriticalTask,
    'itinerary_gap'         => NotificationType.itineraryGap,
    'budget_gap'            => NotificationType.budgetGap,
    'trip_at_risk'          => NotificationType.tripAtRisk,
    'system_warning'        => NotificationType.systemWarning,
    _                       => NotificationType.comment,
  };
}

// =============================================================================
// NotificationSeverity
// =============================================================================

enum NotificationSeverity { low, medium, high, critical }

extension NotificationSeverityDisplay on NotificationSeverity {
  String get dbValue => switch (this) {
    NotificationSeverity.low      => 'low',
    NotificationSeverity.medium   => 'medium',
    NotificationSeverity.high     => 'high',
    NotificationSeverity.critical => 'critical',
  };

  static NotificationSeverity fromDb(String raw) => switch (raw) {
    'low'      => NotificationSeverity.low,
    'high'     => NotificationSeverity.high,
    'critical' => NotificationSeverity.critical,
    _          => NotificationSeverity.medium,
  };

  int get sortWeight => switch (this) {
    NotificationSeverity.critical => 4,
    NotificationSeverity.high     => 3,
    NotificationSeverity.medium   => 2,
    NotificationSeverity.low      => 1,
  };

  Color get color => switch (this) {
    NotificationSeverity.low      => const Color(0xFF6B7280),
    NotificationSeverity.medium   => const Color(0xFFF59E0B),
    NotificationSeverity.high     => const Color(0xFFEF4444),
    NotificationSeverity.critical => const Color(0xFF991B1B),
  };

  Color get bgColor => switch (this) {
    NotificationSeverity.low      => const Color(0xFFF3F4F6),
    NotificationSeverity.medium   => const Color(0xFFFEF3C7),
    NotificationSeverity.high     => const Color(0xFFFEE2E2),
    NotificationSeverity.critical => const Color(0xFFFEE2E2),
  };
}

// =============================================================================
// AppNotification
// =============================================================================

class AppNotification {
  final String id;
  final String? teamId;
  final NotificationType type;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final String? relatedTable;
  final String? relatedId;
  final String? suggestedAction;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    this.teamId,
    required this.type,
    this.severity = NotificationSeverity.medium,
    required this.title,
    required this.message,
    this.relatedTable,
    this.relatedId,
    this.suggestedAction,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id:              id,
    teamId:          teamId,
    type:            type,
    severity:        severity,
    title:           title,
    message:         message,
    relatedTable:    relatedTable,
    relatedId:       relatedId,
    suggestedAction: suggestedAction,
    createdAt:       createdAt,
    isRead:          isRead ?? this.isRead,
  );
}
