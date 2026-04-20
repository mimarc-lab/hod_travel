import '../../data/models/trip_complexity_profile.dart';
import '../../data/models/workflow_task_schedule_rule.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComplexityRules
//
// Maps trip-level complexity inputs → extra days per task group.
// Rules are additive: each qualifying condition adds its increment.
//
// Groups:
//   Pre-Planning | Accommodation | Experiences | Dining
//   Logistics    | Finance       | Client Delivery | Finalization
// ─────────────────────────────────────────────────────────────────────────────

class ComplexityRules {
  /// Returns the number of extra days to add for [task] given [complexity].
  static int adjustmentFor(
    WorkflowTaskScheduleRule task,
    TripComplexityProfile c,
  ) {
    int adj = 0;
    final g = task.groupName;

    // Multi-city trips → extra sourcing and coordination per stop
    if (c.numberOfCities >= 3) {
      if (_isAccommodation(g) || _isExperiences(g) || _isDelivery(g)) adj += 1;
    }

    // Long trips (7+ nights) → more accommodation + experience options to evaluate
    if (c.numberOfDays >= 7) {
      if (_isAccommodation(g) || _isExperiences(g)) adj += 1;
    }

    // Large groups → more coordination for client-facing and finance tasks
    if (c.numberOfGuests >= 6) {
      if (_isDelivery(g) || _isFinance(g)) adj += 1;
    }

    // Signature experiences → deeper sourcing + longer presentation prep
    if (c.hasSignatureExperiences) {
      if (_isExperiences(g)) adj += 2;
      if (_isDelivery(g))    adj += 1;
    }

    // Mobility requirements → additional venue / logistics research
    if (c.hasMobilityRequirements) {
      if (_isAccommodation(g) || _isLogistics(g)) adj += 1;
    }

    // Private transport / aviation → additional logistics coordination
    if (c.hasPrivateTransport) {
      if (_isLogistics(g)) adj += 1;
    }

    return adj;
  }

  // ── Group matchers ─────────────────────────────────────────────────────────

  static bool _isAccommodation(String g) => g == 'Accommodation';
  static bool _isExperiences(String g)   => g == 'Experiences';
  static bool _isDelivery(String g)      => g == 'Client Delivery';
  static bool _isFinance(String g)       => g == 'Finance';
  static bool _isLogistics(String g)     => g == 'Logistics';
}
