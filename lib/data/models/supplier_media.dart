import 'package:flutter/foundation.dart';

// ── Media type ────────────────────────────────────────────────────────────────

enum SupplierMediaType {
  image,
  video;

  String get dbValue => name;

  static SupplierMediaType fromDb(String v) => SupplierMediaType.values
      .firstWhere((e) => e.dbValue == v, orElse: () => SupplierMediaType.image);
}

// ── Model ─────────────────────────────────────────────────────────────────────

@immutable
class SupplierMedia {
  final String             id;
  final String             teamId;
  final String             supplierId;
  final SupplierMediaType  mediaType;
  final String             fileUrl;
  final String?            thumbnailUrl;
  final String             storagePath;
  final String?            mimeType;
  final String?            videoUrl;
  final String             title;
  final String?            description;
  final String?            caption;
  final bool               isHero;
  final bool               isActive;
  final int?               displayOrder;
  final List<String>       tags;
  final DateTime           createdAt;
  final String?            uploadedBy;

  const SupplierMedia({
    required this.id,
    required this.teamId,
    required this.supplierId,
    required this.mediaType,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.storagePath,
    this.mimeType,
    this.videoUrl,
    required this.title,
    this.description,
    this.caption,
    this.isHero = false,
    this.isActive = true,
    this.displayOrder,
    this.tags = const [],
    required this.createdAt,
    this.uploadedBy,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get isVideo     => mediaType == SupplierMediaType.video;
  bool get isImage     => mediaType == SupplierMediaType.image;

  /// URL to use as the preview thumbnail in grid cards.
  String get previewUrl => thumbnailUrl ?? fileUrl;

  /// True when this is an external video (YouTube / Vimeo) link.
  bool get isExternalVideo => isVideo && videoUrl != null;

  // ── copyWith ───────────────────────────────────────────────────────────────

  SupplierMedia copyWith({
    String?            id,
    String?            teamId,
    String?            supplierId,
    SupplierMediaType? mediaType,
    String?            fileUrl,
    String?            thumbnailUrl,
    String?            storagePath,
    String?            mimeType,
    String?            videoUrl,
    String?            title,
    String?            description,
    String?            caption,
    bool?              isHero,
    bool?              isActive,
    int?               displayOrder,
    List<String>?      tags,
    DateTime?          createdAt,
    String?            uploadedBy,
  }) =>
      SupplierMedia(
        id:           id           ?? this.id,
        teamId:       teamId       ?? this.teamId,
        supplierId:   supplierId   ?? this.supplierId,
        mediaType:    mediaType    ?? this.mediaType,
        fileUrl:      fileUrl      ?? this.fileUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        storagePath:  storagePath  ?? this.storagePath,
        mimeType:     mimeType     ?? this.mimeType,
        videoUrl:     videoUrl     ?? this.videoUrl,
        title:        title        ?? this.title,
        description:  description  ?? this.description,
        caption:      caption      ?? this.caption,
        isHero:       isHero       ?? this.isHero,
        isActive:     isActive     ?? this.isActive,
        displayOrder: displayOrder ?? this.displayOrder,
        tags:         tags         ?? this.tags,
        createdAt:    createdAt    ?? this.createdAt,
        uploadedBy:   uploadedBy   ?? this.uploadedBy,
      );
}
