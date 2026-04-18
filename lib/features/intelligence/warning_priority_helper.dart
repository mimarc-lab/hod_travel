import '../../data/models/operational_alert.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WarningPriorityHelper
//
// Sorts a list of OperationalAlerts so the most important issues surface first.
//
// Score = severity weight × 100
//        + trip-proximity bonus (higher the closer to departure)
//        + alert-type weight   (operational > budget)
// ─────────────────────────────────────────────────────────────────────────────

class WarningPriorityHelper {
  const WarningPriorityHelper._();

  /// Returns a new list sorted highest-priority first.
  static List<OperationalAlert> sort(
    List<OperationalAlert> alerts, {
    DateTime? tripStartDate,
  }) {
    final sorted = [...alerts]
      ..sort((a, b) =>
          _score(b, tripStartDate).compareTo(_score(a, tripStartDate)));
    return sorted;
  }

  static int _score(OperationalAlert alert, DateTime? tripStart) {
    var score = alert.severity.sortWeight * 100;

    // Proximity bonus: closer departure = higher urgency
    if (tripStart != null) {
      final daysUntil = tripStart.difference(DateTime.now()).inDays;
      if (daysUntil <= 3) {
        score += 60;
      } else if (daysUntil <= 7) {
        score += 40;
      } else if (daysUntil <= 14) {
        score += 25;
      } else if (daysUntil <= 30) {
        score += 10;
      }
    }

    // Type weight: operational problems ranked above budget/notes
    score += switch (alert.type) {
      AlertType.overdueTask         => 40,
      AlertType.supplierNonResponse => 30,
      AlertType.missingTask         => 25,
      AlertType.itineraryGap        => 20,
      AlertType.budgetGap           => 15,
    };

    return score;
  }
}
