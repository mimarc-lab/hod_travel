import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import 'client_item_card.dart';

/// Renders one day of the client itinerary — header then timeline of items,
/// grouped into morning / afternoon / evening / all-day blocks.
class ClientDaySection extends StatelessWidget {
  final TripDay day;
  final List<ItineraryItem> items;
  final bool wide;

  const ClientDaySection({
    super.key,
    required this.day,
    required this.items,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = wide ? 72.0 : AppSpacing.pagePaddingH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Day marker strip ─────────────────────────────────────────────
        _DayMarker(day: day, hPad: hPad),

        // ── Items grouped by time block ──────────────────────────────────
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: AppSpacing.xl),
            child: Text(
              'Details for this day are being finalised.',
              style: AppTextStyles.bodySmall.copyWith(
                  fontStyle: FontStyle.italic),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: AppSpacing.xl),
            child: _TimelineColumn(items: items),
          ),

        // Subtle section divider before next day
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Container(height: 1, color: AppColors.divider),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}

// ── Day marker ────────────────────────────────────────────────────────────────

class _DayMarker extends StatelessWidget {
  final TripDay day;
  final double hPad;
  const _DayMarker({required this.day, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final dateStr = day.date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(day.date!)
        : null;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.xl, hPad, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Day N" label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentFaint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Day ${day.dayNumber}',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (dateStr != null) ...[
                const SizedBox(width: AppSpacing.base),
                Text(dateStr,
                    style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textMuted)),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // City — editorial large type
          Text(
            day.city,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),

          // Optional day title / theme
          if (day.title != null && day.title!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              day.title!,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ] else if (day.label != null && day.label!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              day.label!,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: AppSpacing.base),

          // Gold underline accent
          Container(width: 36, height: 2, color: AppColors.accent),
        ],
      ),
    );
  }
}

// ── Timeline column ───────────────────────────────────────────────────────────

class _TimelineColumn extends StatelessWidget {
  final List<ItineraryItem> items;
  const _TimelineColumn({required this.items});

  @override
  Widget build(BuildContext context) {
    // Group by time block in display order
    final blockOrder = [
      TimeBlock.allDay,
      TimeBlock.morning,
      TimeBlock.afternoon,
      TimeBlock.evening,
    ];

    final grouped = <TimeBlock, List<ItineraryItem>>{};
    for (final block in blockOrder) {
      final blockItems =
          items.where((i) => i.timeBlock == block).toList();
      // Sort by start time within block
      blockItems.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        final aMin = a.startTime!.hour * 60 + a.startTime!.minute;
        final bMin = b.startTime!.hour * 60 + b.startTime!.minute;
        return aMin.compareTo(bMin);
      });
      if (blockItems.isNotEmpty) grouped[block] = blockItems;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blockOrder)
          if (grouped.containsKey(block)) ...[
            _BlockHeader(block: block),
            const SizedBox(height: AppSpacing.md),
            for (final item in grouped[block]!) ...[
              ClientItemCard(item: item),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
      ],
    );
  }
}

// ── Block header ──────────────────────────────────────────────────────────────

class _BlockHeader extends StatelessWidget {
  final TimeBlock block;
  const _BlockHeader({required this.block});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          block.label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Container(height: 0.5, color: AppColors.border),
        ),
      ],
    );
  }
}
