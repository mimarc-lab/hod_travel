import 'package:flutter/material.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';
import 'accommodation_feature_section.dart';
import 'client_gallery_section.dart';

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

class _TransportMeta extends StatelessWidget {
  final Map<String, dynamic> details;
  const _TransportMeta({required this.details});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    void add(String? v) { if (v != null && v.trim().isNotEmpty) parts.add(v.trim()); }
    add(details['carrier']            as String?);
    add(details['flight_number']      as String?);
    add(details['class_of_service']   as String?);
    add(details['departure_terminal'] as String?);
    add(details['arrival_location']   as String?);
    add(details['seat_number']        as String?);
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: ClientViewTheme.itemMeta,
    );
  }
}

class RefinedItineraryItemBlock extends StatelessWidget {
  final ItineraryItem         item;
  final bool                  showTopRule;
  final List<ClientMediaItem> media;

  const RefinedItineraryItemBlock({
    super.key,
    required this.item,
    this.showTopRule = true,
    this.media       = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (item.type == ItemType.hotel) {
      return AccommodationFeatureSection(item: item, media: media);
    }
    return _StandardBlock(item: item, showTopRule: showTopRule, media: media);
  }
}

// ── Standard block (non-accommodation) ───────────────────────────────────────

class _StandardBlock extends StatelessWidget {
  final ItineraryItem         item;
  final bool                  showTopRule;
  final List<ClientMediaItem> media;

  const _StandardBlock({
    required this.item,
    required this.showTopRule,
    this.media = const [],
  });

  @override
  Widget build(BuildContext context) {
    final timeStr    = ItineraryCopyFormatter.formatTimeRange(item.startTime, item.endTime);
    final typeLabel  = ItineraryCopyFormatter.typeLabel(item.type.dbValue);
    final desc       = ItineraryCopyFormatter.formatDescription(item.description);
    final showSupplier = item.showSupplierName;
    final placeMeta  = ItineraryCopyFormatter.formatPlaceMeta(
      location:     item.location,
      supplierName: showSupplier ? item.supplierName : null,
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

              // Transport details (carrier, flight number, class, etc.)
              if (item.hasTransportDetails) ...[
                const SizedBox(height: 8),
                _TransportMeta(details: item.detailsJson),
              ],

              // Place meta
              if (placeMeta != null) ...[
                const SizedBox(height: 10),
                Text(
                  '·  $placeMeta',
                  style: ClientViewTheme.itemMeta,
                ),
              ],

              // Media gallery (only when media exists)
              if (media.isNotEmpty)
                ClientGallerySection(items: media),
            ],
          ),
        ),
      ],
    );
  }
}
