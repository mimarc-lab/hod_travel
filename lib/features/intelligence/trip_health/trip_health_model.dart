import 'package:flutter/material.dart';

// =============================================================================
// TripHealthStatus
// =============================================================================

enum TripHealthStatus { ready, onTrack, needsAttention, atRisk }

extension TripHealthStatusDisplay on TripHealthStatus {
  String get label => switch (this) {
    TripHealthStatus.ready           => 'Ready',
    TripHealthStatus.onTrack         => 'On Track',
    TripHealthStatus.needsAttention  => 'Needs Attention',
    TripHealthStatus.atRisk          => 'At Risk',
  };

  Color get color => switch (this) {
    TripHealthStatus.ready           => const Color(0xFF10B981),
    TripHealthStatus.onTrack         => const Color(0xFF0EA5E9),
    TripHealthStatus.needsAttention  => const Color(0xFFF59E0B),
    TripHealthStatus.atRisk          => const Color(0xFFEF4444),
  };

  Color get bgColor => switch (this) {
    TripHealthStatus.ready           => const Color(0xFFECFDF5),
    TripHealthStatus.onTrack         => const Color(0xFFE0F2FE),
    TripHealthStatus.needsAttention  => const Color(0xFFFEF3C7),
    TripHealthStatus.atRisk          => const Color(0xFFFEE2E2),
  };
}

// =============================================================================
// IssueCounts — breakdown of alert severity counts
// =============================================================================

class IssueCounts {
  final int critical;
  final int high;
  final int medium;
  final int low;

  const IssueCounts({
    this.critical = 0,
    this.high     = 0,
    this.medium   = 0,
    this.low      = 0,
  });

  int get total        => critical + high + medium + low;
  bool get hasBlockers => critical > 0 || high > 0;

  /// Worst health status derivable from counts alone (no readiness blend).
  /// Used by contexts that have partial data, e.g. the dashboard snapshot.
  TripHealthStatus get worstStatus {
    if (critical > 0 || high > 0) return TripHealthStatus.atRisk;
    if (medium > 0)               return TripHealthStatus.needsAttention;
    if (low > 0)                  return TripHealthStatus.onTrack;
    return TripHealthStatus.ready;
  }

  static const empty = IssueCounts();
}

// =============================================================================
// TripHealth — computed in-memory, never persisted
// =============================================================================

class TripHealth {
  final String tripId;

  /// 0–100. Rule-based, explainable.
  final int score;

  final TripHealthStatus status;

  /// One-sentence narrative summary.
  final String summary;

  /// Top factors driving the score (max 5).
  final List<String> reasons;

  final IssueCounts issueCounts;
  final DateTime generatedAt;

  const TripHealth({
    required this.tripId,
    required this.score,
    required this.status,
    required this.summary,
    required this.reasons,
    required this.issueCounts,
    required this.generatedAt,
  });

  factory TripHealth.perfect(String tripId) => TripHealth(
    tripId:      tripId,
    score:       100,
    status:      TripHealthStatus.ready,
    summary:     'No issues detected. This trip looks good.',
    reasons:     const [],
    issueCounts: IssueCounts.empty,
    generatedAt: DateTime.now(),
  );
}
