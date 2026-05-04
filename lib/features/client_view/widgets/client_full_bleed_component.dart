import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';
import 'client_gallery_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientFullBleedComponent
//
// Used for accommodation heroes, signature experiences, and any item whose
// media has is_hero = true. Feels cinematic — no padding, no border radius.
//
// Layout:
//   ┌──────────────────────────────────────┐  240 px, edge-to-edge
//   │  [hero image, object-fit cover]      │
//   │  ░░░░ bottom gradient overlay ░░░░░  │
//   │  Title                 (18 px semi)  │
//   │  Description           (13 px, 2 ln) │
//   └──────────────────────────────────────┘
//
// Below:
//   Text content (type label, place meta, extended description)
//   Thumbnail strip if > 1 media item
// ─────────────────────────────────────────────────────────────────────────────

class ClientFullBleedComponent extends StatelessWidget {
  final ItineraryItem         item;
  final List<ClientMediaItem> media;

  const ClientFullBleedComponent({
    super.key,
    required this.item,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width >= 900
        ? ClientViewTheme.pageHPadWide
        : 16.0;

    final heroImage = media.where((m) => m.isImage && m.isHero).firstOrNull
        ?? media.where((m) => m.isImage).firstOrNull;

    final desc      = ItineraryCopyFormatter.formatDescription(item.description);
    final placeMeta = ItineraryCopyFormatter.formatPlaceMeta(
      location:     item.location,
      supplierName: item.supplierName,
    );

    // Images beyond the hero go into the thumbnail strip
    final galleryItems = media.where((m) => m != heroImage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Full-bleed image block ─────────────────────────────────────────
        SizedBox(
          height: 240,
          width:  double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (heroImage != null)
                _FullBleedImage(item: heroImage)
              else
                const ColoredBox(color: Color(0xFF1C1C1A)),

              // Bottom gradient
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x73000000)],
                    stops:  [0.4, 1.0],
                  ),
                ),
              ),

              // Title + description overlay
              Positioned(
                left:   16,
                right:  16,
                bottom: 16,
                child:  _OverlayText(item: item, desc: desc),
              ),
            ],
          ),
        ),

        // ── Text content below image ───────────────────────────────────────
        if (placeMeta != null || galleryItems.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (placeMeta != null)
                  Text('·  $placeMeta', style: ClientViewTheme.itemMeta),
              ],
            ),
          ),

        // ── Thumbnail strip for additional images ──────────────────────────
        if (galleryItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClientGallerySection(items: galleryItems),
          ),
      ],
    );
  }
}

// ── Overlay text (title + 2-line description) ─────────────────────────────────

class _OverlayText extends StatelessWidget {
  final ItineraryItem item;
  final String?       desc;
  const _OverlayText({required this.item, required this.desc});

  @override
  Widget build(BuildContext context) {
    // For hotels: prefer supplier name as the display title
    final displayTitle = (item.type == ItemType.hotel &&
            item.supplierName?.trim().isNotEmpty == true)
        ? item.supplierName!.trim()
        : item.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        Text(
          displayTitle,
          style: const TextStyle(
            fontSize:   18,
            fontWeight: FontWeight.w600,
            color:      Colors.white,
            height:     1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (desc != null) ...[
          const SizedBox(height: 4),
          Text(
            desc!,
            style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w400,
              color:      Color(0xCCFFFFFF), // rgba(255,255,255,0.8)
              height:     1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Full-bleed image with auth headers ───────────────────────────────────────

class _FullBleedImage extends StatelessWidget {
  final ClientMediaItem item;
  const _FullBleedImage({required this.item});

  static Map<String, String> _headers() {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  @override
  Widget build(BuildContext context) => Image.network(
        item.displayUrl,
        headers:       _headers(),
        fit:           BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder:  (_, _, _) =>
            const ColoredBox(color: Color(0xFF1C1C1A)),
      );
}
