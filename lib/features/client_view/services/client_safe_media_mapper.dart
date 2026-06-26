import '../../../data/models/client_media_item.dart';
import '../../../data/models/component_media.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientSafeMediaMapper
//
// Converts ComponentMedia (internal) → ClientMediaItem (client-safe).
//
// Rules:
//   • Only maps items where is_visible = true and supplier_media.is_active = true
//   • Never exposes: storagePath, uploadedBy, teamId, supplierId, internal tags,
//     internal description, or any operational field
// ─────────────────────────────────────────────────────────────────────────────

abstract class ClientSafeMediaMapper {
  /// Returns null if the item should not be shown to the client.
  static ClientMediaItem? map(ComponentMedia cm) {
    if (!cm.isVisible) return null;

    final media = cm.media;
    if (media == null || !media.isActive) return null;

    // Caption priority: captionOverride → supplier caption → supplier title
    final String? caption = () {
      if (cm.captionOverride?.trim().isNotEmpty == true) return cm.captionOverride!.trim();
      if (media.caption?.trim().isNotEmpty == true)      return media.caption!.trim();
      if (media.title.trim().isNotEmpty)                 return media.title.trim();
      return null;
    }();

    return ClientMediaItem(
      mediaType:    media.mediaType.dbValue,
      displayUrl:   media.fileUrl,
      thumbnailUrl: media.previewUrl,
      videoUrl:     media.videoUrl,
      caption:      caption,
      isHero:       cm.isHero,
      displayOrder: cm.displayOrder,
    );
  }
}
