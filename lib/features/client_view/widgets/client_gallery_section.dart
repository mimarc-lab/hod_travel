import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import 'client_media_grid.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientGallerySection
//
// Renders a component's additional media (images after the hero).
// • Wide (≥ 600 px): editorial grid
// • Narrow (mobile): 110 px horizontal thumbnail strip, tap opens viewer
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
      padding: const EdgeInsets.only(top: 12),
      child: wide
          ? _WideGallery(items: items)
          : _ThumbnailStrip(items: items),
    );
  }
}

// ── Wide: editorial grid ──────────────────────────────────────────────────────

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
        if (hero?.caption?.isNotEmpty == true)
          ClientMediaCaption(text: hero!.caption!),
      ],
    );
  }
}

// ── Mobile: 110 px horizontal thumbnail strip ─────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  final List<ClientMediaItem> items;
  const _ThumbnailStrip({required this.items});

  static Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: 16),
        itemCount:       items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => showClientMediaViewer(
              context,
              items:        items,
              initialIndex: index,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 140,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.displayUrl,
                      headers:       _headers(),
                      fit:           BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder:  (_, _, _) =>
                          const ColoredBox(color: Color(0xFFECEBE8)),
                    ),
                    if (item.isVideo)
                      const Center(
                        child: Icon(Icons.play_circle_filled_rounded,
                            size: 32, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
