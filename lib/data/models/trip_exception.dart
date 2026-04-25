import 'package:flutter/material.dart';

enum TripExceptionType { task, component, dataIntegrity, financial, supplier }

enum TripExceptionSeverity { low, medium, high }

enum TripExceptionAction {
  assignTask,
  markComplete,
  linkComponent,
  addMissingData,
  escalate,
}

extension TripExceptionTypeDisplay on TripExceptionType {
  String get label => switch (this) {
    TripExceptionType.task          => 'Task',
    TripExceptionType.component     => 'Component',
    TripExceptionType.dataIntegrity => 'Data Integrity',
    TripExceptionType.financial     => 'Financial',
    TripExceptionType.supplier      => 'Supplier',
  };

  IconData get icon => switch (this) {
    TripExceptionType.task          => Icons.task_alt_rounded,
    TripExceptionType.component     => Icons.category_rounded,
    TripExceptionType.dataIntegrity => Icons.link_off_rounded,
    TripExceptionType.financial     => Icons.attach_money_rounded,
    TripExceptionType.supplier      => Icons.storefront_rounded,
  };

  Color get color => switch (this) {
    TripExceptionType.task          => const Color(0xFF0369A1),
    TripExceptionType.component     => const Color(0xFF7C3AED),
    TripExceptionType.dataIntegrity => const Color(0xFFB45309),
    TripExceptionType.financial     => const Color(0xFF065F46),
    TripExceptionType.supplier      => const Color(0xFF1D4ED8),
  };
}

extension TripExceptionSeverityDisplay on TripExceptionSeverity {
  String get label => switch (this) {
    TripExceptionSeverity.low    => 'Low',
    TripExceptionSeverity.medium => 'Medium',
    TripExceptionSeverity.high   => 'High',
  };

  Color get color => switch (this) {
    TripExceptionSeverity.low    => const Color(0xFF6B7280),
    TripExceptionSeverity.medium => const Color(0xFFF59E0B),
    TripExceptionSeverity.high   => const Color(0xFFEF4444),
  };

  Color get bgColor => switch (this) {
    TripExceptionSeverity.low    => const Color(0xFFF3F4F6),
    TripExceptionSeverity.medium => const Color(0xFFFEF3C7),
    TripExceptionSeverity.high   => const Color(0xFFFEE2E2),
  };
}

extension TripExceptionActionDisplay on TripExceptionAction {
  String get label => switch (this) {
    TripExceptionAction.assignTask     => 'Assign Task',
    TripExceptionAction.markComplete   => 'Mark Complete',
    TripExceptionAction.linkComponent  => 'Link Component',
    TripExceptionAction.addMissingData => 'Add Data',
    TripExceptionAction.escalate       => 'Escalate',
  };
}

class TripException {
  final String id;
  final TripExceptionType type;
  final TripExceptionSeverity severity;
  final String message;
  final String? relatedEntityName;
  final String? relatedEntityId;
  final String suggestedAction;
  final TripExceptionAction actionType;

  const TripException({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.relatedEntityName,
    this.relatedEntityId,
    required this.suggestedAction,
    required this.actionType,
  });
}
