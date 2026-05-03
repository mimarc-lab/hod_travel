import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../client_view_theme.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaGrid
//
// Editorial image grid for a component's selected media. Renders on wide
// screens (≥ 600 px). For narrow screens use ClientMediaCarousel instead.
//
// Layout:
//   1 item  → single full-width image
//   2 items → side by side, equal width
//   3+      → hero full-width on top row, remaining items in a 3-col grid
// ─────────────────────────────────────────────────────────────────────────────

class ClientMediaGrid extends StatelessWidget {
  final List<ClientMediaItem> items;

  const ClientMediaGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) return _SingleImage(item: items.first, allItems: items);
    if (items.length == 2) {
      return Row(
        children: [
          Expanded(child: _Thumb(item: items[0], allItems: items, index: 0, aspectRatio: 4/3)),
          const SizedBox(width: 4),
          Expanded(child: _Thumb(item: items[1], allItems: items, index: 1, aspectRatio: 4/3)),
        ],
      );
    }

    // 3+ items: hero full-width, rest in a 3-col grid
    final hero = items.first;
    final rest = items.skip(1).toList();

    return Column(
      children: [
        _Thumb(item: hero, allItems: items, index: 0, aspectRatio: 16/7),
        const SizedBox(height: 4),
        Wrap(
          spacing:     4,
          runSpacing:  4,
          children: [
            for (int i = 0; i < rest.length; i++)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 80 - 8) / 3,
                child: _Thumb(
                  item:        rest[i],
                  allItems:    items,
                  index:       i + 1,
                  aspectRatio: 1.0,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Single full-width image ───────────────────────────────────────────────────

class _SingleImage extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  const _SingleImage({required this.item, required this.allItems});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showClientMediaViewer(context, items: allItems, initialIndex: 0),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _NetImage(item: item),
          ),
        ),
      );
}

// ── Thumbnail tile ────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  final double                aspectRatio;
  const _Thumb({
    required this.item,
    required this.allItems,
    required this.index,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showClientMediaViewer(
            context, items: allItems, initialIndex: index),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetImage(item: item),
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
}

// ── Image.network wrapper ─────────────────────────────────────────────────────

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

class _NetImage extends StatelessWidget {
  final ClientMediaItem item;
  const _NetImage({required this.item});

  @override
  Widget build(BuildContext context) => Image.network(
        item.thumbnailUrl,
        headers:      _storageHeaders(),
        fit:          BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFECEBE8)),
      );
}

// ── Caption row ───────────────────────────────────────────────────────────────

class ClientMediaCaption extends StatelessWidget {
  final String text;
  const ClientMediaCaption({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          text,
          style: ClientViewTheme.accomFeatures.copyWith(
            fontStyle: FontStyle.italic,
            color:     ClientViewTheme.muted,
          ),
          textAlign: TextAlign.center,
        ),
      );
}
