import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaItem — client-safe media presentation DTO.
//
// Never exposes: storage paths, uploaded_by, supplier metadata, internal tags,
// team IDs, or any operational field. Only the minimum required to render
// an image or video beautifully in the client-facing itinerary.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ClientMediaItem {
  /// 'image' or 'video'.
  final String  mediaType;

  /// Authenticated URL — ready to pass directly to Image.network().
  final String  displayUrl;

  /// Authenticated thumbnail URL — use for previews; load displayUrl only in viewer.
  final String  thumbnailUrl;

  /// For external videos (YouTube / Vimeo). Null for uploaded files.
  final String? videoUrl;

  /// Effective caption: captionOverride → supplier caption → supplier title.
  final String? caption;

  final bool   isHero;
  final int?   displayOrder;

  const ClientMediaItem({
    required this.mediaType,
    required this.displayUrl,
    required this.thumbnailUrl,
    this.videoUrl,
    this.caption,
    required this.isHero,
    this.displayOrder,
  });

  bool get isImage          => mediaType == 'image';
  bool get isVideo          => mediaType == 'video';
  bool get isExternalVideo  => isVideo && videoUrl != null;
}
