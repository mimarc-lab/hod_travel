import 'package:flutter/material.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';
import 'accommodation_feature_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RefinedItineraryItemBlock
//
// Open typographic block for a single itinerary item — no boxed card, no
// color strip, no badge chips. Items feel like paragraphs on a page.
//
// Visual structure per item:
//   ─── (hairline separator, full width)
//   [time]                            [TYPE LABEL]
//   Title of the Experience
//   A curated description in a calm, editorial tone...
//   · Venue Name · Location
//
// Accommodation items delegate to AccommodationFeatureSection.
// ─────────────────────────────────────────────────────────────────────────────

class RefinedItineraryItemBlock extends StatelessWidget {
  final ItineraryItem item;
  final bool showTopRule;

  const RefinedItineraryItemBlock({
    super.key,
    required this.item,
    this.showTopRule = true,
  });

  @override
  Widget build(BuildContext context) {
    if (item.type == ItemType.hotel) {
      return AccommodationFeatureSection(item: item);
    }
    return _StandardBlock(item: item, showTopRule: showTopRule);
  }
}

// ── Standard block (non-accommodation) ───────────────────────────────────────

class _StandardBlock extends StatelessWidget {
  final ItineraryItem item;
  final bool showTopRule;

  const _StandardBlock({required this.item, required this.showTopRule});

  @override
  Widget build(BuildContext context) {
    final timeStr    = ItineraryCopyFormatter.formatTimeRange(item.startTime, item.endTime);
    final typeLabel  = ItineraryCopyFormatter.typeLabel(item.type.dbValue);
    final desc       = ItineraryCopyFormatter.formatDescription(item.description);
    final placeMeta  = ItineraryCopyFormatter.formatPlaceMeta(
      location:     item.location,
      supplierName: item.supplierName,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hairline separator above every item
        if (showTopRule)
          Container(height: 0.5, color: ClientViewTheme.hairline),

        Padding(
          padding: const EdgeInsets.only(
            top:    22,
            bottom: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time + type label row
              if (timeStr != null || typeLabel != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (timeStr != null)
                      Text(timeStr, style: ClientViewTheme.itemTime),
                    const Spacer(),
                    if (typeLabel != null)
                      Text(typeLabel, style: ClientViewTheme.itemTypeLabel),
                  ],
                ),

              if (timeStr != null || typeLabel != null)
                const SizedBox(height: 8),

              // Title
              Text(item.title, style: ClientViewTheme.itemTitle),

              // Description
              if (desc != null) ...[
                const SizedBox(height: 8),
                Text(desc, style: ClientViewTheme.itemDescription),
              ],

              // Place meta
              if (placeMeta != null) ...[
                const SizedBox(height: 10),
                Text(
                  '·  $placeMeta',
                  style: ClientViewTheme.itemMeta,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
