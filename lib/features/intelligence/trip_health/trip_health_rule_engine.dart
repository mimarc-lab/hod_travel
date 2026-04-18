import '../../../data/models/operational_alert.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/trip_readiness.dart';
import 'trip_health_model.dart';
import 'trip_health_weights.dart';

// =============================================================================
// TripHealthRuleEngine
//
// Pure static computation: Trip + alerts + readiness → TripHealth.
// No I/O, no state, fully testable.
// =============================================================================

abstract class TripHealthRuleEngine {
  static TripHealth compute({
    required Trip trip,
    required List<OperationalAlert> alerts,
    required TripReadiness readiness,
  }) {
    if (alerts.isEmpty && readiness.score >= 90) {
      return TripHealth.perfect(trip.id);
    }

    // 1. Count alerts by severity (single pass)
    final counts = _countBySeverity(alerts);

    // 2. Compute raw alert penalty
    final penalty = counts.critical * TripHealthWeights.criticalPenalty
                  + counts.high     * TripHealthWeights.highPenalty
                  + counts.medium   * TripHealthWeights.mediumPenalty
                  + counts.low      * TripHealthWeights.lowPenalty;

    // 3. Apply proximity multiplier (trips departing soon incur higher risk)
    final multiplier = _proximityMultiplier(trip.startDate);
    final alertPenalty = (penalty * multiplier).round();

    // 4. Blend readiness deficit
    final readinessDeficit = 100 - readiness.score;
    final readinessPenalty =
        (readinessDeficit * TripHealthWeights.readinessPenaltyWeight).round();

    // 5. Clamp 0–100
    final score = (100 - alertPenalty - readinessPenalty).clamp(0, 100);

    // 6. Derive status from thresholds
    final status = _statusFromScore(score);

    // 7. Build reasons (max 5): top alert titles → proximity note → readiness note
    final reasons = _buildReasons(
        alerts: alerts,
        multiplier: multiplier,
        readiness: readiness);

    // 8. Build one-sentence summary
    final summary = _buildSummary(status, counts, multiplier);

    return TripHealth(
      tripId:      trip.id,
      score:       score,
      status:      status,
      summary:     summary,
      reasons:     reasons,
      issueCounts: counts,
      generatedAt: DateTime.now(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static IssueCounts _countBySeverity(List<OperationalAlert> alerts) {
    var c = 0, h = 0, m = 0, l = 0;
    for (final a in alerts) {
      switch (a.severity) {
        case AlertSeverity.critical: c++; break;
        case AlertSeverity.high:     h++; break;
        case AlertSeverity.medium:   m++; break;
        case AlertSeverity.low:      l++; break;
      }
    }
    return IssueCounts(critical: c, high: h, medium: m, low: l);
  }

  static double _proximityMultiplier(DateTime? startDate) {
    if (startDate == null) return 1.0;
    final daysUntil = startDate.difference(DateTime.now()).inDays;
    if (daysUntil <= 1) return TripHealthWeights.proximityWithin1Day;
    if (daysUntil <= 3) return TripHealthWeights.proximityWithin3Days;
    if (daysUntil <= 7) return TripHealthWeights.proximityWithin7Days;
    return 1.0;
  }

  static TripHealthStatus _statusFromScore(int score) {
    if (score >= TripHealthWeights.readyThreshold)          return TripHealthStatus.ready;
    if (score >= TripHealthWeights.onTrackThreshold)        return TripHealthStatus.onTrack;
    if (score >= TripHealthWeights.needsAttentionThreshold) return TripHealthStatus.needsAttention;
    return TripHealthStatus.atRisk;
  }

  static List<String> _buildReasons({
    required List<OperationalAlert> alerts,
    required double multiplier,
    required TripReadiness readiness,
  }) {
    final reasons = <String>[];

    // Top alert titles (up to 3)
    for (final a in alerts.take(3)) {
      reasons.add(a.title);
    }

    // Proximity warning
    if (multiplier > 1.0) {
      final label = multiplier >= TripHealthWeights.proximityWithin1Day
          ? 'within 24 hours'
          : multiplier >= TripHealthWeights.proximityWithin3Days
              ? 'within 3 days'
              : 'within 7 days';
      reasons.add('Departure $label — unresolved issues carry higher risk now');
    }

    // Readiness note (only if below comfortable threshold)
    if (readiness.score < 70 && readiness.reasons.isNotEmpty) {
      reasons.add('Readiness is ${readiness.score}% — ${readiness.reasons.first}');
    }

    return reasons.take(5).toList();
  }

  static String _buildSummary(
      TripHealthStatus status, IssueCounts counts, double multiplier) {
    if (counts.total == 0) return 'No issues detected. This trip looks good.';

    final blockerCount = counts.critical + counts.high;
    final blocker = blockerCount > 0
        ? '$blockerCount blocker${blockerCount > 1 ? 's' : ''} require immediate attention.'
        : '${counts.medium} issue${counts.medium > 1 ? 's' : ''} need review.';

    final urgency = multiplier >= TripHealthWeights.proximityWithin1Day
        ? ' Departure is imminent.'
        : multiplier >= TripHealthWeights.proximityWithin3Days
            ? ' Departure is very soon.'
            : '';

    return '$blocker$urgency';
  }
}
