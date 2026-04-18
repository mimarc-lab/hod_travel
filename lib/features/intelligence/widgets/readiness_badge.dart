import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_readiness.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReadinessBadge — compact score + label chip
// ─────────────────────────────────────────────────────────────────────────────

class ReadinessBadge extends StatelessWidget {
  final TripReadiness readiness;
  final bool showScore;

  const ReadinessBadge({
    super.key,
    required this.readiness,
    this.showScore = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = readiness.status;
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
              '${readiness.score}',
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

// ─────────────────────────────────────────────────────────────────────────────
// ReasonBullet — one bullet-point line used in both health and readiness cards
// ─────────────────────────────────────────────────────────────────────────────

class ReasonBullet extends StatelessWidget {
  final String text;
  const ReasonBullet({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScoreRing — generic circular progress ring with a numeric score in the centre.
// Used by ReadinessScoreRing and HealthScoreCard.
// ─────────────────────────────────────────────────────────────────────────────

class ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final double size;

  const ScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: AppTextStyles.heading2.copyWith(color: color),
              ),
              Text(
                '%',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReadinessScoreRing — typed wrapper around ScoreRing for TripReadiness
// ─────────────────────────────────────────────────────────────────────────────

class ReadinessScoreRing extends StatelessWidget {
  final TripReadiness readiness;
  final double size;

  const ReadinessScoreRing({
    super.key,
    required this.readiness,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) => ScoreRing(
        score: readiness.score,
        color: readiness.status.color,
        size:  size,
      );
}
