import '../../../data/models/user_model.dart';

// =============================================================================
// NextAction — a single ranked guidance item derived from operational alerts
// =============================================================================

enum NextActionPriority { urgent, high, medium, low }

class NextAction {
  /// Unique identifier (derived from the source alert id).
  final String id;

  /// Short imperative title, e.g. "Resolve overdue task".
  final String title;

  /// Full context sentence from the original alert message.
  final String description;

  final NextActionPriority priority;

  /// Optional label for the call-to-action chip.
  final String? actionLabel;

  /// Roles for which this action is most relevant.
  /// Empty = relevant to everyone.
  final List<AppRole> relevantRoles;

  const NextAction({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.actionLabel,
    this.relevantRoles = const [],
  });
}
