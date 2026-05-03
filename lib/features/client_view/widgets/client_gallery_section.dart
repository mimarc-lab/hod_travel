import 'package:flutter/material.dart';
import '../../../data/models/client_media_item.dart';
import 'client_media_carousel.dart';
import 'client_media_grid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientGallerySection
//
// Renders a component's selected media in the client itinerary.
// • Wide (≥ 600 px): editorial grid — hero full-width + supporting grid
// • Narrow (mobile): swipeable carousel
//
// Renders nothing when [items] is empty.
// ─────────────────────────────────────────────────────────────────────────────

class ClientGallerySection extends StatelessWidget {
  final List<ClientMediaItem> items;

  const ClientGallerySection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: wide
          ? _WideGallery(items: items)
          : ClientMediaCarousel(items: items),
    );
  }
}

// ── Wide: grid + optional caption strip below hero ────────────────────────────

class _WideGallery extends StatelessWidget {
  final List<ClientMediaItem> items;
  const _WideGallery({required this.items});

  @override
  Widget build(BuildContext context) {
    final hero = items.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientMediaGrid(items: items),
        // Caption for hero only (if it exists and has text)
        if (hero?.caption?.isNotEmpty == true)
          ClientMediaCaption(text: hero!.caption!),
      ],
    );
  }
}
