import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReadinessStatus enum
// ─────────────────────────────────────────────────────────────────────────────

enum ReadinessStatus { atRisk, needsAttention, onTrack, ready }

extension ReadinessStatusDisplay on ReadinessStatus {
  String get label => switch (this) {
        ReadinessStatus.atRisk         => 'At Risk',
        ReadinessStatus.needsAttention => 'Needs Attention',
        ReadinessStatus.onTrack        => 'On Track',
        ReadinessStatus.ready          => 'Ready',
      };

  Color get color => switch (this) {
        ReadinessStatus.atRisk         => const Color(0xFFEF4444),
        ReadinessStatus.needsAttention => const Color(0xFFF59E0B),
        ReadinessStatus.onTrack        => const Color(0xFF6366F1),
        ReadinessStatus.ready          => const Color(0xFF10B981),
      };

  Color get bgColor => switch (this) {
        ReadinessStatus.atRisk         => const Color(0xFFFEE2E2),
        ReadinessStatus.needsAttention => const Color(0xFFFEF3C7),
        ReadinessStatus.onTrack        => const Color(0xFFEEF2FF),
        ReadinessStatus.ready          => const Color(0xFFD1FAE5),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// TripReadiness — computed result, not persisted
// ─────────────────────────────────────────────────────────────────────────────

class TripReadiness {
  final String tripId;

  /// 0–100 composite score. Transparent, rule-based.
  final int score;

  final ReadinessStatus status;

  /// Human-readable explanations of deductions.
  final List<String> reasons;

  const TripReadiness({
    required this.tripId,
    required this.score,
    required this.status,
    required this.reasons,
  });

  static const TripReadiness empty = TripReadiness(
    tripId: '',
    score: 0,
    status: ReadinessStatus.atRisk,
    reasons: ['No data available'],
  );
}
