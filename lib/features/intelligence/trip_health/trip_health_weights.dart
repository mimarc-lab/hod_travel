// =============================================================================
// TripHealthWeights
//
// All scoring constants in one place so rules are easy to read and tune.
// =============================================================================

abstract class TripHealthWeights {
  // ── Per-alert severity penalties (subtracted from 100) ────────────────────
  static const int criticalPenalty = 22;
  static const int highPenalty     = 12;
  static const int mediumPenalty   =  5;
  static const int lowPenalty      =  1;

  // ── Proximity multipliers ─────────────────────────────────────────────────
  // Applied to the total alert penalty when the trip is starting soon.
  // A trip with unresolved issues 2 days before departure is far more risky
  // than the same issues 6 weeks out.
  static const double proximityWithin7Days = 1.4;
  static const double proximityWithin3Days = 2.0;
  static const double proximityWithin1Day  = 2.5;

  // ── Readiness blend ───────────────────────────────────────────────────────
  // Fraction of the readiness deficit (100 − readiness.score) added to
  // penalty. At 0.25: 60% readiness → +10 penalty; 40% readiness → +15.
  static const double readinessPenaltyWeight = 0.25;

  // ── Status thresholds ─────────────────────────────────────────────────────
  static const int readyThreshold          = 85; // 85–100 → Ready
  static const int onTrackThreshold        = 70; // 70–84 → On Track
  static const int needsAttentionThreshold = 50; // 50–69 → Needs Attention
  //                                              //  0–49 → At Risk
}
