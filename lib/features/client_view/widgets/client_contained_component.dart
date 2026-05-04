import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../client_view_theme.dart';
import '../services/itinerary_copy_formatter.dart';
import 'client_gallery_section.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientContainedComponent
//
// Used for dining, transfers, secondary experiences, and items without a
// hero-marked image. Inset with padding, rounded image, text below.
//
// Layout:
//   [16 px inset on both sides]
//   ┌─────────────────────────────────┐  200 px, radius 16
//   │  [image, object-fit cover]      │
//   └─────────────────────────────────┘
//   Title                   16 px semibold
//   Description             14 px, max 3 lines
//   · Venue · Location      12 px muted
//   [thumbnail strip if > 1 image]
//
// Tapping the image → opens fullscreen viewer (scale 1.02 feedback).
// ─────────────────────────────────────────────────────────────────────────────

class ClientContainedComponent extends StatelessWidget {
  final ItineraryItem         item;
  final List<ClientMediaItem> media;

  const ClientContainedComponent({
    super.key,
    required this.item,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width >= 900
        ? ClientViewTheme.pageHPadWide
        : 16.0;

    final heroImage = media.where((m) => m.isImage).firstOrNull;
    final timeStr   = ItineraryCopyFormatter.formatTimeRange(
        item.startTime, item.endTime);
    final typeLabel = ItineraryCopyFormatter.typeLabel(item.type.dbValue);
    final desc      = ItineraryCopyFormatter.formatDescription(item.description);
    final placeMeta = ItineraryCopyFormatter.formatPlaceMeta(
      location:     item.location,
      supplierName: item.supplierName,
    );

    // Remaining images for the strip (exclude the hero already shown above)
    final galleryItems =
        heroImage != null ? media.where((m) => m != heroImage).toList() : media;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────────────────────
          if (heroImage != null) ...[
            _ScaleTapImage(
              item:     heroImage,
              allMedia: media,
            ),
            const SizedBox(height: 12),
          ],

          // ── Time + type row ───────────────────────────────────────────────
          if (timeStr != null || typeLabel != null) ...[
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
            const SizedBox(height: 6),
          ],

          // ── Title ─────────────────────────────────────────────────────────
          Text(
            item.title,
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w600,
              color:      Color(0xFF111111),
              height:     1.3,
            ),
          ),

          // ── Description ───────────────────────────────────────────────────
          if (desc != null) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              style: const TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w400,
                color:      Color(0xFF555555),
                height:     1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Place meta ────────────────────────────────────────────────────
          if (placeMeta != null) ...[
            const SizedBox(height: 8),
            Text('·  $placeMeta', style: ClientViewTheme.itemMeta),
          ],

          // ── Additional images strip ───────────────────────────────────────
          if (galleryItems.isNotEmpty)
            ClientGallerySection(items: galleryItems),
        ],
      ),
    );
  }
}

// ── Scale-on-tap image that opens the viewer ──────────────────────────────────

class _ScaleTapImage extends StatefulWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allMedia;

  const _ScaleTapImage({required this.item, required this.allMedia});

  @override
  State<_ScaleTapImage> createState() => _ScaleTapImageState();
}

class _ScaleTapImageState extends State<_ScaleTapImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static Map<String, String> _headers() {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) {
        _ctrl.reverse();
        showClientMediaViewer(
          context,
          items:        widget.allMedia,
          initialIndex: widget.allMedia.indexOf(widget.item),
        );
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            width:  double.infinity,
            child:  Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.item.displayUrl,
                  headers:       _headers(),
                  fit:           BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder:  (_, _, _) =>
                      const ColoredBox(color: Color(0xFFECEBE8)),
                ),
                if (widget.item.isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_filled_rounded,
                        size: 40, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
