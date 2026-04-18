import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import 'refined_itinerary_item_block.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryDayChapter
//
// One day of the client itinerary, presented as a calm editorial chapter.
//
// Structure:
//   ─────────────────────────────── (full-width hairline)
//   DAY 01                          (gold label)
//   City Name                       (large light heading)
//   Thursday, 14 August             (muted date)
//   [optional day intro italic]
//                 (gold underline accent, 28px)
//   [items in chronological order — no sub-block headers]
//   (56px bottom breathing room)
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryDayChapter extends StatelessWidget {
  final TripDay day;
  final List<ItineraryItem> items;
  final bool wide;

  const ItineraryDayChapter({
    super.key,
    required this.day,
    required this.items,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = wide
        ? ClientViewTheme.pageHPadWide
        : ClientViewTheme.pageHPadNarrow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width chapter divider
        Container(height: 0.5, color: ClientViewTheme.hairline),
        const SizedBox(height: ClientViewTheme.dayTopGap),

        // Chapter heading
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _ChapterHeading(day: day),
        ),

        // Items
        Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            28,
            hPad,
            ClientViewTheme.dayBottomGap,
          ),
          child: items.isEmpty
              ? _EmptyDay()
              : _ItemList(items: items),
        ),
      ],
    );
  }
}

// ── Chapter heading ───────────────────────────────────────────────────────────

class _ChapterHeading extends StatelessWidget {
  final TripDay day;
  const _ChapterHeading({required this.day});

  @override
  Widget build(BuildContext context) {
    final dateStr = day.date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(day.date!).toUpperCase()
        : null;

    final intro = day.title?.trim().isNotEmpty == true
        ? day.title
        : day.label?.trim().isNotEmpty == true
            ? day.label
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "DAY 01" — small gold label
        Text(
          'DAY ${day.dayNumber.toString().padLeft(2, '0')}',
          style: ClientViewTheme.dayLabel,
        ),
        const SizedBox(height: 10),

        // City name — editorial focal point
        Text(day.city, style: ClientViewTheme.cityName),

        // Date
        if (dateStr != null) ...[
          const SizedBox(height: 6),
          Text(dateStr, style: ClientViewTheme.dayDate),
        ],

        // Optional day intro
        if (intro != null) ...[
          const SizedBox(height: 12),
          Text(intro, style: ClientViewTheme.dayIntro),
        ],

        // Gold underline accent
        const SizedBox(height: 18),
        Container(width: 28, height: 1.5, color: ClientViewTheme.gold),
      ],
    );
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  final List<ItineraryItem> items;
  const _ItemList({required this.items});

  @override
  Widget build(BuildContext context) {
    // Sort: all-day items first, then by time block order, then by start time
    final sorted = List<ItineraryItem>.from(items)
      ..sort(_itemSortOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sorted.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < sorted.length - 1 ? ClientViewTheme.itemSpacing : 0,
            ),
            child: RefinedItineraryItemBlock(
              item:       sorted[i],
              showTopRule: i > 0,
            ),
          ),
      ],
    );
  }
}

int _itemSortOrder(ItineraryItem a, ItineraryItem b) {
  const blockOrder = [
    TimeBlock.allDay,
    TimeBlock.morning,
    TimeBlock.afternoon,
    TimeBlock.evening,
  ];

  final aBlock = blockOrder.indexOf(a.timeBlock);
  final bBlock = blockOrder.indexOf(b.timeBlock);

  if (aBlock != bBlock) return aBlock.compareTo(bBlock);

  // Same block — sort by start time
  if (a.startTime == null && b.startTime == null) return 0;
  if (a.startTime == null) return 1;
  if (b.startTime == null) return -1;
  final aMin = a.startTime!.hour * 60 + a.startTime!.minute;
  final bMin = b.startTime!.hour * 60 + b.startTime!.minute;
  return aMin.compareTo(bMin);
}

// ── Empty day ─────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Details for this day are being finalised.',
        style: ClientViewTheme.dayIntro,
      ),
    );
  }
}
