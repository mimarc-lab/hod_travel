import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LinkedRecordCard — reusable tile for cross-module linked records
// ─────────────────────────────────────────────────────────────────────────────

/// A single linked record tile used across task detail, itinerary, suppliers,
/// and budget views to show cross-module relationships.
class LinkedRecordCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;       // e.g. "Task", "Supplier", "Itinerary Item"
  final String title;       // the record name
  final String? subtitle;   // status, city, trip name, etc.
  final Color? statusColor;
  final String? statusLabel;
  final VoidCallback? onTap;

  const LinkedRecordCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.title,
    this.subtitle,
    this.statusColor,
    this.statusLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Module icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Label + title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTextStyles.overline
                        .copyWith(fontSize: 9, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Status badge
            if (statusLabel != null && statusColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor!.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel!,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),

            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded,
                  size: 15, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LinkedRecordsSection — labelled group of LinkedRecordCards
// ─────────────────────────────────────────────────────────────────────────────

class LinkedRecordsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const LinkedRecordsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyLinkedRecords — shown when no links exist
// ─────────────────────────────────────────────────────────────────────────────

class EmptyLinkedRecords extends StatelessWidget {
  final String message;
  const EmptyLinkedRecords(
      {super.key, this.message = 'No linked records yet.'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
