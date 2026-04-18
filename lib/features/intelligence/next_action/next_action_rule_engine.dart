import '../../../data/models/operational_alert.dart';
import '../../../data/models/user_model.dart';
import 'next_action_model.dart';
import 'next_action_priority_helper.dart';

// =============================================================================
// NextActionRuleEngine
//
// Maps each OperationalAlert to a NextAction and returns a role-aware,
// priority-sorted list.  One action per alert; alert dedup is handled
// upstream in the notification bridge.
// =============================================================================

// Per-type action template: (title, actionLabel, relevantRoles)
typedef _ActionTemplate = (String, String, List<AppRole>);

abstract class NextActionRuleEngine {
  static List<NextAction> compute({
    required List<OperationalAlert> alerts,
    AppRole? role,
  }) {
    if (alerts.isEmpty) return const [];
    final actions = alerts.map(_toAction).toList();
    return NextActionPriorityHelper.sort(actions, role: role);
  }

  static NextAction _toAction(OperationalAlert alert) {
    final (title, actionLabel, roles) = _template(alert.type);
    return NextAction(
      id:            'action_${alert.id}',
      title:         title,
      description:   alert.message,
      priority:      _toPriority(alert.severity),
      actionLabel:   actionLabel,
      relevantRoles: roles,
    );
  }

  // ── Per-type templates ─────────────────────────────────────────────────────
  // Each entry defines: title shown to user, CTA chip label, roles for whom
  // this action is most relevant (empty = everyone).

  static _ActionTemplate _template(AlertType type) => switch (type) {
    AlertType.overdueTask => (
      'Resolve overdue task',
      'View Task',
      [AppRole.admin, AppRole.tripLead, AppRole.staff],
    ),
    AlertType.missingTask => (
      'Add missing task',
      'Open Task Board',
      [AppRole.admin, AppRole.tripLead],
    ),
    AlertType.supplierNonResponse => (
      'Follow up with supplier',
      'View Supplier',
      [AppRole.admin, AppRole.tripLead, AppRole.staff],
    ),
    AlertType.itineraryGap => (
      'Fill itinerary gap',
      'Edit Itinerary',
      [AppRole.admin, AppRole.tripLead],
    ),
    AlertType.budgetGap => (
      'Review budget gap',
      'View Budget',
      [AppRole.admin, AppRole.finance],
    ),
  };

  static NextActionPriority _toPriority(AlertSeverity s) => switch (s) {
    AlertSeverity.critical => NextActionPriority.urgent,
    AlertSeverity.high     => NextActionPriority.high,
    AlertSeverity.medium   => NextActionPriority.medium,
    AlertSeverity.low      => NextActionPriority.low,
  };
}
