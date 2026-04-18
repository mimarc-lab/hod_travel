import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/operational_alert.dart';
import '../../../data/models/trip_model.dart';
import '../../intelligence/widgets/alert_card.dart';
import '../../intelligence/trip_health/trip_health_model.dart'; // TripHealthStatus, IssueCounts

// ─────────────────────────────────────────────────────────────────────────────
// IntelligenceSection
//
// Dashboard panel: high-priority operational alerts across active trips.
// Renders nothing when the alert list is empty.
// Shows at most 5 alerts; a note indicates any overflow.
// ─────────────────────────────────────────────────────────────────────────────

class IntelligenceSection extends StatelessWidget {
  final List<OperationalAlert> alerts;

  /// Alerts grouped by trip ID — drives the per-trip health snapshot.
  final Map<String, List<OperationalAlert>> alertsByTrip;

  /// All trips — used to resolve trip names in snapshot rows.
  final List<Trip> allTrips;

  final VoidCallback? onRefresh;

  const IntelligenceSection({
    super.key,
    required this.alerts,
    this.alertsByTrip = const {},
    this.allTrips = const [],
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final shown    = alerts.take(5).toList();
    final overflow = alerts.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row (written inline — avoids nesting SectionHeader's Spacer) ──
        Row(
          children: [
            Text('Operational Alerts', style: AppTextStyles.heading2),
            const SizedBox(width: AppSpacing.sm),
            _CountBadge(count: alerts.length),
            const Spacer(),
            if (onRefresh != null)
              TextButton(
                onPressed: onRefresh,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Refresh',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.accent),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Per-trip health snapshot ──────────────────────────────────────────
        if (alertsByTrip.isNotEmpty) ...[
          _TripHealthSnapshot(
              alertsByTrip: alertsByTrip, allTrips: allTrips),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Alert cards ───────────────────────────────────────────────────────
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          separatorBuilder: (context, _) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => AlertCard(alert: shown[i]),
        ),

        if (overflow > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '+$overflow more alert${overflow > 1 ? 's' : ''} — open a trip to see the full list.',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.labelSmall
            .copyWith(color: const Color(0xFFEF4444)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TripHealthSnapshot — per-trip alert breakdown rows
// ─────────────────────────────────────────────────────────────────────────────

class _TripHealthSnapshot extends StatelessWidget {
  final Map<String, List<OperationalAlert>> alertsByTrip;
  final List<Trip> allTrips;

  const _TripHealthSnapshot(
      {required this.alertsByTrip, required this.allTrips});

  @override
  Widget build(BuildContext context) {
    final tripById = {for (final t in allTrips) t.id: t};

    // Count alerts per trip in one pass; sort worst status first.
    final rows = alertsByTrip.entries.map((e) {
      final counts = _countAlerts(e.value);
      return (tripId: e.key, counts: counts);
    }).toList()
      ..sort((a, b) => a.counts.worstStatus.index
          .compareTo(b.counts.worstStatus.index));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            child: Text(
              'Trip Health Snapshot',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rows.map((row) => _SnapshotRow(
                tripName:   tripById[row.tripId]?.name ?? row.tripId,
                status:     row.counts.worstStatus,
                issueCounts: row.counts,
              )),
        ],
      ),
    );
  }

  static IssueCounts _countAlerts(List<OperationalAlert> alerts) {
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
}

class _SnapshotRow extends StatelessWidget {
  final String tripName;
  final TripHealthStatus status;
  final IssueCounts issueCounts;

  const _SnapshotRow({
    required this.tripName,
    required this.status,
    required this.issueCounts,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tripName,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _AlertPills(issueCounts: issueCounts),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            ),
            child: Text(
              status.label,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPills extends StatelessWidget {
  final IssueCounts issueCounts;
  const _AlertPills({required this.issueCounts});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (issueCounts.critical > 0)
          _Pill(count: issueCounts.critical,
                color: AlertSeverity.critical.color),
        if (issueCounts.high > 0)
          _Pill(count: issueCounts.high,
                color: AlertSeverity.high.color),
        if (issueCounts.medium > 0)
          _Pill(count: issueCounts.medium,
                color: AlertSeverity.medium.color),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final int count;
  final Color color;
  const _Pill({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
