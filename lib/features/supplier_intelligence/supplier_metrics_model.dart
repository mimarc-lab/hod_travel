import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReliabilityTier — transparent, rule-based performance bracket
// ─────────────────────────────────────────────────────────────────────────────

enum ReliabilityTier {
  excellent,
  strong,
  developing,
  unrated;

  String get label {
    switch (this) {
      case ReliabilityTier.excellent:   return 'Excellent';
      case ReliabilityTier.strong:      return 'Strong';
      case ReliabilityTier.developing:  return 'Developing';
      case ReliabilityTier.unrated:     return 'Unrated';
    }
  }

  Color get color {
    switch (this) {
      case ReliabilityTier.excellent:   return const Color(0xFF22C55E); // green-500
      case ReliabilityTier.strong:      return const Color(0xFF3B82F6); // blue-500
      case ReliabilityTier.developing:  return const Color(0xFFF59E0B); // amber-500
      case ReliabilityTier.unrated:     return const Color(0xFF94A3B8); // slate-400
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ReliabilityTier.excellent:   return const Color(0xFFDCFCE7); // green-100
      case ReliabilityTier.strong:      return const Color(0xFFDBEAFE); // blue-100
      case ReliabilityTier.developing:  return const Color(0xFFFEF3C7); // amber-100
      case ReliabilityTier.unrated:     return const Color(0xFFF1F5F9); // slate-100
    }
  }

  IconData get icon {
    switch (this) {
      case ReliabilityTier.excellent:   return Icons.verified_rounded;
      case ReliabilityTier.strong:      return Icons.thumb_up_alt_rounded;
      case ReliabilityTier.developing:  return Icons.trending_up_rounded;
      case ReliabilityTier.unrated:     return Icons.help_outline_rounded;
    }
  }

  /// Short descriptor shown in list-view badge
  String get shortLabel {
    switch (this) {
      case ReliabilityTier.excellent:   return 'Excellent';
      case ReliabilityTier.strong:      return 'Strong';
      case ReliabilityTier.developing:  return 'Developing';
      case ReliabilityTier.unrated:     return 'Unrated';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SupplierMetrics — computed performance snapshot for one supplier
// ─────────────────────────────────────────────────────────────────────────────

class SupplierMetrics {
  /// Total tasks linked to this supplier.
  final int taskCount;

  /// Tasks with status == confirmed.
  final int confirmedCount;

  /// Tasks with status == awaitingReply.
  final int awaitingReplyCount;

  /// Tasks where dueDate < now and status is not confirmed/cancelled.
  final int overdueCount;

  /// Distinct trip IDs this supplier has been used in.
  final Set<String> tripIds;

  /// Most recent task travelDate (used as "last used" proxy).
  final DateTime? lastUsedDate;

  /// Number of enrichment records (contact updates, notes, etc.).
  final int enrichmentCount;

  /// Timestamp of the most recent enrichment entry.
  final DateTime? lastEnrichedAt;

  const SupplierMetrics({
    required this.taskCount,
    required this.confirmedCount,
    required this.awaitingReplyCount,
    required this.overdueCount,
    required this.tripIds,
    required this.lastUsedDate,
    required this.enrichmentCount,
    required this.lastEnrichedAt,
  });

  /// Empty metrics — used before data loads or for suppliers with no history.
  factory SupplierMetrics.empty() => SupplierMetrics(
        taskCount:          0,
        confirmedCount:     0,
        awaitingReplyCount: 0,
        overdueCount:       0,
        tripIds:            const {},
        lastUsedDate:       null,
        enrichmentCount:    0,
        lastEnrichedAt:     null,
      );

  // ── Derived getters ────────────────────────────────────────────────────────

  int get tripCount => tripIds.length;

  bool get hasUsageHistory => taskCount > 0;

  /// 0.0 – 1.0; null when no tasks.
  double? get confirmationRate =>
      taskCount == 0 ? null : confirmedCount / taskCount;

  /// 0.0 – 1.0; null when no tasks.
  double? get awaitingReplyRate =>
      taskCount == 0 ? null : awaitingReplyCount / taskCount;

  /// Calendar days since lastUsedDate; null if never used.
  int? get daysSinceLastUsed {
    if (lastUsedDate == null) return null;
    return DateTime.now().difference(lastUsedDate!).inDays;
  }

  /// Calendar days since lastEnrichedAt; null if never enriched.
  int? get daysSinceEnrichment {
    if (lastEnrichedAt == null) return null;
    return DateTime.now().difference(lastEnrichedAt!).inDays;
  }

  /// Human-readable "last used" label.
  String get lastUsedLabel {
    final days = daysSinceLastUsed;
    if (days == null) return 'Never used';
    if (days == 0)    return 'Today';
    if (days == 1)    return 'Yesterday';
    if (days < 7)     return '$days days ago';
    if (days < 30)    return '${(days / 7).round()} weeks ago';
    if (days < 365)   return '${(days / 30).round()} months ago';
    return '${(days / 365).round()} years ago';
  }

  /// Human-readable "data freshness" label based on enrichment age.
  String get freshnessLabel {
    final days = daysSinceEnrichment;
    if (days == null)  return 'No data';
    if (days < 30)     return 'Fresh';
    if (days < 90)     return 'Recent';
    if (days < 180)    return 'Aging';
    return 'Stale';
  }

  Color get freshnessColor {
    final days = daysSinceEnrichment;
    if (days == null)  return const Color(0xFF94A3B8);
    if (days < 30)     return const Color(0xFF22C55E);
    if (days < 90)     return const Color(0xFF3B82F6);
    if (days < 180)    return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  /// Formatted confirmation rate, e.g. "72%"; "--" when no tasks.
  String get confirmationRateLabel {
    final r = confirmationRate;
    if (r == null) return '--';
    return '${(r * 100).round()}%';
  }
}
