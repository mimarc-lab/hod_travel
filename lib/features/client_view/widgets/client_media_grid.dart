import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../client_view_theme.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaGrid
//
// Editorial image grid for wide screens (≥ 600 px).
//
// Layout rules:
//   1 item  → full-width 16/9, full-res
//   2 items → side-by-side 4/3, full-res
//   3 items → full-width 16/9 hero + two 3/2 below, full-res
//   4+      → full-width 16/9 hero + three thumbnails below;
//             last tile shows "+N" overlay when items > 4
// ─────────────────────────────────────────────────────────────────────────────

class ClientMediaGrid extends StatelessWidget {
  final List<ClientMediaItem> items;

  const ClientMediaGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    if (items.length == 1) {
      return _HeroTile(item: items[0], allItems: items, index: 0, ratio: 16 / 9);
    }

    if (items.length == 2) {
      return Row(
        children: [
          Expanded(child: _ThumbTile(item: items[0], allItems: items, index: 0, ratio: 4 / 3, fullRes: true)),
          const SizedBox(width: 4),
          Expanded(child: _ThumbTile(item: items[1], allItems: items, index: 1, ratio: 4 / 3, fullRes: true)),
        ],
      );
    }

    // 3+: hero on top, up to 3 supporting tiles below
    final supporting = items.skip(1).take(3).toList();
    final overflow   = items.length - 4; // >0 when more than 4 total

    return Column(
      children: [
        _HeroTile(item: items[0], allItems: items, index: 0, ratio: 16 / 9),
        const SizedBox(height: 4),
        Row(
          children: [
            for (int i = 0; i < supporting.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: (overflow > 0 && i == supporting.length - 1)
                    ? _OverflowTile(
                        item:     supporting[i],
                        allItems: items,
                        index:    i + 1,
                        overflow: overflow + 1,
                      )
                    : _ThumbTile(
                        item:     supporting[i],
                        allItems: items,
                        index:    i + 1,
                        ratio:    4 / 3,
                      ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Hero tile — full-res, no play overlay ─────────────────────────────────────

class _HeroTile extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  final double                ratio;

  const _HeroTile({
    required this.item,
    required this.allItems,
    required this.index,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showClientMediaViewer(context, items: allItems, initialIndex: index),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _NetImage(item: item, fullRes: true),
          ),
        ),
      );
}

// ── Thumbnail tile ────────────────────────────────────────────────────────────

class _ThumbTile extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  final double                ratio;
  final bool                  fullRes;

  const _ThumbTile({
    required this.item,
    required this.allItems,
    required this.index,
    required this.ratio,
    this.fullRes = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showClientMediaViewer(context, items: allItems, initialIndex: index),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetImage(item: item, fullRes: fullRes),
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

// ── Overflow tile (+N overlay on last visible thumbnail) ──────────────────────

class _OverflowTile extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  final int                   overflow;

  const _OverflowTile({
    required this.item,
    required this.allItems,
    required this.index,
    required this.overflow,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showClientMediaViewer(context, items: allItems, initialIndex: index),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetImage(item: item, fullRes: false),
                Container(color: Colors.black.withAlpha(130)),
                Center(
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      24,
                      fontWeight:    FontWeight.w300,
                      letterSpacing: 1.5,
                    ),
                  ),
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
  final bool            fullRes;
  const _NetImage({required this.item, this.fullRes = false});

  @override
  Widget build(BuildContext context) => Image.network(
        fullRes ? item.displayUrl : item.thumbnailUrl,
        headers:       _storageHeaders(),
        fit:           BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder:  (_, _, _) => const ColoredBox(color: Color(0xFFECEBE8)),
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
