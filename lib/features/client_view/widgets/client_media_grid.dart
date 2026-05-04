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
//   3+      → hero LEFT + 2×2 thumbnail grid RIGHT
//             Tapping a thumbnail swaps it into the hero.
//             Tapping the hero opens the full-screen viewer.
//             Last grid slot shows +N badge when more than 5 items.
// ─────────────────────────────────────────────────────────────────────────────

class ClientMediaGrid extends StatefulWidget {
  final List<ClientMediaItem> items;
  const ClientMediaGrid({super.key, required this.items});

  @override
  State<ClientMediaGrid> createState() => _ClientMediaGridState();
}

class _ClientMediaGridState extends State<ClientMediaGrid> {
  int _heroIndex = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    if (items.length == 1) {
      return _HeroTile(item: items[0], allItems: items, index: 0, ratio: 16 / 9);
    }

    if (items.length == 2) {
      return Row(
        children: [
          Expanded(child: _HeroTile(item: items[0], allItems: items, index: 0, ratio: 4 / 3)),
          const SizedBox(width: 4),
          Expanded(child: _HeroTile(item: items[1], allItems: items, index: 1, ratio: 4 / 3)),
        ],
      );
    }

    // 3+ → hero + 2×2 grid
    // Grid items: all items except the current hero, in original order
    final gridItems = <({int index, ClientMediaItem item})>[
      for (int i = 0; i < items.length; i++)
        if (i != _heroIndex) (index: i, item: items[i]),
    ];

    final visibleGrid = gridItems.take(4).toList();
    final overflow    = gridItems.length - 4; // hidden beyond the 4 grid slots

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ────────────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _HeroTile(
              item:     items[_heroIndex],
              allItems: items,
              index:    _heroIndex,
              ratio:    4 / 3,
            ),
          ),

          const SizedBox(width: 4),

          // ── 2×2 thumbnail grid ───────────────────────────────────────────
          Expanded(
            flex: 2,
            child: _ThumbnailGrid(
              slots:    visibleGrid,
              allItems: items,
              overflow: overflow,
              onSelect: (itemIndex) => setState(() => _heroIndex = itemIndex),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2×2 grid of thumbnail slots ───────────────────────────────────────────────

class _ThumbnailGrid extends StatelessWidget {
  final List<({int index, ClientMediaItem item})> slots;
  final List<ClientMediaItem>                     allItems;
  final int                                       overflow;
  final ValueChanged<int>                         onSelect;

  const _ThumbnailGrid({
    required this.slots,
    required this.allItems,
    required this.overflow,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell(int slotPos) {
      final slot    = slots[slotPos];
      final isLast  = slotPos == slots.length - 1;
      final showBadge = isLast && overflow > 0;

      if (showBadge) {
        return _OverflowCell(
          item:     slot.item,
          allItems: allItems,
          index:    slot.index,
          overflow: overflow + 1,
        );
      }

      return _ThumbCell(
        item:     slot.item,
        onTap:    () => onSelect(slot.index),
      );
    }

    final hasBottom = slots.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

// ── Hero tile — tapping opens full-screen viewer ──────────────────────────────

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

// ── Thumb cell — tapping swaps into hero (no full-screen) ─────────────────────

class _ThumbCell extends StatelessWidget {
  final ClientMediaItem item;
  final VoidCallback    onTap;

  const _ThumbCell({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetImage(item: item, fullRes: false),
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

// ── Overflow cell — tapping opens full-screen viewer at that index ────────────

class _OverflowCell extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  final int                   overflow;

  const _OverflowCell({
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
          child: SizedBox.expand(
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
