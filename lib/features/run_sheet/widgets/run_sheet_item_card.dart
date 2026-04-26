import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../providers/run_sheet_provider.dart';
import '../services/run_sheet_view_mode.dart';
import 'run_sheet_contact_block.dart';
import 'run_sheet_item_detail.dart';
import 'run_sheet_status_chip.dart';

class RunSheetItemCard extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;

  const RunSheetItemCard({
    super.key,
    required this.item,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final type       = item.type;
    final isComplete = item.status == RunSheetStatus.completed;
    final isCancelled = item.status == RunSheetStatus.cancelled;
    final dimmed     = isComplete || isCancelled;

    return GestureDetector(
      onTap: () => showRunSheetItemDetail(context, item: item, provider: provider),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1.0,
        child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border:       Border.all(
            color: item.status == RunSheetStatus.issueFlagged
                ? const Color(0xFFFCA5A5)
                : item.status == RunSheetStatus.delayed
                    ? const Color(0xFFFDE68A)
                    : AppColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              color:      AppColors.shadow,
              blurRadius: 4,
              offset:     Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(width: 3, color: type.color),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeader(item: item, provider: provider),
                    _CardBody(item: item, viewMode: provider.viewMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetProvider provider;
  const _CardHeader({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.startTime != null)
                  Text(
                    _fmtTime(item.startTime!),
                    style: AppTextStyles.heading3.copyWith(
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                if (item.endTime != null)
                  Text(
                    _fmtTime(item.endTime!),
                    style: AppTextStyles.labelSmall,
                  ),
                if (item.startTime == null)
                  Text(
                    item.timeBlock.label,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Type badge + title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(type: item.type),
                    const Spacer(),
                    RunSheetStatusButton(
                      current:   item.status,
                      onChanged: (s) => provider.updateStatus(item, s),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: AppTextStyles.heading3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final RunSheetItem     item;
  final RunSheetViewMode viewMode;
  const _CardBody({required this.item, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    final showOps       = RunSheetRoleFilter.showOpsNotes(viewMode);
    final showLogistics = RunSheetRoleFilter.showLogisticsNotes(viewMode);
    final showTransport = RunSheetRoleFilter.showTransportNotes(viewMode);
    final showGuide     = RunSheetRoleFilter.showGuideNotes(viewMode);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location / supplier row
          if (_hasMetaRow)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (item.location?.isNotEmpty ?? false)
                    _MetaChip(
                      icon:  Icons.place_outlined,
                      label: item.location!,
                    ),
                  if (item.supplierName?.isNotEmpty ?? false)
                    _MetaChip(
                      icon:  Icons.storefront_outlined,
                      label: item.supplierName!,
                    ),
                ],
              ),
            ),

          // Description
          if (item.description?.isNotEmpty ?? false) ...[
            Text(
              item.description!,
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          // Contacts — always shown when present
          if (item.hasContacts) ...[
            RunSheetContactBlock(item: item),
            const SizedBox(height: 8),
          ],

          // Transport notes — driver-specific
          if (showTransport && item.hasTransportNotes) ...[
            _NotesBlock(
              icon:        Icons.directions_car_outlined,
              label:       'DRIVER NOTE',
              text:        item.transportNotes!,
              bgColor:     const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              textColor:   const Color(0xFF1E40AF),
              iconColor:   const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 8),
          ],

          // Guide notes — guide-specific
          if (showGuide && item.hasGuideNotes) ...[
            _NotesBlock(
              icon:        Icons.hiking_rounded,
              label:       'GUIDE NOTE',
              text:        item.guideNotes!,
              bgColor:     const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFBBF7D0),
              textColor:   const Color(0xFF166534),
              iconColor:   const Color(0xFF16A34A),
            ),
            const SizedBox(height: 8),
          ],

          // Logistics notes
          if (showLogistics && item.hasLogistics) ...[
            _NotesBlock(
              icon:        Icons.local_shipping_outlined,
              label:       'LOGISTICS',
              text:        item.logisticsNotes!,
              bgColor:     const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              textColor:   const Color(0xFF1E40AF),
              iconColor:   const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 8),
          ],

          // Ops notes — internal staff only
          if (showOps && item.hasOpsNotes) ...[
            _NotesBlock(
              icon:        Icons.sticky_note_2_outlined,
              label:       'OPS NOTE',
              text:        item.opsNotes!,
              bgColor:     const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              textColor:   const Color(0xFF92400E),
              iconColor:   const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 8),
          ],

          // Responsible person
          if (item.responsibleName?.isNotEmpty ?? false)
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Responsible: ',
                  style: AppTextStyles.labelSmall,
                ),
                Text(
                  item.responsibleName!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  bool get _hasMetaRow =>
      (item.location?.isNotEmpty ?? false) ||
      (item.supplierName?.isNotEmpty ?? false);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final ItemType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        type.color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color:         type.color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
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
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _NotesBlock extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   text;
  final Color    bgColor;
  final Color    borderColor;
  final Color    textColor;
  final Color    iconColor;

  const _NotesBlock({
    required this.icon,
    required this.label,
    required this.text,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.overline.copyWith(
                    color:         textColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color:  textColor.withAlpha(200),
                    height: 1.5,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final p = t.period == DayPeriod.am ? 'am' : 'pm';
  return '$h:$m $p';
}
