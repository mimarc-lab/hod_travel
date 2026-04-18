import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_model.dart';
import '../supplier_intelligence_provider.dart';
import '../supplier_metrics_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierSummaryCards
//
// Six KPI cards shown at the top of the supplier intelligence section.
// Renders a loading shimmer when intelligence hasn't loaded yet.
// ─────────────────────────────────────────────────────────────────────────────

class SupplierSummaryCards extends StatelessWidget {
  final Supplier supplier;
  final SupplierIntelligenceProvider intelligenceProvider;

  const SupplierSummaryCards({
    super.key,
    required this.supplier,
    required this.intelligenceProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: intelligenceProvider,
      builder: (context, _) {
        final loading = !intelligenceProvider.isLoaded;
        final metrics = intelligenceProvider.metricsFor(supplier.id);
        final tier    = intelligenceProvider.tierFor(supplier);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiCard(
              label: 'Reliability',
              value: loading ? null : tier.label,
              icon:  loading ? Icons.shield_outlined : tier.icon,
              iconColor: loading ? AppColors.textMuted : tier.color,
              badgeColor: loading ? null : tier.backgroundColor,
              loading: loading,
            ),
            _KpiCard(
              label:    'Last Used',
              value:    loading ? null : metrics.lastUsedLabel,
              icon:     Icons.history_rounded,
              iconColor: AppColors.textSecondary,
              loading:  loading,
            ),
            _KpiCard(
              label:    'Trips Served',
              value:    loading ? null : '${metrics.tripCount}',
              icon:     Icons.luggage_outlined,
              iconColor: AppColors.textSecondary,
              loading:  loading,
            ),
            _KpiCard(
              label:    'Total Tasks',
              value:    loading ? null : '${metrics.taskCount}',
              icon:     Icons.task_alt_rounded,
              iconColor: AppColors.textSecondary,
              loading:  loading,
            ),
            _KpiCard(
              label:    'Confirmed Rate',
              value:    loading ? null : metrics.confirmationRateLabel,
              icon:     Icons.check_circle_outline_rounded,
              iconColor: _confirmedColor(metrics),
              loading:  loading,
            ),
            _KpiCard(
              label:    'Data Freshness',
              value:    loading ? null : metrics.freshnessLabel,
              icon:     Icons.sync_rounded,
              iconColor: loading ? AppColors.textMuted : metrics.freshnessColor,
              loading:  loading,
            ),
          ],
        );
      },
    );
  }

  Color _confirmedColor(SupplierMetrics m) {
    final r = m.confirmationRate;
    if (r == null)  return AppColors.textMuted;
    if (r >= 0.80)  return const Color(0xFF22C55E);
    if (r >= 0.60)  return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ── _KpiCard ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String   label;
  final String?  value;
  final IconData icon;
  final Color    iconColor;
  final Color?   badgeColor;
  final bool     loading;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.badgeColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.overline.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            _Shimmer(width: 72, height: 18)
          else
            Text(
              value ?? '--',
              style: AppTextStyles.heading3.copyWith(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ── _Shimmer ──────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.surfaceAlt,
            AppColors.border,
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ── ReliabilityTierBadge — standalone reusable badge ─────────────────────────

class ReliabilityTierBadge extends StatelessWidget {
  final ReliabilityTier tier;
  final bool compact;

  const ReliabilityTierBadge({
    super.key,
    required this.tier,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical:   compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color:        tier.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: tier.color.withAlpha(60), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: compact ? 10 : 12, color: tier.color),
          const SizedBox(width: 4),
          Text(
            tier.shortLabel,
            style: AppTextStyles.overline.copyWith(
              color:         tier.color,
              fontSize:      compact ? 9 : 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
