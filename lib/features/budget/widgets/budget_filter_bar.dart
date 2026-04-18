import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import '../providers/budget_provider.dart';

/// Horizontal filter bar: category + payment status + currency chips.
class BudgetFilterBar extends StatelessWidget {
  final BudgetProvider provider;
  const BudgetFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Category filters
            _Chip(
              label: 'All',
              isSelected: provider.categoryFilter == null,
              onTap: () => provider.setCategoryFilter(null),
            ),
            const SizedBox(width: AppSpacing.xs),
            ...CostCategory.values.map((cat) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _Chip(
                label: cat.label,
                icon: cat.icon,
                color: cat.color,
                isSelected: provider.categoryFilter == cat,
                onTap: () => provider.setCategoryFilter(
                    provider.categoryFilter == cat ? null : cat),
              ),
            )),

            _Divider(),

            // Payment status filters
            ...PaymentStatus.values.map((s) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _Chip(
                label: s.label,
                color: s.textColor,
                isSelected: provider.statusFilter == s,
                onTap: () => provider.setStatusFilter(
                    provider.statusFilter == s ? null : s),
              ),
            )),

            // Currency filters (if multiple)
            if (provider.availableCurrencies.length > 1) ...[
              _Divider(),
              ...provider.availableCurrencies.map((cur) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _Chip(
                  label: cur,
                  isSelected: provider.currencyFilter == cur,
                  onTap: () => provider.setCurrencyFilter(
                      provider.currencyFilter == cur ? null : cur),
                ),
              )),
            ],

            // Clear
            if (provider.hasActiveFilters) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: provider.clearFilters,
                child: Text('Clear',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 20,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.withAlpha(22) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? c : AppColors.border,
            width: isSelected ? 1.5 : 1,
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
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? c : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}
