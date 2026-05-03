import 'package:flutter/foundation.dart';
import 'supplier_media.dart';

@immutable
class ComponentMedia {
  final String        id;
  final String        teamId;
  final String        componentId;
  final String        supplierMediaId;
  final bool          isHero;
  final bool          isVisible;
  final String?       captionOverride;
  final int?          displayOrder;
  final DateTime      createdAt;
  final String?       createdBy;

  /// Populated when fetched with a join on supplier_media.
  final SupplierMedia? media;

  const ComponentMedia({
    required this.id,
    required this.teamId,
    required this.componentId,
    required this.supplierMediaId,
    this.isHero           = false,
    this.isVisible        = true,
    this.captionOverride,
    this.displayOrder,
    required this.createdAt,
    this.createdBy,
    this.media,
  });

  String get effectiveCaption =>
      captionOverride?.isNotEmpty == true
          ? captionOverride!
          : media?.caption ?? '';

  ComponentMedia copyWith({
    String?       id,
    String?       teamId,
    String?       componentId,
    String?       supplierMediaId,
    bool?         isHero,
    bool?         isVisible,
    String?       captionOverride,
    int?          displayOrder,
    DateTime?     createdAt,
    String?       createdBy,
    SupplierMedia? media,
  }) =>
      ComponentMedia(
        id:              id              ?? this.id,
        teamId:          teamId          ?? this.teamId,
        componentId:     componentId     ?? this.componentId,
        supplierMediaId: supplierMediaId ?? this.supplierMediaId,
        isHero:          isHero          ?? this.isHero,
        isVisible:       isVisible       ?? this.isVisible,
        captionOverride: captionOverride ?? this.captionOverride,
        displayOrder:    displayOrder    ?? this.displayOrder,
        createdAt:       createdAt       ?? this.createdAt,
        createdBy:       createdBy       ?? this.createdBy,
        media:           media           ?? this.media,
      );
}
