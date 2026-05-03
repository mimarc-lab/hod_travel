import 'dart:math';
import 'dart:typed_data';
import '../../../data/models/supplier_media.dart';
import '../../../data/repositories/supplier_media_repository.dart';
import 'image_processing_service.dart';

// ── Upload specification ───────────────────────────────────────────────────────

class MediaUploadSpec {
  /// Raw file bytes — required for image/MP4 uploads.
  final Uint8List? bytes;

  /// Original file name (used to derive the stored file name).
  final String?    fileName;

  /// For video-URL mode: YouTube / Vimeo link.
  final String?    videoUrl;

  /// External thumbnail URL (optional, used for video-URL mode).
  final String?    externalThumbnailUrl;

  final SupplierMediaType mediaType;
  final String            title;
  final String?           caption;
  final String?           description;
  final List<String>      tags;
  final bool              isHero;

  const MediaUploadSpec({
    this.bytes,
    this.fileName,
    this.videoUrl,
    this.externalThumbnailUrl,
    required this.mediaType,
    required this.title,
    this.caption,
    this.description,
    this.tags = const [],
    this.isHero = false,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class MediaUploadService {
  final SupplierMediaRepository _repo;
  final ImageProcessingService  _imgSvc;
  static final _rng = Random.secure();

  MediaUploadService({
    required SupplierMediaRepository repo,
    ImageProcessingService?          imageProcessingService,
  })  : _repo   = repo,
        _imgSvc = imageProcessingService ?? ImageProcessingService();

  /// Full upload flow:
  /// 1. If image: convert to WebP + generate thumbnail
  /// 2. Upload optimized bytes (and thumbnail) to Storage
  /// 3. Insert metadata row into supplier_media
  Future<SupplierMedia> upload({
    required String          supplierId,
    required String          teamId,
    required MediaUploadSpec spec,
  }) async {
    final mediaId = _generateUuid();

    String  fileUrl      = '';
    String? thumbnailUrl = spec.externalThumbnailUrl;
    String  storagePath  = '';
    String? mimeType;

    if (spec.mediaType == SupplierMediaType.image) {
      // ── Image path ─────────────────────────────────────────────────────────
      final bytes = spec.bytes;
      if (bytes == null) throw Exception('Image bytes are required.');

      final processed = await _imgSvc.process(bytes);

      final baseName = _baseName(spec.fileName ?? 'image');

      // Upload optimized image
      storagePath = await _repo.uploadToStorage(
        teamId:      teamId,
        supplierId:  supplierId,
        mediaId:     mediaId,
        fileName:    '$baseName.jpg',
        bytes:       processed.optimizedBytes,
        contentType: 'image/jpeg',
      );
      fileUrl  = _repo.getPublicUrl(storagePath);
      mimeType = 'image/jpeg';

      // Upload thumbnail
      final thumbPath = await _repo.uploadToStorage(
        teamId:      teamId,
        supplierId:  supplierId,
        mediaId:     mediaId,
        fileName:    '${baseName}_thumb.jpg',
        bytes:       processed.thumbnailBytes,
        contentType: 'image/jpeg',
      );
      thumbnailUrl = _repo.getPublicUrl(thumbPath);

    } else {
      // ── Video path ─────────────────────────────────────────────────────────
      if (spec.videoUrl != null) {
        // External URL (YouTube / Vimeo)
        fileUrl  = spec.videoUrl!;
        mimeType = 'video/external';
        // Auto-extract YouTube thumbnail if not provided
        thumbnailUrl ??= _youTubeThumbnail(spec.videoUrl!);
      } else if (spec.bytes != null) {
        // Uploaded MP4
        final bytes    = spec.bytes!;
        final baseName = _baseName(spec.fileName ?? 'video');
        storagePath = await _repo.uploadToStorage(
          teamId:      teamId,
          supplierId:  supplierId,
          mediaId:     mediaId,
          fileName:    '$baseName.mp4',
          bytes:       bytes,
          contentType: 'video/mp4',
        );
        fileUrl  = _repo.getPublicUrl(storagePath);
        mimeType = 'video/mp4';
      } else {
        throw Exception('Video upload requires either a URL or file bytes.');
      }
    }

    // If this should become the hero, clear any existing one first
    if (spec.isHero) await _repo.clearHero(supplierId);

    final media = SupplierMedia(
      id:           mediaId,
      teamId:       teamId,
      supplierId:   supplierId,
      mediaType:    spec.mediaType,
      fileUrl:      fileUrl,
      thumbnailUrl: thumbnailUrl,
      storagePath:  storagePath,
      mimeType:     mimeType,
      videoUrl:     spec.videoUrl,
      title:        spec.title.trim(),
      description:  spec.description?.trim(),
      caption:      spec.caption?.trim(),
      isHero:       spec.isHero,
      tags:         spec.tags,
      createdAt:    DateTime.now(),
    );

    return _repo.create(media, teamId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _generateUuid() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant
    String h(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${b.sublist(0, 4).map(h).join()}-'
        '${b.sublist(4, 6).map(h).join()}-'
        '${b.sublist(6, 8).map(h).join()}-'
        '${b.sublist(8, 10).map(h).join()}-'
        '${b.sublist(10).map(h).join()}';
  }

  /// Strips extension and sanitises the file name.
  static String _baseName(String name) {
    final dot = name.lastIndexOf('.');
    final raw = dot > 0 ? name.substring(0, dot) : name;
    return raw.replaceAll(RegExp(r'[^\w\-]'), '_').toLowerCase();
  }

  /// Extracts the standard maxresdefault thumbnail for a YouTube URL.
  static String? _youTubeThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? videoId;
    if (uri.host.contains('youtu.be')) {
      videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else if (uri.host.contains('youtube.com')) {
      videoId = uri.queryParameters['v'];
    }
    if (videoId == null) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
}
