import 'package:flutter/material.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';
import 'client_contained_component.dart';
import 'client_full_bleed_component.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientComponentBlock
//
// Dispatcher — routes each itinerary item to the correct visual treatment.
//
// Decision logic:
//   Full-bleed  → hotel items with media  |  any item with is_hero = true media
//   Contained   → any item with image media (non-hero)
//   Text-only   → no client-visible media
//
// "Full-bleed" = cinematic 240 px edge-to-edge block with gradient overlay.
// "Contained"  = 200 px rounded image + text below, inset 16 px.
// "Text-only"  = open typographic block, no imagery.
//
// Rule: max 1–2 full-bleed blocks per day is enforced by the data (only
// accommodation and hero-marked media qualify), not by arbitrary limits here.
// ─────────────────────────────────────────────────────────────────────────────

class ClientComponentBlock extends StatelessWidget {
  final ItineraryItem         item;
  final List<ClientMediaItem> media;

  const ClientComponentBlock({
    super.key,
    required this.item,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final images = media.where((m) => m.isImage).toList();

    // Full-bleed criteria
    final isHotel     = item.type == ItemType.hotel;
    final hasHeroMark = images.any((m) => m.isHero);
    final isFullBleed = images.isNotEmpty && (isHotel || hasHeroMark);

    if (isFullBleed) {
      return ClientFullBleedComponent(item: item, media: media);
    }

    if (images.isNotEmpty) {
      return ClientContainedComponent(item: item, media: media);
    }

    // Text-only
    return _TextOnlyBlock(item: item);
  }
}

// ── Text-only block ───────────────────────────────────────────────────────────
// Clean typographic treatment — same editorial DNA as the wider design.

class _TextOnlyBlock extends StatelessWidget {
  final ItineraryItem item;
  const _TextOnlyBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width >= 900
        ? ClientViewTheme.pageHPadWide
        : 16.0;

    final timeStr   = ItineraryCopyFormatter.formatTimeRange(
        item.startTime, item.endTime);
    final typeLabel = ItineraryCopyFormatter.typeLabel(item.type.dbValue);
    final desc      = ItineraryCopyFormatter.formatDescription(item.description);
    final placeMeta = ItineraryCopyFormatter.formatPlaceMeta(
      location:     item.location,
      supplierName: item.supplierName,
    );

    // For hotels with no media, use the accommodation label style
    final isHotel = item.type == ItemType.hotel;
    final displayTitle = (isHotel &&
            item.supplierName?.trim().isNotEmpty == true)
        ? item.supplierName!.trim()
        : item.title;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hotel label
          if (isHotel) ...[
            Row(
              children: [
                Text('YOUR ACCOMMODATION',
                    style: ClientViewTheme.accomLabel),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                      height: 0.5,
                      color: ClientViewTheme.gold.withAlpha(80)),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Time + type row
          if (!isHotel && (timeStr != null || typeLabel != null)) ...[
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
            const SizedBox(height: 8),
          ],

          // Title
          Text(
            displayTitle,
            style: isHotel
                ? ClientViewTheme.accomName
                : ClientViewTheme.itemTitle,
          ),

          // Description
          if (desc != null) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: isHotel
                  ? ClientViewTheme.accomDesc
                  : ClientViewTheme.itemDescription,
            ),
          ],

          // Place meta
          if (placeMeta != null) ...[
            const SizedBox(height: 10),
            Text('·  $placeMeta', style: ClientViewTheme.itemMeta),
          ],
        ],
      ),
    );
  }
}
