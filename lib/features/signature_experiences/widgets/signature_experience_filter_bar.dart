import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/signature_experience.dart';

/// Search + category dropdown (inline row) + status chips.
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
        // ── Row 1: Category dropdown + Search ──────────────────────────────
        Row(
          children: [
            _CategoryDropdown(
              selected: filterCategory,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EditorialSearchBar(onChanged: onSearchChanged),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Row 2: Status chips ─────────────────────────────────────────────
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
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
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

// ── Category dropdown button ──────────────────────────────────────────────────

class _CategoryDropdown extends StatelessWidget {
  final ExperienceCategory? selected;
  final ValueChanged<ExperienceCategory?> onChanged;

  const _CategoryDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    final label = selected?.label ?? 'Category';
    final dotColor = selected?.color ?? AppColors.textMuted;
    final borderColor =
        hasSelection ? selected!.color.withAlpha(100) : AppColors.border;
    final bgColor =
        hasSelection ? selected!.color.withAlpha(18) : Colors.white;

    return PopupMenuButton<ExperienceCategory?>(
      onSelected: onChanged,
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      shadowColor: const Color(0x18000000),
      constraints: const BoxConstraints(minWidth: 200),
      itemBuilder: (_) => [
        // All categories option
        PopupMenuItem<ExperienceCategory?>(
          value: null,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'All Categories',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected == null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected == null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              if (selected == null) ...[
                const Spacer(),
                const Icon(Icons.check_rounded,
                    size: 14, color: AppColors.accent),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        // Individual categories
        ...ExperienceCategory.values.map(
          (c) => PopupMenuItem<ExperienceCategory?>(
            value: c,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  c.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected == c
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected == c
                        ? c.color
                        : AppColors.textSecondary,
                  ),
                ),
                if (selected == c) ...[
                  const Spacer(),
                  Icon(Icons.check_rounded, size: 14, color: c.color),
                ],
              ],
            ),
          ),
        ),
      ],
      // Trigger button
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 48,
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
                color: hasSelection ? selected!.color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: hasSelection ? selected!.color : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status filter chip ────────────────────────────────────────────────────────

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
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: fg,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
