import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

/// Horizontal filter row: category chips + preferred toggle + clear button.
/// Reads and writes directly to the provider — all logic unchanged.
class SupplierFilterBar extends StatelessWidget {
  final SupplierProvider provider;
  const SupplierFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile
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
                // "All" chip
                _FilterChip(
                  label: 'All',
                  isSelected: provider.typeFilter == null,
                  onTap: () => provider.setTypeFilter(null),
                ),
                const SizedBox(width: 6),

                // Type chips
                ...SupplierType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label: _shortLabel(type),
                        icon: type.icon,
                        color: type.color,
                        isSelected: provider.typeFilter == type,
                        onTap: () => provider.setTypeFilter(
                          provider.typeFilter == type ? null : type,
                        ),
                      ),
                    )),

                // Divider
                Container(
                  width: 1,
                  height: 18,
                  color: AppColors.border,
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),

                // Preferred toggle
                _PreferredToggleChip(
                  isOn: provider.preferredOnly,
                  onTap: () =>
                      provider.setPreferredOnly(!provider.preferredOnly),
                ),

                // Clear filters
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
          // Subtle hairline separator from content area
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }

  // Compact label for filter bar chips (Experience Providers → Experience)
  String _shortLabel(SupplierType type) => switch (type) {
        SupplierType.accommodation      => 'Accommodation',
        SupplierType.dining             => 'Dining',
        SupplierType.transport          => 'Transport',
        SupplierType.guide              => 'Guides',
        SupplierType.experienceProvider => 'Experience',
        SupplierType.specialistServices => 'Specialist',
        SupplierType.venue              => 'Venues',
        SupplierType.other              => 'Other',
      };
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
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
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
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isOn
              ? AppColors.accent.withAlpha(20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn
                ? AppColors.accent.withAlpha(120)
                : AppColors.border,
            width: isOn ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.diamond_outlined,
              size: 11,
              color: isOn ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Preferred',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    isOn ? FontWeight.w600 : FontWeight.w400,
                color: isOn
                    ? AppColors.accent
                    : AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
