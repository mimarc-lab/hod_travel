import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import 'client_component_block.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryDayChapter
//
// One day of the client itinerary, presented as a calm editorial chapter.
//
// Structure:
//   ───────────────────────── (full-width hairline)
//   DAY 01                   (gold label, 24 px side-pad)
//   City Name                (large light heading)
//   Thursday, 14 August      (muted date)
//   [optional intro italic]
//            ▬▬▬             (28 px gold accent underline)
//
//   [ClientComponentBlock items — full-bleed have no side-pad;
//    contained / text-only manage their own 16 px pad]
//
//   (36 px bottom breathing room)
//
// The whole chapter fades in + slides up 8 px (180 ms) on first render.
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryDayChapter extends StatelessWidget {
  final TripDay                            day;
  final List<ItineraryItem>               items;
  final bool                              wide;
  final Map<String, List<ClientMediaItem>> mediaByItemId;

  const ItineraryDayChapter({
    super.key,
    required this.day,
    required this.items,
    required this.wide,
    this.mediaByItemId = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hPad = wide
        ? ClientViewTheme.pageHPadWide
        : ClientViewTheme.pageHPadNarrow;

    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve:    Curves.easeOut,
      builder:  (_, v, child) => Opacity(
        opacity: v,
        child:   Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child:  child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width chapter divider
          Container(height: 0.5, color: ClientViewTheme.hairline),
          const SizedBox(height: 28),

          // Chapter heading — padded
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child:   _ChapterHeading(day: day),
          ),
          const SizedBox(height: 24),

          // Items — NO wrapping horizontal padding; each block manages its own
          items.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child:   _EmptyDay(),
                )
              : _ItemList(
                  items:         items,
                  mediaByItemId: mediaByItemId,
                ),

          const SizedBox(height: 36),
        ],
      ),
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
        Text(
          'DAY ${day.dayNumber.toString().padLeft(2, '0')}',
          style: ClientViewTheme.dayLabel,
        ),
        const SizedBox(height: 10),

        Text(day.city, style: ClientViewTheme.cityName),

        if (dateStr != null) ...[
          const SizedBox(height: 6),
          Text(dateStr, style: ClientViewTheme.dayDate),
        ],

        if (intro != null) ...[
          const SizedBox(height: 12),
          Text(intro, style: ClientViewTheme.dayIntro),
        ],

        // Gold accent underline
        const SizedBox(height: 18),
        Container(width: 28, height: 1.5, color: ClientViewTheme.gold),
      ],
    );
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────
// No wrapping horizontal padding — ClientComponentBlock decides its own insets.

class _ItemList extends StatelessWidget {
  final List<ItineraryItem>               items;
  final Map<String, List<ClientMediaItem>> mediaByItemId;
  const _ItemList({required this.items, this.mediaByItemId = const {}});

  @override
  Widget build(BuildContext context) {
    final sorted = List<ItineraryItem>.from(items)..sort(_itemSortOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 28),
          ClientComponentBlock(
            key:   ValueKey(sorted[i].id),
            item:  sorted[i],
            media: mediaByItemId[sorted[i].id] ?? const [],
          ),
        ],
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

  if (a.startTime == null && b.startTime == null) return 0;
  if (a.startTime == null) return 1;
  if (b.startTime == null) return -1;
  return (a.startTime!.hour * 60 + a.startTime!.minute)
      .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
}

// ── Empty day ─────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child:   Text(
          'Details for this day are being finalised.',
          style: ClientViewTheme.dayIntro,
        ),
      );
}
