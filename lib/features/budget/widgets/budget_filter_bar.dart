import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import '../providers/budget_provider.dart';

/// Horizontal filter bar: category + payment status + currency chips.
/// All filter logic is unchanged — visual redesign only.
class BudgetFilterBar extends StatelessWidget {
  final BudgetProvider provider;
  const BudgetFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
            child: Row(
              children: [
                // All categories
                _Chip(
                  label: 'All',
                  isSelected: provider.categoryFilter == null,
                  onTap: () => provider.setCategoryFilter(null),
                ),
                const SizedBox(width: 6),

                // Category chips
                ...CostCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: cat.label,
                        icon: cat.icon,
                        color: cat.color,
                        isSelected: provider.categoryFilter == cat,
                        onTap: () => provider.setCategoryFilter(
                            provider.categoryFilter == cat
                                ? null
                                : cat),
                      ),
                    )),

                _BarDivider(),

                // Payment status chips
                ...PaymentStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Chip(
                        label: s.label,
                        color: s.textColor,
                        isSelected: provider.statusFilter == s,
                        onTap: () => provider.setStatusFilter(
                            provider.statusFilter == s ? null : s),
                      ),
                    )),

                // Currency chips (only when multiple currencies present)
                if (provider.availableCurrencies.length > 1) ...[
                  _BarDivider(),
                  ...provider.availableCurrencies.map((cur) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          label: cur,
                          isSelected:
                              provider.currencyFilter == cur,
                          onTap: () => provider.setCurrencyFilter(
                              provider.currencyFilter == cur
                                  ? null
                                  : cur),
                        ),
                      )),
                ],

                // Clear
                if (provider.hasActiveFilters) ...[
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: provider.clearFilters,
                    child: Text(
                      'Clear',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

class _BarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 18,
        color: AppColors.border,
        margin:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? c.withAlpha(120) : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11,
                  color: isSelected ? c : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected ? c : AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
