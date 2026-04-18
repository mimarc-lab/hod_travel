import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/signature_experience.dart';

/// Search field + status + category filter bar for the library screen.
class SignatureExperienceFilterBar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ExperienceStatus? filterStatus;
  final ValueChanged<ExperienceStatus?> onStatusChanged;
  final ExperienceCategory? filterCategory;
  final ValueChanged<ExperienceCategory?> onCategoryChanged;

  const SignatureExperienceFilterBar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.filterStatus,
    required this.onStatusChanged,
    required this.filterCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search ──────────────────────────────────────────────────────────
        SizedBox(
          width: 300,
          height: 38,
          child: TextField(
            onChanged: onSearchChanged,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Search experiences…',
              hintStyle: AppTextStyles.bodySmall,
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.sm),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Status pills ─────────────────────────────────────────────────────
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _FilterPill(
              label: 'All',
              selected: filterStatus == null,
              onTap: () => onStatusChanged(null),
            ),
            ...[
              ExperienceStatus.flagship,
              ExperienceStatus.approved,
              ExperienceStatus.tested,
              ExperienceStatus.draft,
              ExperienceStatus.archived,
            ].map((s) => _FilterPill(
                  label: s.label,
                  selected: filterStatus == s,
                  activeColor: s.color,
                  activeBg: s.backgroundColor,
                  onTap: () => onStatusChanged(filterStatus == s ? null : s),
                )),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // ── Category pills ───────────────────────────────────────────────────
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: ExperienceCategory.values.map((c) => _FilterPill(
                label: c.label,
                selected: filterCategory == c,
                activeColor: c.color,
                activeBg: c.color.withAlpha(26),
                onTap: () => onCategoryChanged(filterCategory == c ? null : c),
              )).toList(),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? activeColor;
  final Color? activeBg;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
    this.activeBg,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? (activeColor ?? Colors.white) : AppColors.textSecondary;
    final bg = selected ? (activeBg ?? AppColors.accent) : AppColors.surface;
    final borderColor = selected ? (activeColor ?? AppColors.accent) : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
