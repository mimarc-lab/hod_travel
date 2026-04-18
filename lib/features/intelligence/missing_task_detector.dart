import '../../data/models/operational_alert.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// MissingTaskDetector
//
// Checks whether a trip has tasks covering each expected operational category.
// Keyword-matches against task name and category fields.
// Only non-cancelled tasks are considered.
// ─────────────────────────────────────────────────────────────────────────────

class MissingTaskDetector {
  const MissingTaskDetector._();

  static const _checks = [
    _Check(
      keywords: utils.kAccommodationKeywords,
      label: 'Accommodation',
      suggestion: 'Create an accommodation sourcing or confirmation task.',
    ),
    _Check(
      keywords: ['transfer', 'airport', 'transport', 'arrival', 'departure'],
      label: 'Airport Transfer',
      suggestion: 'Create an airport transfer or logistics task.',
    ),
    _Check(
      keywords: ['payment', 'invoice', 'finance', 'budget', 'costing'],
      label: 'Payment Review',
      suggestion: 'Create a payment or budget review task.',
    ),
    _Check(
      keywords: ['client', 'delivery', 'proposal', 'presentation'],
      label: 'Client Delivery',
      suggestion: 'Create a client delivery or proposal task.',
    ),
  ];

  /// Returns one alert per expected category not covered by [tasks] for [trip].
  static List<OperationalAlert> detect(Trip trip, List<Task> tasks) {
    final active = tasks.where(
      (t) => t.tripId == trip.id && t.status != TaskStatus.cancelled,
    );

    final alerts = <OperationalAlert>[];
    for (final check in _checks) {
      if (!active.any(check.matches)) {
        alerts.add(OperationalAlert(
          id: 'missing_${trip.id}_${check._key}',
          tripId: trip.id,
          type: AlertType.missingTask,
          severity: AlertSeverity.medium,
          title: 'Missing ${check.label} Task',
          message: 'No ${check.label.toLowerCase()} task found for ${trip.name}.',
          suggestedAction: check.suggestion,
        ));
      }
    }
    return alerts;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Check {
  final List<String> keywords;
  final String label;
  final String suggestion;

  const _Check({
    required this.keywords,
    required this.label,
    required this.suggestion,
  });

  String get _key => label.toLowerCase().replaceAll(' ', '_');

  bool matches(Task t) {
    final name = t.name.toLowerCase();
    final cat  = t.category?.toLowerCase() ?? '';
    return keywords.any((k) => name.contains(k) || cat.contains(k));
  }
}
