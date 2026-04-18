import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../next_action_model.dart';

// =============================================================================
// NextActionCard — single row card for one ranked next action
// =============================================================================

class NextActionCard extends StatelessWidget {
  final NextAction action;

  const NextActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriorityDot(priority: action.priority),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  action.description,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (action.actionLabel != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _ActionChip(label: action.actionLabel!),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PriorityDot extends StatelessWidget {
  final NextActionPriority priority;
  const _PriorityDot({required this.priority});

  Color get _color => switch (priority) {
    NextActionPriority.urgent => const Color(0xFF991B1B),
    NextActionPriority.high   => const Color(0xFFEF4444),
    NextActionPriority.medium => const Color(0xFFF59E0B),
    NextActionPriority.low    => const Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  const _ActionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentDark),
      ),
    );
  }
}
