import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_control_row.dart';
import '../../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';

/// Compact filter row: type dropdown + preferred toggle + clear.
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
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
            child: Row(
              children: [
                Expanded(
                  child: AdaptiveControlRow(
                    gap: 10,
                    children: [
                      _SupplierTypeDropdown(
                        selected: provider.typeFilter,
                        onChanged: provider.setTypeFilter,
                      ),
                      _PreferredToggleChip(
                        isOn: provider.preferredOnly,
                        onTap: () =>
                            provider.setPreferredOnly(!provider.preferredOnly),
                      ),
                    ],
                  ),
                ),
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
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

// ── Type dropdown ─────────────────────────────────────────────────────────────

class _SupplierTypeDropdown extends StatelessWidget {
  final SupplierType? selected;
  final ValueChanged<SupplierType?> onChanged;

  const _SupplierTypeDropdown({
    required this.selected,
    required this.onChanged,
  });

  static const _typeLabels = {
    SupplierType.accommodation:      'Accommodation',
    SupplierType.dining:             'Dining',
    SupplierType.transport:          'Transport',
    SupplierType.guide:              'Guides',
    SupplierType.experienceProvider: 'Experience',
    SupplierType.specialistServices: 'Specialist',
    SupplierType.venue:              'Venues',
    SupplierType.other:              'Other',
  };

  Color get _dotColor =>
      selected != null ? selected!.color : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    final label = hasSelection ? _typeLabels[selected]! : 'Type';
    final dotColor = _dotColor;
    final borderColor =
        hasSelection ? dotColor.withAlpha(100) : AppColors.border;
    final bgColor =
        hasSelection ? dotColor.withAlpha(18) : AppColors.surface;

    return PopupMenuButton<SupplierType?>(
      onSelected: onChanged,
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      shadowColor: const Color(0x18000000),
      constraints: const BoxConstraints(minWidth: 200),
      itemBuilder: (_) => [
        PopupMenuItem<SupplierType?>(
          value: null,
          child: _DropdownItem(
            label: 'All Types',
            dotColor: AppColors.textMuted,
            isSelected: selected == null,
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...SupplierType.values.map(
          (t) => PopupMenuItem<SupplierType?>(
            value: t,
            child: _DropdownItem(
              label: _typeLabels[t]!,
              dotColor: t.color,
              isSelected: selected == t,
            ),
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.75),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight:
                    hasSelection ? FontWeight.w600 : FontWeight.w400,
                color: hasSelection ? dotColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: hasSelection ? dotColor : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool isSelected;
  const _DropdownItem({
    required this.label,
    required this.dotColor,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? dotColor : AppColors.textSecondary,
          ),
        ),
        if (isSelected) ...[
          const Spacer(),
          Icon(Icons.check_rounded, size: 14, color: dotColor),
        ],
      ],
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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isOn ? AppColors.accent.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn
                ? AppColors.accent.withAlpha(100)
                : AppColors.border,
            width: 0.75,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.diamond_outlined,
              size: 13,
              color: isOn ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Preferred',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                color: isOn ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
