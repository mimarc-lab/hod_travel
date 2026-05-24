import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/supplier_media.dart';
import '../../../data/repositories/component_media_repository.dart';
import '../../../data/repositories/supplier_media_repository.dart';
import '../../../data/repositories/trip_component_repository.dart';
import 'client_safe_media_mapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaPresenter
//
// Fetches and organises media for the client-facing itinerary.
//
// Primary source (TripComponent → ComponentMedia chain):
//   TripComponentRepository.fetchForTrip(tripId)
//     → builds componentId → itineraryItemId map
//   ComponentMediaRepository.fetchClientVisibleForComponents(componentIds)
//     → batch fetch, all client-visible media
//   ClientSafeMediaMapper.map()
//     → strips all internal fields, rewrites storage URLs
//
// Fallback source (direct supplier media):
//   For any itinerary item that has a supplierId but no component media,
//   fetch the supplier's active images and show them in the client view.
//   Requires optional [supplierMediaRepo] + [allItems] parameters.
//
//   Returns Map<itineraryItemId, List<ClientMediaItem>>
//     sorted: hero first → display_order → created_at
// ─────────────────────────────────────────────────────────────────────────────

abstract class ClientMediaPresenter {
  /// Loads all client-visible media for a trip, keyed by ItineraryItem.id.
  /// Never throws — returns an empty map on any error so the itinerary
  /// remains readable even if media loading fails.
  static Future<Map<String, List<ClientMediaItem>>> loadForTrip({
    required String                    tripId,
    required TripComponentRepository   componentRepo,
    required ComponentMediaRepository  mediaRepo,
    SupplierMediaRepository?           supplierMediaRepo,
    List<ItineraryItem>?               allItems,
  }) async {
    // Step 1 — fetch all trip components to get the itineraryItemId mapping
    final components = await componentRepo.fetchForTrip(tripId);

    final itemIdByComponentId = <String, String>{};
    for (final c in components) {
      if (c.itineraryItemId != null) {
        itemIdByComponentId[c.id] = c.itineraryItemId!;
      }
    }

    final result = <String, List<ClientMediaItem>>{};

    if (itemIdByComponentId.isNotEmpty) {
      // Step 2 — batch fetch client-visible media for all those components
      final allMedia = await mediaRepo.fetchClientVisibleForComponents(
        itemIdByComponentId.keys.toList(),
      );

      // Step 3 — group by itinerary_item_id, apply client-safe mapper
      for (final cm in allMedia) {
        final itemId = itemIdByComponentId[cm.componentId];
        if (itemId == null) continue;
        final clientItem = ClientSafeMediaMapper.map(cm);
        if (clientItem == null) continue;
        result.putIfAbsent(itemId, () => []).add(clientItem);
      }
    }

    // Step 4 — sort each group: hero first, then display_order
    for (final list in result.values) {
      list.sort((a, b) {
        if (a.isHero && !b.isHero) return -1;
        if (!a.isHero && b.isHero) return 1;
        final aOrd = a.displayOrder ?? 999;
        final bOrd = b.displayOrder ?? 999;
        return aOrd.compareTo(bOrd);
      });
    }

    // Step 5 — supplier media fallback: items with supplierId but no component media
    if (supplierMediaRepo != null && allItems != null) {
      final itemsNeedingMedia = allItems
          .where((i) => i.supplierId != null && !result.containsKey(i.id))
          .toList();

      if (itemsNeedingMedia.isNotEmpty) {
        // Dedupe supplier IDs, fetch in parallel
        final supplierIds = {for (final i in itemsNeedingMedia) i.supplierId!};
        final mediaBySupplier = <String, List<SupplierMedia>>{};
        await Future.wait(
          supplierIds.map((sid) async {
            try {
              final raw = await supplierMediaRepo.fetchForSupplier(sid);
              mediaBySupplier[sid] =
                  raw.where((m) => m.isActive && m.isImage).toList();
            } catch (_) {}
          }),
        );

        for (final item in itemsNeedingMedia) {
          final allForSupplier = mediaBySupplier[item.supplierId!];
          if (allForSupplier == null || allForSupplier.isEmpty) continue;

          // If the item has specific gallery_ids selected, show only those;
          // otherwise fall back to all active images for the supplier.
          final galleryList = item.detailsJson['gallery_ids'];
          final selectedIds = galleryList is List && galleryList.isNotEmpty
              ? List<String>.from(galleryList.whereType<String>())
              : null;

          final media = selectedIds != null
              ? allForSupplier.where((m) => selectedIds.contains(m.id)).toList()
              : allForSupplier;

          if (media.isEmpty) continue;
          result[item.id] = media
              .map(_mapSupplierMedia)
              .toList()
            ..sort((a, b) {
              if (a.isHero && !b.isHero) return -1;
              if (!a.isHero && b.isHero) return 1;
              final aOrd = a.displayOrder ?? 999;
              final bOrd = b.displayOrder ?? 999;
              return aOrd.compareTo(bOrd);
            });
        }
      }
    }

    return result;
  }

  static ClientMediaItem _mapSupplierMedia(SupplierMedia m) {
    String authUrl(String url) =>
        url.replaceFirst('/object/public/', '/object/authenticated/');
    return ClientMediaItem(
      mediaType:    m.mediaType.dbValue,
      displayUrl:   authUrl(m.fileUrl),
      thumbnailUrl: authUrl(m.previewUrl),
      videoUrl:     m.videoUrl,
      caption:      m.caption?.trim().isNotEmpty == true
                        ? m.caption!.trim()
                        : (m.title.trim().isNotEmpty ? m.title.trim() : null),
      isHero:       m.isHero,
      displayOrder: m.displayOrder,
    );
  }

  /// Selects the single best trip-level hero image.
  ///
  /// Priority:
  ///   1. Accommodation item with is_hero = true
  ///   2. Experience item with is_hero = true
  ///   3. Any item with is_hero = true
  ///   4. First image across all items
  ///   5. null (no hero — don't show empty block)
  static ClientMediaItem? selectTripHero(
    Map<String, List<ClientMediaItem>> mediaByItemId,
    List<ItineraryItem>                allItems,
  ) {
    final typeByItemId = {for (final i in allItems) i.id: i.type};

    ClientMediaItem? heroFor(ItemType type) {
      for (final entry in mediaByItemId.entries) {
        if (typeByItemId[entry.key] != type) continue;
        final hero = entry.value.where((m) => m.isHero && m.isImage).firstOrNull;
        if (hero != null) return hero;
      }
      return null;
    }

    return heroFor(ItemType.hotel)
        ?? heroFor(ItemType.experience)
        ?? mediaByItemId.values.expand((l) => l).where((m) => m.isHero && m.isImage).firstOrNull
        ?? mediaByItemId.values.expand((l) => l).where((m) => m.isImage).firstOrNull;
  }
}
