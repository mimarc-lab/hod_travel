import '../../data/models/itinerary_models.dart';
import '../../data/models/operational_alert.dart';
import '../../data/models/trip_model.dart';
import 'detector_utils.dart' as utils;

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryGapDetector
//
// Three checks, in order of severity:
//   1. No itinerary days at all            → High
//   2. Some / all days have no items       → High / Medium
//   3. Multi-night trip, no hotel entry    → Low
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryGapDetector {
  const ItineraryGapDetector._();

  static List<OperationalAlert> detect(
    Trip trip,
    List<TripDay> days,
    Map<String, List<ItineraryItem>> itemsByDayId,
  ) {
    if (days.isEmpty) {
      return [
        OperationalAlert(
          id:              'itin_nodays_${trip.id}',
          tripId:          trip.id,
          type:            AlertType.itineraryGap,
          severity:        AlertSeverity.high,
          title:           'Itinerary Not Started',
          message:         'No itinerary days have been created for ${trip.name}.',
          suggestedAction: 'Open the Itinerary tab and add trip days.',
        ),
      ];
    }

    final alerts    = <OperationalAlert>[];
    final emptyNums = days
        .where((d) => (itemsByDayId[d.id] ?? []).isEmpty)
        .map((d) => d.dayNumber)
        .toList()
      ..sort();

    // ── Empty days ────────────────────────────────────────────────────────────
    if (emptyNums.isNotEmpty) {
      final allEmpty = emptyNums.length == days.length;
      final n        = emptyNums.length;
      alerts.add(OperationalAlert(
        id:       'itin_gaps_${trip.id}',
        tripId:   trip.id,
        type:     AlertType.itineraryGap,
        severity: allEmpty ? AlertSeverity.high : AlertSeverity.medium,
        title:    allEmpty
                    ? 'All Itinerary Days Are Empty'
                    : utils.nOf(n, 'Empty Itinerary Day'),
        message:  '${_dayLabel(emptyNums)} '
                  '${n == 1 ? 'has' : 'have'} no itinerary items.',
        suggestedAction: 'Add itinerary items for the empty '
                         '${utils.pl(n, 'day')}.',
      ));
    }

    // ── No hotel on multi-night trip ──────────────────────────────────────────
    if (days.length > 1) {
      final anyHotel = days.any((d) =>
          (itemsByDayId[d.id] ?? []).any((i) => i.type == ItemType.hotel));
      if (!anyHotel) {
        alerts.add(OperationalAlert(
          id:              'itin_nohotel_${trip.id}',
          tripId:          trip.id,
          type:            AlertType.itineraryGap,
          severity:        AlertSeverity.low,
          title:           'No Accommodation in Itinerary',
          message:         'No hotel or accommodation items have been added for ${trip.name}.',
          suggestedAction: 'Add accommodation entries to the relevant days.',
        ));
      }
    }

    return alerts;
  }

  static String _dayLabel(List<int> nums) {
    if (nums.length == 1)  return 'Day ${nums.first}';
    if (nums.length <= 3)  return nums.map((d) => 'Day $d').join(', ');
    return 'Days ${nums.first}–${nums.last}';
  }
}
