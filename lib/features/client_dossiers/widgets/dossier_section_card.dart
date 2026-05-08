import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

// ── DossierSectionCard ────────────────────────────────────────────────────────

class DossierSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool isInternal;

  const DossierSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.isInternal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isInternal ? const Color(0xFFFFFBF5) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInternal
              ? AppColors.accentLight
              : const Color(0xFFEDECEA),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPaddingH,
              AppSpacing.cardPaddingV,
              AppSpacing.cardPaddingH,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isInternal) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.accentFaint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isInternal
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          letterSpacing: -0.1,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isInternal
                ? AppColors.accentLight.withAlpha(120)
                : AppColors.divider,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPaddingH),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── DossierInfoRow ────────────────────────────────────────────────────────────

class DossierInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const DossierInfoRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null && valueWidget == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ── InterestBar ───────────────────────────────────────────────────────────────

class InterestBar extends StatelessWidget {
  final String label;
  final int level;

  const InterestBar({super.key, required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(1, 5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          ...List.generate(5, (i) {
            final filled = i < clamped;
            return Container(
              width: 22,
              height: 6,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: filled ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(3),
                border: filled
                    ? null
                    : Border.all(color: AppColors.border, width: 0.5),
              ),
            );
          }),
          const SizedBox(width: 10),
          Text(
            _label(clamped),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _label(int v) => switch (v) {
        1 => 'None',
        2 => 'Low',
        3 => 'Moderate',
        4 => 'High',
        5 => 'Essential',
        _ => '',
      };
}

// ── PreferenceChip ────────────────────────────────────────────────────────────

class PreferenceChip extends StatelessWidget {
  final String label;
  final bool small;

  const PreferenceChip({super.key, required this.label, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.3,
        ),
      ),
    );
  }
}

class AlertChip extends StatelessWidget {
  final String label;

  const AlertChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF92400E),
          height: 1.3,
        ),
      ),
    );
  }
}
