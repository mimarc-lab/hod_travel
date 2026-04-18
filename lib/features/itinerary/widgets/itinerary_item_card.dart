import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../shared/widgets/approval_chip.dart';
import '../providers/itinerary_provider.dart';
import 'item_editor.dart';

/// Card for a single itinerary item with drag handle, type badge, and actions.
class ItineraryItemCard extends StatelessWidget {
  final ItineraryItem item;
  final ItineraryProvider provider;

  const ItineraryItemCard({
    super.key,
    required this.item,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = item.type.color;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => showItemEditor(context, provider: provider, existing: item),
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — drag is handled by outer ReorderableDragStartListener
              Padding(
                padding: const EdgeInsets.only(top: 2, right: AppSpacing.sm),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 16, color: AppColors.textMuted),
              ),

              // Type icon badge
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.type.icon, size: 15, color: typeColor),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status badge + approval
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.tableCell.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusBadge(status: item.status),
                        const SizedBox(width: AppSpacing.xs),
                        ApprovalStatusChip(
                            status: item.approvalStatus, compact: true),
                      ],
                    ),

                    // Time row
                    if (item.startTime != null) ...[
                      const SizedBox(height: 3),
                      _TimeRow(item: item),
                    ],

                    // Location / supplier
                    if (item.location != null || item.supplierName != null) ...[
                      const SizedBox(height: 3),
                      _MetaRow(item: item),
                    ],

                    // Description / notes snippet
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Delete button
              _DeleteButton(
                onTap: () => provider.deleteItem(item.tripDayId, item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting sub-widgets ────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ItemStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withAlpha(22),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final ItineraryItem item;
  const _TimeRow({required this.item});

  String _fmt(TimeOfDay t) =>
      DateFormat.jm().format(DateTime(2000, 1, 1, t.hour, t.minute));

  @override
  Widget build(BuildContext context) {
    final start = _fmt(item.startTime!);
    final end   = item.endTime != null ? ' – ${_fmt(item.endTime!)}' : '';
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text('$start$end',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final ItineraryItem item;
  const _MetaRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (item.location != null) ...[
          Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              item.location!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (item.location != null && item.supplierName != null)
          Text('  ·  ', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
        if (item.supplierName != null) ...[
          Icon(Icons.storefront_outlined, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              item.supplierName!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm, top: 2),
        child: Icon(Icons.close_rounded, size: 15, color: AppColors.textMuted),
      ),
    );
  }
}
