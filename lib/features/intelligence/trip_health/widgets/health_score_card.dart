import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../widgets/readiness_badge.dart'; // ScoreRing, ReasonBullet
import '../trip_health_model.dart';
import 'health_score_badge.dart';

// =============================================================================
// HealthScoreCard
//
// Full card shown in the Intelligence panel.  Ring on the left (ScoreRing),
// title + badge + summary + reason bullets on the right.
// =============================================================================

class HealthScoreCard extends StatelessWidget {
  final TripHealth health;

  const HealthScoreCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(
            score: health.score,
            color: health.status.color,
            size:  72,
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Trip Health', style: AppTextStyles.heading2),
                    const SizedBox(width: AppSpacing.sm),
                    HealthScoreBadge(health: health, showScore: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  health.summary,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                if (health.reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...health.reasons.map((r) => ReasonBullet(text: r)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

