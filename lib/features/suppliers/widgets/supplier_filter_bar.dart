import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

/// Horizontal filter row: category chips + preferred toggle + clear button.
/// Reads and writes directly to the provider.
class SupplierFilterBar extends StatelessWidget {
  final SupplierProvider provider;
  const SupplierFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.isMobile(context)
              ? AppSpacing.pagePaddingHMobile
              : AppSpacing.pagePaddingH,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // "All" chip
            _FilterChip(
              label: 'All',
              isSelected: provider.categoryFilter == null,
              onTap: () => provider.setCategoryFilter(null),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Category chips
            ...SupplierCategory.values.map((cat) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _FilterChip(
                label: cat.label,
                icon: cat.icon,
                color: cat.color,
                isSelected: provider.categoryFilter == cat,
                onTap: () => provider.setCategoryFilter(
                  provider.categoryFilter == cat ? null : cat,
                ),
              ),
            )),

            // Divider
            Container(
              width: 1, height: 20,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),

            // Preferred toggle
            _PreferredToggleChip(
              isOn: provider.preferredOnly,
              onTap: () => provider.setPreferredOnly(!provider.preferredOnly),
            ),

            // Clear filters button (only when filters active)
            if (provider.hasActiveFilters) ...[
              const SizedBox(width: AppSpacing.sm),
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
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
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
              Icon(icon, size: 11, color: isSelected ? c : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? c : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preferred toggle chip ─────────────────────────────────────────────────────

class _PreferredToggleChip extends StatelessWidget {
  final bool isOn;
  final VoidCallback onTap;
  const _PreferredToggleChip({required this.isOn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isOn ? AppColors.accent.withAlpha(22) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn ? AppColors.accent : AppColors.border,
            width: isOn ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 11,
              color: isOn ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Preferred',
              style: AppTextStyles.labelSmall.copyWith(
                color: isOn ? AppColors.accent : AppColors.textSecondary,
                fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
