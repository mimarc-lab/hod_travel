import '../../../data/models/client_media_item.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/repositories/component_media_repository.dart';
import '../../../data/repositories/trip_component_repository.dart';
import 'client_safe_media_mapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientMediaPresenter
//
// Fetches and organises component media for the client-facing itinerary.
//
// Data flow:
//   TripComponentRepository.fetchForTrip(tripId)
//     → builds componentId → itineraryItemId map
//   ComponentMediaRepository.fetchClientVisibleForComponents(componentIds)
//     → batch fetch, all client-visible media
//   ClientSafeMediaMapper.map()
//     → strips all internal fields, rewrites storage URLs
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
  }) async {
    // Step 1 — fetch all trip components to get the itineraryItemId mapping
    final components = await componentRepo.fetchForTrip(tripId);

    final itemIdByComponentId = <String, String>{};
    for (final c in components) {
      if (c.itineraryItemId != null) {
        itemIdByComponentId[c.id] = c.itineraryItemId!;
      }
    }
    if (itemIdByComponentId.isEmpty) return {};

    // Step 2 — batch fetch client-visible media for all those components
    final allMedia = await mediaRepo.fetchClientVisibleForComponents(
      itemIdByComponentId.keys.toList(),
    );

    // Step 3 — group by itinerary_item_id, apply client-safe mapper
    final result = <String, List<ClientMediaItem>>{};
    for (final cm in allMedia) {
      final itemId = itemIdByComponentId[cm.componentId];
      if (itemId == null) continue;
      final clientItem = ClientSafeMediaMapper.map(cm);
      if (clientItem == null) continue;
      result.putIfAbsent(itemId, () => []).add(clientItem);
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

    return result;
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
