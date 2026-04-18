import '../../data/models/cost_item_model.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/trip_readiness.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// ReadinessService
//
// Computes a 0–100 readiness score and status label for a single trip.
// All scoring is transparent and table-driven — adjust thresholds here.
//
//   Signal                      Max deduction
//   ─────────────────────────── ─────────────
//   Task completion rate             30 pts
//   Overdue high-priority tasks      20 pts
//   Missing expected task categories 20 pts
//   Itinerary coverage               15 pts
//   Budget populated                 15 pts
//
// [missingTaskCount] must be passed in by the caller (pre-computed by
// MissingTaskDetector) to avoid running the detector twice for the same data.
// ─────────────────────────────────────────────────────────────────────────────

class ReadinessService {
  const ReadinessService._();

  static TripReadiness compute({
    required Trip trip,
    required List<Task> tasks,
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDayId,
    required List<CostItem> costItems,
    required int missingTaskCount,
  }) {
    final tripTasks = tasks
        .where((t) => t.tripId == trip.id && t.status != TaskStatus.cancelled)
        .toList();
    final tripCosts = costItems.where((c) => c.tripId == trip.id).toList();
    final now       = DateTime.now();

    var score       = 100;
    final reasons   = <String>[];

    // ── Task completion (max −30) ─────────────────────────────────────────────
    if (tripTasks.isEmpty) {
      score -= 20;
      reasons.add('No tasks have been created');
    } else {
      final done = tripTasks.where((t) => utils.isCompleteStatus(t.status)).length;
      final pct  = (done / tripTasks.length * 100).round();
      if (pct < 25)       { score -= 30; reasons.add('$pct% of tasks complete'); }
      else if (pct < 50)  { score -= 20; reasons.add('$pct% of tasks complete'); }
      else if (pct < 75)  { score -= 10; }
    }

    // ── Overdue high-priority tasks (max −20) ─────────────────────────────────
    final overdueHigh = tripTasks.where((t) =>
        t.priority  == TaskPriority.high &&
        t.dueDate   != null &&
        t.dueDate!.isBefore(now) &&
        !utils.isCompleteStatus(t.status)).length;

    if (overdueHigh > 0) {
      // −7 per task, capped at 20
      score -= (overdueHigh * 7).clamp(0, 20);
      reasons.add('$overdueHigh overdue high-priority ${utils.pl(overdueHigh, 'task')}');
    }

    // ── Missing task categories (max −20) ─────────────────────────────────────
    // Caller passes count so we don't re-run MissingTaskDetector here.
    if (missingTaskCount > 0) {
      score -= (missingTaskCount * 7).clamp(0, 20);
      reasons.add('$missingTaskCount expected task '
                  '${utils.pl(missingTaskCount, 'category', 'categories')} missing');
    }

    // ── Itinerary coverage (max −15) ─────────────────────────────────────────
    if (days.isEmpty) {
      score -= 10;
      reasons.add('Itinerary not started');
    } else {
      final emptyCount =
          days.where((d) => (itemsByDayId[d.id] ?? []).isEmpty).length;
      if (emptyCount == days.length) {
        score -= 15;
        reasons.add('All ${days.length} itinerary ${utils.pl(days.length, 'day')} empty');
      } else if (emptyCount > 0) {
        score -= (emptyCount * 3).clamp(0, 15);
        reasons.add('$emptyCount itinerary ${utils.pl(emptyCount, 'day')} incomplete');
      }
    }

    // ── Budget coverage (max −15) ─────────────────────────────────────────────
    if (tripCosts.isEmpty && tripTasks.isNotEmpty) {
      score -= 15;
      reasons.add('No budget items added');
    } else if (tripCosts.isNotEmpty) {
      final unpriced = tripCosts.where((c) => c.netCost == 0).length;
      if (unpriced > 0) {
        score -= (unpriced * 3).clamp(0, 10);
        reasons.add('$unpriced unpriced cost ${utils.pl(unpriced, 'item')}');
      }
    }

    score = score.clamp(0, 100);

    final status = score >= 85
        ? ReadinessStatus.ready
        : score >= 65
            ? ReadinessStatus.onTrack
            : score >= 40
                ? ReadinessStatus.needsAttention
                : ReadinessStatus.atRisk;

    return TripReadiness(
      tripId:  trip.id,
      score:   score,
      status:  status,
      reasons: reasons,
    );
  }
}
