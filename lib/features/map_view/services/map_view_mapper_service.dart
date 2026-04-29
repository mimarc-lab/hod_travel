import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show LatLng;

import '../../../data/models/itinerary_models.dart';
import 'trip_location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripMapMarker — the data model for a single pin on the map
// ─────────────────────────────────────────────────────────────────────────────

class TripMapMarker {
  final ItineraryItem item;
  final TripDayRef day;
  final LatLng position;

  /// Transport icon markers carry the positions of the two adjacent location
  /// stops so the detail card can show an "A → B" route label.
  /// Null for non-transport markers.
  final LatLng? routeFrom;
  final LatLng? routeTo;

  /// True only when this marker was placed via Pass 2 (midpoint badge between
  /// two adjacent stops).  Transport items that were successfully geocoded to
  /// a specific location in Pass 1 have this set to false and render as pins.
  final bool isRouteIcon;

  const TripMapMarker({
    required this.item,
    required this.day,
    required this.position,
    this.routeFrom,
    this.routeTo,
    this.isRouteIcon = false,
  });

  String get id => item.id;

  /// True for transport items rendered as a mid-route badge (not a pin).
  bool get isTransportIcon => isRouteIcon;
}

/// Lightweight day reference carried by each marker (avoids importing
/// the full TripDay into the map marker model).
class TripDayRef {
  final String id;
  final int number;
  final String city;
  final DateTime? date;

