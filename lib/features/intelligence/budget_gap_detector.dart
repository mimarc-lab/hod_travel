import '../../data/models/cost_item_model.dart';
import '../../data/models/operational_alert.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// BudgetGapDetector
//
// Three checks, in order of severity:
//   1. Trip has tasks but no cost items at all        → High  (exits early)
//   2. Accommodation tasks exist, no matching cost    → Medium
//   3. Cost items with net cost of zero (unpriced)   → Low
// ─────────────────────────────────────────────────────────────────────────────

class BudgetGapDetector {
  const BudgetGapDetector._();

  static List<OperationalAlert> detect(
    Trip trip,
    List<Task> tasks,
    List<CostItem> costItems,
  ) {
    final tripTasks = tasks.where(
      (t) => t.tripId == trip.id && t.status != TaskStatus.cancelled,
    ).toList();
    final tripCosts = costItems.where((c) => c.tripId == trip.id).toList();

    // ── 1. No cost items at all ───────────────────────────────────────────────
    if (tripTasks.isNotEmpty && tripCosts.isEmpty) {
      return [
        OperationalAlert(
          id:              'budget_empty_${trip.id}',
          tripId:          trip.id,
          type:            AlertType.budgetGap,
          severity:        AlertSeverity.high,
          title:           'No Budget Items Added',
          message:         '${trip.name} has ${utils.nOf(tripTasks.length, 'task')} '
                           'but no cost items have been created.',
          suggestedAction: 'Open the Budget tab and add cost items.',
        ),
      ];
    }

    final alerts = <OperationalAlert>[];

    // ── 2. Accommodation task without cost coverage ───────────────────────────
    final hasAccomTask = tripTasks.any(utils.isAccommodationTask);
    final hasAccomCost = tripCosts.any((c) => c.category == CostCategory.accommodation);

    if (hasAccomTask && !hasAccomCost) {
      alerts.add(OperationalAlert(
        id:              'budget_noaccom_${trip.id}',
        tripId:          trip.id,
        type:            AlertType.budgetGap,
        severity:        AlertSeverity.medium,
        title:           'Missing Accommodation Costs',
        message:         'Accommodation tasks exist but no accommodation cost items '
                         'have been added for ${trip.name}.',
        suggestedAction: 'Add accommodation cost items to the Budget tab.',
      ));
    }

    // ── 3. Unpriced cost items (net cost = 0) ─────────────────────────────────
    final unpriced = tripCosts.where((c) => c.netCost == 0).toList();
    if (unpriced.isNotEmpty) {
      final n = unpriced.length;
      alerts.add(OperationalAlert(
        id:              'budget_unpriced_${trip.id}',
        tripId:          trip.id,
        type:            AlertType.budgetGap,
        severity:        AlertSeverity.low,
        title:           utils.nOf(n, 'Unpriced Cost Item'),
        message:         '${utils.nAre(n, 'cost item')} at zero — pricing may be incomplete.',
        suggestedAction: 'Review and update the unpriced cost items.',
      ));
    }

    return alerts;
  }
}
