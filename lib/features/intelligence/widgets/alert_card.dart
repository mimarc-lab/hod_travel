import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/operational_alert.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertCard — compact card for a single OperationalAlert
// ─────────────────────────────────────────────────────────────────────────────

class AlertCard extends StatelessWidget {
  final OperationalAlert alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final severity = alert.severity;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: severity.color, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppSpacing.cardRadius),
          bottomRight: Radius.circular(AppSpacing.cardRadius),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: severity.bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(alert.type.icon, size: 16, color: severity.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: AppTextStyles.heading3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SeverityChip(severity: severity),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (alert.suggestedAction != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alert.suggestedAction!,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.accent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final AlertSeverity severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: severity.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.label,
        style: AppTextStyles.labelSmall.copyWith(color: severity.color),
      ),
    );
  }
}
