import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/signature_experience.dart';

/// Refined search + filter bar for the Experience Library.
///
/// Search: 48px height, 14px radius, subtle shadow, full-width.
/// Status + category filters: horizontally scrollable chip rows.
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
        // ── Search bar ──────────────────────────────────────────────────────
        _EditorialSearchBar(onChanged: onSearchChanged),
        const SizedBox(height: 12),

        // ── Status chips ─────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _FilterChip(
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
              ].map(
                (s) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: s.label,
                    selected: filterStatus == s,
                    activeColor: s.color,
                    activeBg: s.backgroundColor,
                    onTap: () =>
                        onStatusChanged(filterStatus == s ? null : s),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Category chips ───────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (int i = 0; i < ExperienceCategory.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _FilterChip(
                  label: ExperienceCategory.values[i].label,
                  selected: filterCategory == ExperienceCategory.values[i],
                  activeColor: ExperienceCategory.values[i].color,
                  activeBg:
                      ExperienceCategory.values[i].color.withAlpha(26),
                  onTap: () => onCategoryChanged(
                    filterCategory == ExperienceCategory.values[i]
                        ? null
                        : ExperienceCategory.values[i],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Editorial search bar ──────────────────────────────────────────────────────

class _EditorialSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _EditorialSearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.75),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search experiences, destinations, themes...',
          hintStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? activeColor;
  final Color? activeBg;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
    this.activeBg,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? (activeColor ?? AppColors.accent)
        : AppColors.textSecondary;
    final bg = selected
        ? (activeBg ?? AppColors.accentFaint)
        : AppColors.surface;
    final borderColor = selected
        ? (activeColor ?? AppColors.accent).withAlpha(90)
        : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.75),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: fg,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
