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
// Layout:
//   1 item  → full-width 16/9
//   2 items → side-by-side 4/3
//   3-4     → hero LEFT + 2×1 or 2×2 grid RIGHT
//   5+      → hero LEFT + 2×2 grid RIGHT, bottom-right tile shows +N badge
//
//   ┌─────────────────────┬─────────┬─────────┐
//   │                     │  [1]    │  [2]    │
//   │       hero [0]      ├─────────┼─────────┤
//   │                     │  [3]    │  [4]+N  │
//   └─────────────────────┴─────────┴─────────┘
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

    // 3+ → hero + right grid
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _HeroTile(
              item: items[0], allItems: items, index: 0, ratio: 4 / 3,
            ),
          ),

          const SizedBox(width: 4),

          // ── Right 2×2 grid ─────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: _RightGrid(items: items),
          ),
        ],
      ),
    );
  }
}

// ── Right 2×2 grid ────────────────────────────────────────────────────────────
// Shows up to 4 images (indices 1-4). Last slot shows +N when items > 5.

class _RightGrid extends StatelessWidget {
  final List<ClientMediaItem> items;
  const _RightGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    // Slots to fill: indices 1-4 (up to 4 thumbnails)
    final slots    = items.skip(1).take(4).toList();
    final overflow = items.length - 5; // images hidden beyond the 5 visible

    Widget cell(int slotIndex) {
      final itemIndex = slotIndex + 1; // actual index in items list
      final item      = slots[slotIndex];
      final isLast    = slotIndex == slots.length - 1;
      final showBadge = isLast && overflow > 0;

      if (showBadge) {
        return _OverflowTile(
          item:     item,
          allItems: items,
          index:    itemIndex,
          overflow: overflow + 1, // +1 includes the overlaid image itself
        );
      }
      return _ThumbTile(
        item:     item,
        allItems: items,
        index:    itemIndex,
        ratio:    1.0,
      );
    }

    // Build rows: top row always present, bottom row only when ≥ 3 items
    final hasBottom = slots.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row
        Expanded(
          child: Row(
            children: [
              Expanded(child: cell(0)),
              if (slots.length > 1) ...[
                const SizedBox(width: 4),
                Expanded(child: cell(1)),
              ],
            ],
          ),
        ),

        // Bottom row
        if (hasBottom) ...[
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(child: cell(2)),
                if (slots.length > 3) ...[
                  const SizedBox(width: 4),
                  Expanded(child: cell(3)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Hero tile ─────────────────────────────────────────────────────────────────

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
                        size: 28, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ),
      );
}

// ── Overflow tile (+N badge) ──────────────────────────────────────────────────

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetImage(item: item, fullRes: false),
              Container(color: Colors.black.withAlpha(140)),
              Center(
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color:         Colors.white,
                    fontSize:      26,
                    fontWeight:    FontWeight.w300,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
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

// ── Caption ───────────────────────────────────────────────────────────────────

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
