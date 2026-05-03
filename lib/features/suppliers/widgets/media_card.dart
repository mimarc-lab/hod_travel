import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_media.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MediaCard
//
// Luxury Aman-style card. 3:2 aspect ratio, large rounded corners, soft
// shadow. Hover → subtle zoom + caption overlay. Hero items show a gold pin.
// ─────────────────────────────────────────────────────────────────────────────

class MediaCard extends StatefulWidget {
  final SupplierMedia  media;
  final bool           showControls;    // show edit / hero / delete buttons
  final VoidCallback?  onTap;
  final VoidCallback?  onEdit;
  final VoidCallback?  onSetHero;
  final VoidCallback?  onDelete;

  const MediaCard({
    super.key,
    required this.media,
    this.showControls = false,
    this.onTap,
    this.onEdit,
    this.onSetHero,
    this.onDelete,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.media;

    return MouseRegion(
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      cursor:   SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      _hovered
                    ? AppColors.shadowMedium.withAlpha(40)
                    : AppColors.shadow,
                blurRadius: _hovered ? 20 : 8,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Image / video preview ─────────────────────────────────
                  _MediaPreview(media: m, hovered: _hovered),

                  // ── Caption overlay ───────────────────────────────────────
                  if (m.caption?.isNotEmpty == true || m.title.isNotEmpty)
                    _CaptionOverlay(
                      title:   m.title,
                      caption: m.caption,
                      visible: _hovered,
                    ),

                  // ── Video play icon ───────────────────────────────────────
                  if (m.isVideo) const _VideoPlayBadge(),

                  // ── Hero pin ──────────────────────────────────────────────
                  if (m.isHero) const _HeroBadge(),

                  // ── Controls ──────────────────────────────────────────────
                  if (widget.showControls)
                    _ControlsOverlay(
                      visible:  _hovered,
                      isHero:   m.isHero,
                      onEdit:   widget.onEdit,
                      onHero:   widget.onSetHero,
                      onDelete: widget.onDelete,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Rewrites /object/public/ → /object/authenticated/ and adds Bearer token
// so Image.network can load files from a private Supabase Storage bucket.
String _authUrl(String url) =>
    url.replaceFirst('/object/public/', '/object/authenticated/');

Map<String, String> _storageHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return token != null ? {'Authorization': 'Bearer $token'} : {};
}

// ── Image / video preview ─────────────────────────────────────────────────────

class _MediaPreview extends StatelessWidget {
  final SupplierMedia media;
  final bool          hovered;
  const _MediaPreview({required this.media, required this.hovered});

  @override
  Widget build(BuildContext context) {
    final previewUrl = media.previewUrl;
    final hasPreview = previewUrl.isNotEmpty;

    return AnimatedScale(
      scale:    hovered ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeOutCubic,
      child: hasPreview
          ? Image.network(
              _authUrl(previewUrl),
              headers:      _storageHeaders(),
              fit:          BoxFit.cover,
              errorBuilder: (_, _, _) => _Placeholder(isVideo: media.isVideo),
            )
          : _Placeholder(isVideo: media.isVideo),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool isVideo;
  const _Placeholder({this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Icon(
          isVideo ? Icons.play_circle_outline_rounded : Icons.image_outlined,
          size:  48,
          color: AppColors.border,
        ),
      ),
    );
  }
}

// ── Caption overlay ───────────────────────────────────────────────────────────

class _CaptionOverlay extends StatelessWidget {
  final String  title;
  final String? caption;
  final bool    visible;
  const _CaptionOverlay({
    required this.title,
    required this.caption,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        alignment: Alignment.bottomLeft,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
            stops:  [0.45, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize:      MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color:      Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (caption?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Video play badge ──────────────────────────────────────────────────────────

class _VideoPlayBadge extends StatelessWidget {
  const _VideoPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width:  52,
        height: 52,
        decoration: BoxDecoration(
          color:  Colors.black.withAlpha(120),
          shape:  BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          size:  30,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Hero badge ────────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top:   10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        AppColors.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(40),
              blurRadius: 4,
              offset:     const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 10, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              'HERO',
              style: AppTextStyles.overline.copyWith(
                color:         Colors.white,
                letterSpacing: 0.6,
                fontSize:      9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Controls overlay (edit / hero / delete) ───────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  final bool          visible;
  final bool          isHero;
  final VoidCallback? onEdit;
  final VoidCallback? onHero;
  final VoidCallback? onDelete;

  const _ControlsOverlay({
    required this.visible,
    required this.isHero,
    this.onEdit,
    this.onHero,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBtn(
                icon:    Icons.edit_outlined,
                tooltip: 'Edit',
                onTap:   onEdit,
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon:    isHero ? Icons.star_rounded : Icons.star_outline_rounded,
                tooltip: isHero ? 'Remove hero' : 'Set as hero',
                onTap:   onHero,
                active:  isHero,
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon:    Icons.delete_outline_rounded,
                tooltip: 'Remove',
                onTap:   onDelete,
                danger:  true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final VoidCallback? onTap;
  final bool         active;
  final bool         danger;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.danger  = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xCCFEE2E2)
        : active
            ? AppColors.accent.withAlpha(230)
            : Colors.black.withAlpha(100);
    final iconColor = danger
        ? const Color(0xFFDC2626)
        : active
            ? Colors.white
            : Colors.white;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width:  30,
          height: 30,
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
      ),
    );
  }
}
