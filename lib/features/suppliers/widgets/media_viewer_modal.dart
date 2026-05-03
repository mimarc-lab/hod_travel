import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';

void showMediaViewer(
  BuildContext context, {
  required List<SupplierMedia> items,
  required int                 initialIndex,
}) =>
    showDialog<void>(
      context:      context,
      barrierColor: Colors.black87,
      builder:      (_) => _Modal(items: items, initialIndex: initialIndex),
    );

// ── Modal ─────────────────────────────────────────────────────────────────────

class _Modal extends StatefulWidget {
  final List<SupplierMedia> items;
  final int                 initialIndex;
  const _Modal({required this.items, required this.initialIndex});

  @override
  State<_Modal> createState() => _ModalState();
}

class _ModalState extends State<_Modal> {
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
        duration: const Duration(milliseconds: 250),
        curve:    Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_cur];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:    const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  900,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopBar(
              current: _cur,
              total:   widget.items.length,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView.builder(
                      controller:    _ctrl,
                      onPageChanged: (i) => setState(() => _cur = i),
                      itemCount:     widget.items.length,
                      itemBuilder:   (_, i) => _Page(media: widget.items[i]),
                    ),
                  ),
                  if (_cur > 0)
                    _Arrow(
                      icon:  Icons.chevron_left_rounded,
                      align: Alignment.centerLeft,
                      onTap: () => _go(_cur - 1),
                    ),
                  if (_cur < widget.items.length - 1)
                    _Arrow(
                      icon:  Icons.chevron_right_rounded,
                      align: Alignment.centerRight,
                      onTap: () => _go(_cur + 1),
                    ),
                ],
              ),
            ),
            if (item.title.isNotEmpty || item.caption?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              _Caption(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int          current;
  final int          total;
  final VoidCallback onClose;
  const _TopBar({
    required this.current,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${current + 1} / $total',
          style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width:  32,
            height: 32,
            decoration: BoxDecoration(
              color:        Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

String _authUrl(String url) =>
    url.replaceFirst('/object/public/', '/object/authenticated/');

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

// ── Single page ───────────────────────────────────────────────────────────────

class _Page extends StatelessWidget {
  final SupplierMedia media;
  const _Page({required this.media});

  @override
  Widget build(BuildContext context) {
    final preview = media.previewUrl;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit:      StackFit.expand,
        children: [
          if (preview.isNotEmpty)
            InteractiveViewer(
              child: Image.network(
                _authUrl(preview),
                headers:      _storageHeaders(),
                fit:          BoxFit.contain,
                errorBuilder: (_, _, _) => const _Broken(),
              ),
            )
          else
            const _Broken(),
          if (media.isVideo)
            Center(
              child: GestureDetector(
                onTap: () async {
                  final raw = (media.videoUrl?.isNotEmpty == true)
                      ? media.videoUrl!
                      : media.fileUrl;
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
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size:  40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.broken_image_outlined, size: 64, color: Colors.white24),
      );
}

// ── Navigation arrow ──────────────────────────────────────────────────────────

class _Arrow extends StatelessWidget {
  final IconData     icon;
  final Alignment    align;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.align, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.white24),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Caption ───────────────────────────────────────────────────────────────────

class _Caption extends StatelessWidget {
  final SupplierMedia item;
  const _Caption({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (item.title.isNotEmpty)
          Text(
            item.title,
            style:     AppTextStyles.labelMedium.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        if (item.caption?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Text(
            item.caption!,
            style:     AppTextStyles.labelSmall.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
