import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import 'cost_status_chip.dart';

/// Four KPI cards: Trip Revenue · Operational Cost · Projected Margin · Outstanding.
/// Renders as 2×2 grid on mobile, single row on desktop/tablet.
/// Includes a financial health indicator line beneath the cards.
class BudgetSummaryCards extends StatelessWidget {
  final BudgetSummary summary;
  final String currency;

  const BudgetSummaryCards({
    super.key,
    required this.summary,
    required this.currency,
  });

  String? get _contextMargin {
    if (summary.totalSellPrice <= 0) return null;
    final pct =
        (summary.totalMargin / summary.totalSellPrice * 100)
            .toStringAsFixed(1);
    return '$pct% margin';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    final cards = [
      _KpiCard(
        label: 'Trip Revenue',
        accentColor: const Color(0xFFC9A96E),
        amount: summary.totalSellPrice,
        currency: currency,
        contextLine: '${summary.itemCount} items',
      ),
      _KpiCard(
        label: 'Operational Cost',
        accentColor: const Color(0xFF4A90A4),
        amount: summary.totalNetCost,
        currency: currency,
        contextLine: 'Total net cost',
      ),
      _KpiCard(
        label: 'Projected Margin',
        accentColor: const Color(0xFF5A9E6F),
        amount: summary.totalMargin,
        currency: currency,
        contextLine: _contextMargin,
      ),
      _KpiCard(
        label: 'Outstanding Payments',
        accentColor: const Color(0xFFD4845A),
        amount: summary.outstandingAmount,
        currency: currency,
        contextLine: 'Unpaid & pending',
      ),
    ];

    final content = isMobile
        ? GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: cards,
          )
        : Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: c,
                      ),
                    ))
                .toList(),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          _HealthIndicator(summary: summary),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatefulWidget {
  final String label;
  final Color accentColor;
  final double amount;
  final String currency;
  final String? contextLine;

  const _KpiCard({
    required this.label,
    required this.accentColor,
    required this.amount,
    required this.currency,
    this.contextLine,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(_hovered ? 0x0E000000 : 0x06000000),
              blurRadius: _hovered ? 20 : 8,
              offset: Offset(0, _hovered ? 6 : 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent dot + label
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Amount
            CurrencyAmount(
              amount: widget.amount,
              currency: widget.currency,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            // Context line
            if (widget.contextLine != null) ...[
              const SizedBox(height: 3),
              Text(
                widget.contextLine!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Financial health indicator ────────────────────────────────────────────────

class _HealthIndicator extends StatelessWidget {
  final BudgetSummary summary;
  const _HealthIndicator({required this.summary});

  String get _label {
    if (summary.totalSellPrice <= 0) return '';
    final pct = summary.totalMargin / summary.totalSellPrice * 100;
    if (pct >= 25) return 'Healthy Margin — ${pct.toStringAsFixed(1)}%';
    if (pct >= 15) return 'Solid Margin — ${pct.toStringAsFixed(1)}%';
    if (summary.outstandingAmount > summary.totalSellPrice * 0.6) {
      return 'Outstanding payments require attention';
    }
    return '';
  }

  Color get _color {
    if (summary.totalSellPrice <= 0) return AppColors.textMuted;
    final pct = summary.totalMargin / summary.totalSellPrice * 100;
    if (pct >= 25) return const Color(0xFF5A9E6F);
    if (pct >= 15) return const Color(0xFF5A9E6F);
    if (summary.outstandingAmount > summary.totalSellPrice * 0.6) {
      return const Color(0xFFD4845A);
    }
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label.isEmpty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _color,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
