import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import 'cost_status_chip.dart';

/// Four summary metric cards: Net Cost · Sell Price · Margin · Outstanding.
/// Renders as a 2×2 grid on mobile, a single row on desktop/tablet.
class BudgetSummaryCards extends StatelessWidget {
  final BudgetSummary summary;
  final String currency; // display currency label

  const BudgetSummaryCards({
    super.key,
    required this.summary,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final cards = [
      _SummaryCard(
        label: 'Net Cost',
        icon: Icons.receipt_outlined,
        iconColor: const Color(0xFF4A90A4),
        amount: summary.totalNetCost,
        currency: currency,
      ),
      _SummaryCard(
        label: 'Sell Price',
        icon: Icons.sell_outlined,
        iconColor: AppColors.accent,
        amount: summary.totalSellPrice,
        currency: currency,
      ),
      _SummaryCard(
        label: 'Margin',
        icon: Icons.trending_up_rounded,
        iconColor: const Color(0xFF5A9E6F),
        amount: summary.totalMargin,
        currency: currency,
        subLabel: summary.totalSellPrice > 0
            ? '${(summary.totalMargin / summary.totalSellPrice * 100).toStringAsFixed(1)}%'
            : null,
      ),
      _SummaryCard(
        label: 'Outstanding',
        icon: Icons.pending_outlined,
        iconColor: const Color(0xFFD4845A),
        amount: summary.outstandingAmount,
        currency: currency,
        subLabel: '${summary.itemCount} items',
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingHMobile,
          vertical: AppSpacing.base,
        ),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.6,
        children: cards,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical: AppSpacing.base,
      ),
      child: Row(
        children: cards
            .map((c) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: c,
                )))
            .toList(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final double amount;
  final String currency;
  final String? subLabel;

  const _SummaryCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.amount,
    required this.currency,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary)),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CurrencyAmount(
                amount: amount,
                currency: currency,
                style: AppTextStyles.statNumber.copyWith(fontSize: 20),
              ),
              if (subLabel != null)
                Text(subLabel!,
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
