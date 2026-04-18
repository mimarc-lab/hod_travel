import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../trip_health_model.dart';

// =============================================================================
// HealthScoreBadge — compact coloured pill showing status label ± numeric score
// =============================================================================

class HealthScoreBadge extends StatelessWidget {
  final TripHealth health;

  /// Show the numeric score before the label. Default true.
  final bool showScore;

  const HealthScoreBadge({
    super.key,
    required this.health,
    this.showScore = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = health.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showScore) ...[
            Text(
              '${health.score}',
              style: AppTextStyles.labelMedium.copyWith(
                color: status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 1,
              height: 12,
              color: status.color.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            status.label,
            style: AppTextStyles.labelMedium.copyWith(color: status.color),
          ),
        ],
      ),
    );
  }
}
