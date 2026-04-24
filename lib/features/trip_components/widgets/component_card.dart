import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_component_model.dart';
import '../providers/components_provider.dart';
import 'component_status_chip.dart';

class ComponentCard extends StatelessWidget {
  final TripComponent component;
  final ComponentsProvider provider;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const ComponentCard({
    super.key,
    required this.component,
    required this.provider,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final type = component.componentType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored type accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: type.color,
                  borderRadius: const BorderRadius.only(
                    topLeft:    Radius.circular(AppSpacing.cardRadius),
                    bottomLeft: Radius.circular(AppSpacing.cardRadius),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: type badge + status chip + actions
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: type.bgColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon, size: 12, color: type.color),
                                const SizedBox(width: 4),
                                Text(
                                  type.label,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: type.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ComponentStatusChip(status: component.status, small: true),
                          const Spacer(),
                          _LinkBadges(component: component),
                          const SizedBox(width: AppSpacing.sm),
                          _CardMenu(component: component, provider: provider, onEdit: onEdit),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Title
                      Text(component.title, style: AppTextStyles.heading3),

                      // Supplier
                      if (component.supplierName != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(component.supplierName!, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],

                      const SizedBox(height: AppSpacing.sm),

                      // Date + time + location row
                      Wrap(
                        spacing: AppSpacing.base,
                        runSpacing: AppSpacing.xs,
                        children: [
                          if (component.startDate != null)
                            _MetaChip(
                              icon:  Icons.calendar_today_outlined,
                              label: _formatDateRange(component),
                            ),
                          if (component.startTime != null)
                            _MetaChip(
                              icon:  Icons.access_time_rounded,
                              label: _formatTimeRange(component),
                            ),
                          if (component.locationName != null)
                            _MetaChip(
                              icon:  Icons.location_on_outlined,
                              label: component.locationName!,
                            ),
                        ],
                      ),

                      // Internal notes preview
                      if (component.notesInternal != null && component.notesInternal!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          component.notesInternal!,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateRange(TripComponent c) {
    final fmt = DateFormat('d MMM');
    if (c.endDate != null && c.endDate != c.startDate) {
      return '${fmt.format(c.startDate!)} – ${fmt.format(c.endDate!)}';
    }
    return fmt.format(c.startDate!);
  }

  String _formatTimeRange(TripComponent c) {
    final start = c.startTime ?? '';
    final end   = c.endTime;
    return end != null ? '$start – $end' : start;
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _LinkBadges extends StatelessWidget {
  final TripComponent component;
  const _LinkBadges({required this.component});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (component.isLinkedToItinerary)
          _Badge(icon: Icons.list_alt_rounded, tooltip: 'Linked to Itinerary'),
        if (component.isLinkedToBudget)
          _Badge(icon: Icons.attach_money_rounded, tooltip: 'Linked to Budget'),
        if (component.isLinkedToRunSheet)
          _Badge(icon: Icons.assignment_rounded, tooltip: 'Linked to Run Sheet'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  const _Badge({required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(icon, size: 14, color: AppColors.accent),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final TripComponent      component;
  final ComponentsProvider provider;
  final VoidCallback?      onEdit;
  const _CardMenu({required this.component, required this.provider, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete component?'),
              content: Text('Delete "${component.title}"? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) provider.deleteComponent(component.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit',   child: Text('Edit')),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
