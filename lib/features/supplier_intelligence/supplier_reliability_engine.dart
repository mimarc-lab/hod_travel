import '../../data/models/supplier_model.dart';
import 'supplier_metrics_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierReliabilityEngine
//
// Pure, stateless scoring engine. Takes a Supplier and its computed metrics,
// applies a transparent point-based rubric, and returns a ReliabilityTier.
//
// Point rubric (max 9 pts):
//   internalRating  → 0–3 pts  (rating / 5 * 3, rounded)
//   task volume     → 0–2 pts  (≥10: 2, ≥4: 1, else: 0)
//   confirmation %  → 0–2 pts  (≥80%: 2, ≥60%: 1, else: 0)
//   awaitingReply % → –1 to +1 (≤5%: +1, ≤20%: 0, >20%: –1)
//   preferred flag  → +1 pt
//
// Thresholds:
//   ≥ 7 pts → Excellent
//   ≥ 5 pts → Strong
//   ≥ 2 pts → Developing
//    < 2    → Unrated  (also when hasUsageHistory is false)
// ─────────────────────────────────────────────────────────────────────────────

abstract class SupplierReliabilityEngine {
  static ReliabilityTier compute(Supplier supplier, SupplierMetrics metrics) {
    // No usage data → cannot meaningfully rate
    if (!metrics.hasUsageHistory) return ReliabilityTier.unrated;

    int pts = 0;

    // ── internalRating (0–3 pts) ──────────────────────────────────────────
    // Map 0–5 rating onto 0–3 using floor so we don't inflate on low ratings
    pts += (supplier.internalRating / 5.0 * 3.0).round().clamp(0, 3);

    // ── task volume (0–2 pts) ─────────────────────────────────────────────
    if (metrics.taskCount >= 10) {
      pts += 2;
    } else if (metrics.taskCount >= 4) {
      pts += 1;
    }

    // ── confirmation rate (0–2 pts) ───────────────────────────────────────
    final confRate = metrics.confirmationRate ?? 0.0;
    if (confRate >= 0.80) {
      pts += 2;
    } else if (confRate >= 0.60) {
      pts += 1;
    }

    // ── awaiting reply rate (–1 to +1) ────────────────────────────────────
    final awaitRate = metrics.awaitingReplyRate ?? 0.0;
    if (awaitRate <= 0.05) {
      pts += 1;
    } else if (awaitRate > 0.20) {
      pts -= 1;
    }

    // ── preferred flag (+1) ───────────────────────────────────────────────
    if (supplier.preferred) pts += 1;

    // ── map points → tier ─────────────────────────────────────────────────
    if (pts >= 7) return ReliabilityTier.excellent;
    if (pts >= 5) return ReliabilityTier.strong;
    if (pts >= 2) return ReliabilityTier.developing;
    return ReliabilityTier.unrated;
  }

  /// Score breakdown for tooltip / debug — returns individual contributions.
  static Map<String, int> breakdown(Supplier supplier, SupplierMetrics metrics) {
    if (!metrics.hasUsageHistory) {
      return {
        'ratingPts':      0,
        'volumePts':      0,
        'confirmPts':     0,
        'awaitPts':       0,
        'preferredPts':   0,
        'total':          0,
      };
    }

    final ratingPts = (supplier.internalRating / 5.0 * 3.0).round().clamp(0, 3);

    int volumePts = 0;
    if (metrics.taskCount >= 10) { volumePts = 2; }
    else if (metrics.taskCount >= 4) { volumePts = 1; }

    final confRate = metrics.confirmationRate ?? 0.0;
    int confirmPts = 0;
    if (confRate >= 0.80) { confirmPts = 2; }
    else if (confRate >= 0.60) { confirmPts = 1; }

    final awaitRate = metrics.awaitingReplyRate ?? 0.0;
    int awaitPts = 0;
    if (awaitRate <= 0.05) { awaitPts = 1; }
    else if (awaitRate > 0.20) { awaitPts = -1; }

    final preferredPts = supplier.preferred ? 1 : 0;

    return {
      'ratingPts':    ratingPts,
      'volumePts':    volumePts,
      'confirmPts':   confirmPts,
      'awaitPts':     awaitPts,
      'preferredPts': preferredPts,
      'total':        ratingPts + volumePts + confirmPts + awaitPts + preferredPts,
    };
  }
}
