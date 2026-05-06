import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/user_avatar.dart';

class TeamActivitySection extends StatelessWidget {
  final List<TeamActivityItem> activity;

  const TeamActivitySection({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    // Show latest 5 only
    final visible = activity.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Team Activity'),
        const SizedBox(height: AppSpacing.base),
        if (visible.isEmpty)
          const _EmptyActivity()
        else
          Column(
            children: [
              for (int i = 0; i < visible.length; i++) ...[
                _ActivityRow(item: visible[i]),
                if (i < visible.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 40),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

// ── Activity row ──────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final TeamActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: item.actor, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(
                        text: item.actor.name.split(' ').first,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(text: ' ${item.action} '),
                      TextSpan(
                        text: item.subject,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(item.time),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 24, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No recent activity',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'Team updates will appear here.',
            style:
                AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
