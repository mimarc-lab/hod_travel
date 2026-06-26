import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/client_media_item.dart';
import '../client_view_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showClientMediaViewer
//
// Full-screen media viewer for the client-facing itinerary.
// Black stage, swipe between items, elegant caption at bottom.
// ─────────────────────────────────────────────────────────────────────────────

void showClientMediaViewer(
  BuildContext context, {
  required List<ClientMediaItem> items,
  required int initialIndex,
}) =>
    showDialog<void>(
      context:      context,
      barrierColor: Colors.black.withAlpha(230),
      builder:      (_) => _Viewer(items: items, initialIndex: initialIndex),
    );

// ─────────────────────────────────────────────────────────────────────────────

class _Viewer extends StatefulWidget {
  final List<ClientMediaItem> items;
  final int                   initialIndex;
  const _Viewer({required this.items, required this.initialIndex});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _ctrl;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur  = widget.initialIndex;
    _ctrl = PageController(initialPage: _cur);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int i) => _ctrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve:    Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_cur];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:    EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Page view
            PageView.builder(
              controller:    _ctrl,
              onPageChanged: (i) => setState(() => _cur = i),
              itemCount:     widget.items.length,
              itemBuilder:   (_, i) => _MediaPage(item: widget.items[i]),
            ),

            // Close button
            Positioned(
              top:   MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width:  40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:        Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ),

            // Counter
            Positioned(
              top:  MediaQuery.of(context).padding.top + 22,
              left: 20,
              child: Text(
                '${_cur + 1} / ${widget.items.length}',
                style: const TextStyle(
                  color:      Colors.white60,
                  fontSize:   13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // Prev arrow
            if (_cur > 0)
              _NavArrow(
                align: Alignment.centerLeft,
                icon:  Icons.chevron_left_rounded,
                onTap: () => _go(_cur - 1),
              ),

            // Next arrow
            if (_cur < widget.items.length - 1)
              _NavArrow(
                align: Alignment.centerRight,
                icon:  Icons.chevron_right_rounded,
                onTap: () => _go(_cur + 1),
              ),

            // Caption
            if (item.caption?.isNotEmpty == true)
              Positioned(
                left:   0,
                right:  0,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                child:  _Caption(text: item.caption!),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Single page ───────────────────────────────────────────────────────────────

class _MediaPage extends StatelessWidget {
  final ClientMediaItem item;
  const _MediaPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit:      StackFit.expand,
        children: [
          InteractiveViewer(
            child: Image.network(
              item.displayUrl,
              fit:          BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 48, color: Colors.white24),
              ),
            ),
          ),
          if (item.isVideo)
            Center(
              child: GestureDetector(
                onTap: () async {
                  final raw = item.videoUrl ?? item.displayUrl;
                  final uri = Uri.tryParse(raw);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width:  72,
                  height: 72,
                  decoration: BoxDecoration(
                    color:  Colors.black.withAlpha(160),
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 38, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Caption ───────────────────────────────────────────────────────────────────

class _Caption extends StatelessWidget {
  final String text;
  const _Caption({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:      Colors.white.withAlpha(180),
            fontSize:   13,
            fontWeight: FontWeight.w300,
            height:     1.5,
            fontFamily: ClientViewTheme.eyebrow.fontFamily,
          ),
        ),
      );
}

// ── Navigation arrow ──────────────────────────────────────────────────────────

class _NavArrow extends StatelessWidget {
  final Alignment    align;
  final IconData     icon;
  final VoidCallback onTap;
  const _NavArrow({required this.align, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Align(
          alignment: align,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width:  40,
                height: 40,
                decoration: BoxDecoration(
                  color:        Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: Colors.white70),
              ),
            ),
          ),
        ),
      );
}
