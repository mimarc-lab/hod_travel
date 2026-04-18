import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final NotificationProvider provider;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final n      = notification;
    final unread = !n.isRead;

    return GestureDetector(
      onTap: () => provider.markRead(n.id),
      child: Container(
        color: unread ? AppColors.accentFaint : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingH, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Module icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: n.type.color.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(n.type.icon, size: 16, color: n.type.color),
            ),
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with severity badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          n.title.isNotEmpty ? n.title : n.message,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: unread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _SeverityBadge(severity: n.severity),
                    ],
                  ),

                  // Message (only if separate from title)
                  if (n.title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Meta row: related table tag + time
                  Row(
                    children: [
                      if (n.relatedTable != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(n.relatedTable!,
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        _timeAgo(n.createdAt),
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),

                  // Suggested action chip
                  if (n.suggestedAction != null) ...[
                    const SizedBox(height: 6),
                    _SuggestedActionChip(action: n.suggestedAction!),
                  ],
                ],
              ),
            ),

            // Unread dot
            if (unread)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: AppSpacing.sm),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }
}

// ── Severity badge ────────────────────────────────────────────────────────────

class _SeverityBadge extends StatelessWidget {
  final NotificationSeverity severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    // Only show badges for medium+; low is ambient.
    if (severity == NotificationSeverity.low) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: severity.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.dbValue.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: severity.color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Suggested action chip ─────────────────────────────────────────────────────

class _SuggestedActionChip extends StatelessWidget {
  final String action;
  const _SuggestedActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              action,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
