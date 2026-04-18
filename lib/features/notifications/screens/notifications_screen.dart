import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/notification_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationProvider provider;
  const NotificationsScreen({super.key, required this.provider});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;
  NotificationSeverity? _severityFilter; // null = all severities

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _NotificationsHeader(
            provider:        widget.provider,
            unreadOnly:      _unreadOnly,
            severityFilter:  _severityFilter,
            onToggleUnread:  (v) => setState(() => _unreadOnly = v),
            onSeverityFilter: (s) => setState(() => _severityFilter = s),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.provider,
              builder: (context, _) {
                var items = _unreadOnly
                    ? widget.provider.unread
                    : widget.provider.all;

                if (_severityFilter != null) {
                  items = items
                      .where((n) => n.severity == _severityFilter)
                      .toList();
                }

                // Sort by severity weight desc, then createdAt desc.
                items = List.of(items)
                  ..sort((a, b) {
                    final bySeverity = b.severity.sortWeight
                        .compareTo(a.severity.sortWeight);
                    if (bySeverity != 0) return bySeverity;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: _unreadOnly
                        ? 'All caught up'
                        : 'No notifications yet',
                    subtitle: _unreadOnly
                        ? 'You have no unread notifications.'
                        : 'Activity across your trips will appear here.',
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, i) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, i) => NotificationTile(
                    notification: items[i],
                    provider: widget.provider,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _NotificationsHeader extends StatelessWidget {
  final NotificationProvider provider;
  final bool unreadOnly;
  final NotificationSeverity? severityFilter;
  final ValueChanged<bool> onToggleUnread;
  final ValueChanged<NotificationSeverity?> onSeverityFilter;

  const _NotificationsHeader({
    required this.provider,
    required this.unreadOnly,
    required this.severityFilter,
    required this.onToggleUnread,
    required this.onSeverityFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
          horizontal: hPad, vertical: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications', style: AppTextStyles.displayMedium),
                    ListenableBuilder(
                      listenable: provider,
                      builder: (context, _) => Text(
                        '${provider.unreadCount} unread',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: provider,
                builder: (context, _) {
                  if (provider.unreadCount == 0) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: provider.markAllRead,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('Mark all read',
                          style: AppTextStyles.labelMedium),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Read filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: !unreadOnly,
                  onTap: () => onToggleUnread(false),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Unread',
                  isSelected: unreadOnly,
                  onTap: () => onToggleUnread(true),
                ),
                const SizedBox(width: AppSpacing.base),
                const _Divider(),
                const SizedBox(width: AppSpacing.base),
                // Severity filter chips
                _SeverityChip(
                  label: 'Critical',
                  severity: NotificationSeverity.critical,
                  selected: severityFilter == NotificationSeverity.critical,
                  onTap: () => onSeverityFilter(
                    severityFilter == NotificationSeverity.critical
                        ? null
                        : NotificationSeverity.critical,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SeverityChip(
                  label: 'High',
                  severity: NotificationSeverity.high,
                  selected: severityFilter == NotificationSeverity.high,
                  onTap: () => onSeverityFilter(
                    severityFilter == NotificationSeverity.high
                        ? null
                        : NotificationSeverity.high,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 20, color: AppColors.border);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final NotificationSeverity severity;
  final bool selected;
  final VoidCallback onTap;
  const _SeverityChip({
    required this.label,
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? severity.color.withAlpha(30) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? severity.color : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: severity.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? severity.color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