  const TripDayRef({
    required this.id,
    required this.number,
    required this.city,
    this.date,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MapViewMapperService — pure, stateless computation
// ─────────────────────────────────────────────────────────────────────────────

abstract class MapViewMapperService {
  // ── Build ──────────────────────────────────────────────────────────────────

  /// Converts itinerary data into a flat list of [TripMapMarker].
  ///
  /// **Pass 1** — location markers: all non-transport, non-note items whose
  /// location can be resolved.  Overlapping pins are spread with a small
  /// golden-ratio spiral (~30 m step).
  ///
  /// **Pass 2** — transport icon markers: each transport item is placed at the
  /// geographic midpoint between the nearest preceding and following location
  /// markers (in day/time order).  This makes the icon appear on the route
  /// line connecting those two stops.  Falls back to title-parsed route
  /// coordinates when one or both adjacent stops are unresolved.
  static List<TripMapMarker> buildMarkers({
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDayId,
  }) {
    // ── Flatten + sort all items by day / start-time ─────────────────────────
    final allItems = <({ItineraryItem item, TripDayRef day})>[];

    for (final day in days) {
      final ref = TripDayRef(
        id: day.id,
        number: day.dayNumber,
        city: day.city,
        date: day.date,
      );
      for (final item in itemsByDayId[day.id] ?? const <ItineraryItem>[]) {
        allItems.add((item: item, day: ref));
      }
    }

    allItems.sort((a, b) {
      final dc = a.day.number.compareTo(b.day.number);
      if (dc != 0) return dc;
      final at = a.item.startTime;
      final bt = b.item.startTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return (at.hour * 60 + at.minute).compareTo(bt.hour * 60 + bt.minute);
    });

    // ── Pass 1: location markers ─────────────────────────────────────────────
    final locationMarkers = <TripMapMarker>[];

    // markerById is built incrementally so ghost-hotel entries are included.
    // Ghost entries carry the resolved position but are NOT added to
    // locationMarkers (no visible pin).  They exist only so Pass 2 can still
    // compute correct transport-badge midpoints when the hotel is the
    // prev / next stop.
    final markerById = <String, TripMapMarker>{};
    final overlapCount = <String, int>{};

    // Tracks base-coordinate keys of hotels that already have a visible pin.
    // The same property repeats throughout an itinerary (guest returns after
    // each experience), so only the first occurrence gets rendered.
    final pinnedHotelKeys = <String>{};

    for (final e in allItems) {
      if (e.item.type == ItemType.note) continue;

      // Transport items: try to geocode a specific location first.
      // If a location can be resolved (e.g. "JFK Airport" in the title),
      // place a standalone pin here in Pass 1 rather than a midpoint badge.
      // Items that can't be geocoded are left for Pass 2.
      if (e.item.type == ItemType.transport) {
        final LatLng? pos;
        if (e.item.latitude != null && e.item.longitude != null) {
          pos = LatLng(e.item.latitude!, e.item.longitude!);
        } else {
          pos = TripLocationService.resolve(e.item.location, e.day.city)
              ?? TripLocationService.resolve(e.item.title, e.day.city);
        }
        if (pos != null) {
          final marker = TripMapMarker(item: e.item, day: e.day, position: pos);
          locationMarkers.add(marker);
          markerById[e.item.id] = marker;
        }
        // If pos == null → handled in Pass 2 as a midpoint badge
        continue;
      }

      // Resolve position. For flight items also try the item title so that
      // airport names embedded in titles ("George Bush Inter...", "Marco Polo
      // Airport", "JFK Departure") geocode to the correct airport coordinates
      // rather than falling back to a generic city centre.
      final LatLng? base;
      if (e.item.latitude != null && e.item.longitude != null) {
        base = LatLng(e.item.latitude!, e.item.longitude!);
      } else if (e.item.type == ItemType.flight) {
        base = TripLocationService.resolve(e.item.location, null)
            ?? TripLocationService.resolve(e.item.title, e.day.city);
      } else {
        base = TripLocationService.resolve(e.item.location, e.day.city);
      }
      if (base == null) continue;

      final baseKey = _coordKey(base);

      // ── Hotel deduplication ────────────────────────────────────────────────
      // Skip the visible pin when this hotel has already been placed.
      // A ghost TripMapMarker is still stored in markerById so that
      // transport-badge midpoints remain accurate.
      if (e.item.type == ItemType.hotel) {
        if (pinnedHotelKeys.contains(baseKey)) {
          markerById[e.item.id] = TripMapMarker(
            item: e.item,
            day: e.day,
            position: base, // raw coord — no spiral, no visible pin
          );
          continue; // do not render another hotel pin
        }
        pinnedHotelKeys.add(baseKey);
      }
      // ──────────────────────────────────────────────────────────────────────

      final count = overlapCount[baseKey] ?? 0;
      overlapCount[baseKey] = count + 1;

      final marker = TripMapMarker(
        item: e.item,
        day: e.day,
        position: count == 0 ? base : _spiral(base, count),
      );
      locationMarkers.add(marker);
      markerById[e.item.id] = marker;
    }

    // ── Pass 2: transport icon markers ───────────────────────────────────────
    final transportMarkers = <TripMapMarker>[];

    for (int i = 0; i < allItems.length; i++) {
      final e = allItems[i];
      if (e.item.type != ItemType.transport) continue;

      // Already geocoded to a specific location in Pass 1 — render as a pin,
      // not a midpoint badge.
      if (markerById.containsKey(e.item.id)) continue;

      // Nearest preceding location marker with a resolved position.
      // Skip items that have no entry in markerById (unresolvable location)
      // and keep scanning backwards until we find one that does.
      TripMapMarker? prevMarker;
      for (int j = i - 1; j >= 0; j--) {
        final t = allItems[j].item.type;
        if (t != ItemType.transport && t != ItemType.note) {
          final candidate = markerById[allItems[j].item.id];
          if (candidate != null) {
            prevMarker = candidate;
            break;
          }
          // item exists but location is unresolved — keep scanning
        }
      }

      // Nearest following location marker with a resolved position.
      // Same logic: skip items whose location couldn't be resolved.
      TripMapMarker? nextMarker;
      for (int j = i + 1; j < allItems.length; j++) {
        final t = allItems[j].item.type;
        if (t != ItemType.transport && t != ItemType.note) {
          final candidate = markerById[allItems[j].item.id];
          if (candidate != null) {
            nextMarker = candidate;
            break;
          }
          // item exists but location is unresolved — keep scanning
        }
      }

      // Resolve from / to positions
      LatLng? from = prevMarker?.position;
      LatLng? to = nextMarker?.position;

      // If one or both sides are missing, try title-parsed geographic route
      if (from == null || to == null) {
        final route = TripLocationService.parseTransportRoute(
          e.item.title,
          e.day.city,
        );
        from ??= route?.from;
        to ??= route?.to;
      }

      // Final fallback: use the current day's city as departure and the
      // next calendar day's city as arrival.  This handles flights/transfers
      // whose titles don't follow the "A to B" pattern (e.g. "JFK Departure").
      from ??= TripLocationService.resolve(null, e.day.city);
      if (to == null) {
        // Find the first item that belongs to a later day.
        String? nextCity;
        for (int j = i + 1; j < allItems.length; j++) {
          if (allItems[j].day.number > e.day.number) {
            nextCity = allItems[j].day.city;
            break;
          }
        }
        // If no later item exists, try the next sequential day in the days list.
        if (nextCity == null) {
          final nextDayNum = e.day.number + 1;
          for (final day in days) {
            if (day.dayNumber == nextDayNum) { nextCity = day.city; break; }
          }
        }
        to = TripLocationService.resolve(null, nextCity);
      }

      if (from == null || to == null) continue;
      if (from.latitude == to.latitude && from.longitude == to.longitude) {
        continue; // same point — skip
      }

      transportMarkers.add(
        TripMapMarker(
          item: e.item,
          day: e.day,
          position: _midpoint(from, to),
          routeFrom: from,
          routeTo: to,
          isRouteIcon: true,
        ),
      );
    }

    return [...locationMarkers, ...transportMarkers];
  }

  // ── Filter ─────────────────────────────────────────────────────────────────

  /// Returns only markers for [dayId]; all markers when [dayId] is null.
  static List<TripMapMarker> filterByDay(
    List<TripMapMarker> all,
    String? dayId,
  ) {
    if (dayId == null) return all;
    return all.where((m) => m.day.id == dayId).toList();
  }

  /// Returns only markers of [type]; all markers when [type] is null.
  /// Transport icons are always included so the journey context is visible.
  static List<TripMapMarker> filterByType(
    List<TripMapMarker> filtered,
    ItemType? type,
  ) {
    if (type == null) return filtered;
    return filtered.where((m) => m.item.displayType == type).toList();
  }

  // ── Route ──────────────────────────────────────────────────────────────────

  /// Ordered [LatLng] list for the route polyline.
  ///
  /// Only location (non-transport) markers are used.  Transport icon markers
  /// sit at midpoints of route segments, so including them would be redundant.
  ///
  /// Primary sort: day number.  Secondary: start time (untimed items last).
  static List<LatLng> routePoints(List<TripMapMarker> markers) {
    final sorted =
        markers.where((m) => m.item.displayType != ItemType.transport).toList()
          ..sort(_markerOrder);
    return sorted.map((m) => m.position).toList();
  }

  // ── Bounds ─────────────────────────────────────────────────────────────────

  /// Axis-aligned bounding box for [markers], padded by [padDeg] degrees.
  /// Returns null when [markers] is empty.
  static ({LatLng sw, LatLng ne})? bounds(
    List<TripMapMarker> markers, {
    double padDeg = 0.5,
  }) {
    if (markers.isEmpty) return null;

    var minLat = markers.first.position.latitude;
    var maxLat = markers.first.position.latitude;
    var minLng = markers.first.position.longitude;
    var maxLng = markers.first.position.longitude;

    for (final m in markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Ensure minimum bounding box so single-point trips zoom to street level
    const minDelta = 0.08;
    final latDelta = math.max(maxLat - minLat, minDelta);
    final lngDelta = math.max(maxLng - minLng, minDelta);
    final latCentre = (minLat + maxLat) / 2;
    final lngCentre = (minLng + maxLng) / 2;

    return (
      sw: LatLng(
        latCentre - latDelta / 2 - padDeg,
        lngCentre - lngDelta / 2 - padDeg,
      ),
      ne: LatLng(
        latCentre + latDelta / 2 + padDeg,
        lngCentre + lngDelta / 2 + padDeg,
      ),
    );
  }

  // ── Distance segments ──────────────────────────────────────────────────────

  /// Returns one entry per consecutive pair of non-transport location markers,
  /// each with the segment midpoint and straight-line Haversine distance (km).
  /// Used to render distance labels along the route polyline.
  static List<({LatLng midpoint, double distanceKm, String fromId, String toId})> routeSegments(
      List<TripMapMarker> markers) {
    final sorted =
        markers.where((m) => m.item.displayType != ItemType.transport).toList()
          ..sort(_markerOrder);

    if (sorted.length < 2) return const [];

    final segments = <({LatLng midpoint, double distanceKm, String fromId, String toId})>[];
    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i].position;
      final b = sorted[i + 1].position;
      segments.add((
        midpoint:   _midpoint(a, b),
        distanceKm: _haversineKm(a, b),
        fromId:     sorted[i].id,
        toId:       sorted[i + 1].id,
      ));
    }
    return segments;
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final x = sinLat * sinLat +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            sinLng * sinLng;
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;

  // ── Private helpers ────────────────────────────────────────────────────────

  static LatLng _midpoint(LatLng a, LatLng b) =>
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

  static String _coordKey(LatLng ll) =>
      '${ll.latitude.toStringAsFixed(4)},${ll.longitude.toStringAsFixed(4)}';

  /// Offset [base] outward in a golden-ratio spiral.
  /// Step ~30 m keeps same-building pins visually grouped.
  static LatLng _spiral(LatLng base, int n) {
    const step = 0.00027; // ~30 m per unit
    final angle = n * math.pi * 0.6180339887; // golden ratio
    final radius = step * math.sqrt(n.toDouble());
    return LatLng(
      base.latitude + radius * math.cos(angle),
      base.longitude + radius * math.sin(angle),
    );
  }

  static int _markerOrder(TripMapMarker a, TripMapMarker b) {
    final dayComp = a.day.number.compareTo(b.day.number);
    if (dayComp != 0) return dayComp;

    final at = a.item.startTime;
    final bt = b.item.startTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;

    final am = at.hour * 60 + at.minute;
    final bm = bt.hour * 60 + bt.minute;
    return am.compareTo(bm);
  }
}
