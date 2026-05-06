import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../client_view_theme.dart';
import 'client_media_viewer_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaCarousel
//
// Swipeable horizontal carousel for narrow (mobile) screens.
// Fixed height, peek at next image, dot indicators, minimal chrome.
// ─────────────────────────────────────────────────────────────────────────────

class ClientMediaCarousel extends StatefulWidget {
  final List<ClientMediaItem> items;
  const ClientMediaCarousel({super.key, required this.items});

  @override
  State<ClientMediaCarousel> createState() => _ClientMediaCarouselState();
}

class _ClientMediaCarouselState extends State<ClientMediaCarousel> {
  late final PageController _ctrl;
  int _cur = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller:    _ctrl,
            onPageChanged: (i) => setState(() => _cur = i),
            itemCount:     widget.items.length,
            itemBuilder:   (_, i) => _Slide(
              item:     widget.items[i],
              allItems: widget.items,
              index:    i,
            ),
          ),
        ),

        // Dot indicators — only when multiple items
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.items.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  _cur == i ? 16 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color:        _cur == i
                      ? ClientViewTheme.gold
                      : ClientViewTheme.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],

        // Caption for current item
        if (widget.items[_cur].caption?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(
            widget.items[_cur].caption!,
            style: ClientViewTheme.accomFeatures.copyWith(
              fontStyle: FontStyle.italic,
              color:     ClientViewTheme.muted,
            ),
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Slide tile ────────────────────────────────────────────────────────────────

Map<String, String> _storageHeaders() {
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final token = Supabase.instance.client.auth.currentSession?.accessToken
      ?? (anonKey.isNotEmpty ? anonKey : null);
  if (token == null) return {};
  return {'Authorization': 'Bearer $token'};
}

class _Slide extends StatelessWidget {
  final ClientMediaItem       item;
  final List<ClientMediaItem> allItems;
  final int                   index;
  const _Slide({required this.item, required this.allItems, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showClientMediaViewer(
          context, items: allItems, initialIndex: index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.thumbnailUrl,
                headers:      _storageHeaders(),
                fit:          BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFECEBE8)),
              ),
              if (item.isVideo)
                const Center(
                  child: Icon(Icons.play_circle_filled_rounded,
                      size: 40, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
