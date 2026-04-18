import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

// ── DossierSectionCard ────────────────────────────────────────────────────────
/// Premium section wrapper used throughout the dossier detail and form screens.

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
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isInternal ? AppColors.accentLight : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPaddingH,
              AppSpacing.cardPaddingV,
              AppSpacing.cardPaddingH,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (isInternal) ...[
                  Icon(Icons.lock_outline_rounded,
                      size: 12, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: isInternal
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          letterSpacing: 1.1,
                          fontSize: 10,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
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
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: valueWidget ??
                Text(value!,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── InterestBar ───────────────────────────────────────────────────────────────
/// Visual 1–5 interest level indicator.

class InterestBar extends StatelessWidget {
  final String label;
  final int level; // 1–5

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
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ...List.generate(5, (i) {
            final filled = i < clamped;
            return Container(
              width: 20,
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
          const SizedBox(width: 8),
          Text(
            _label(clamped),
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted,
                fontSize: 10),
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
        vertical:   small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: small ? 11 : 12)),
    );
  }
}

class AlertChip extends StatelessWidget {
  final String label;

  const AlertChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
              color: const Color(0xFF92400E), fontSize: 11)),
    );
  }
}
