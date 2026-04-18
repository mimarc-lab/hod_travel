import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'map_view_mapper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tuning constants
// All k-prefixed values here are the single source of truth for timing and
// motion feel.  Adjust without touching any logic below.
// ─────────────────────────────────────────────────────────────────────────────

/// Geographic distance (in degrees, Euclidean) below which two locations are
/// treated as "same area" and receive the shortest single-curve transition.
/// 0.5° ≈ 55 km.
const double kSameAreaThresholdDeg = 0.5;

/// Distance threshold below which a "nearby" transition is used.
/// 8° ≈ 880 km.  Above this the full three-stage cinematic arc fires.
const double kNearbyThresholdDeg = 8.0;

/// Camera animation duration for same-area moves (short pan within one city).
const Duration kSameAreaDuration = Duration(milliseconds: 900);

/// Duration for nearby transitions (different region or country).
const Duration kNearbyDuration = Duration(milliseconds: 1500);

/// Duration for long-distance transitions (different country / continent).
/// This covers the full three-stage arc: pull-back → pan → settle.
const Duration kLongDistanceDuration = Duration(milliseconds: 2600);

/// How many zoom levels to pull back during the "context" phase of a
/// long-distance transition.  Raise for a more dramatic fly-out.
const double kContextZoomPullback = 3.5;

/// The map never zooms out further than this value during the pull-back.
const double kMinContextZoom = 3.5;

/// Progress fraction [0 → 1] at which the zoom-out stage ends.
/// Default: first 25 % of the total animation is the pull-back.
const double kStageZoomOutEnd = 0.25;

/// Progress fraction at which the pan stage ends (settle / zoom-in begins).
/// Default: 25 %–65 % is the pan; 65 %–100 % is the settle zoom-in.
const double kStagePanEnd = 0.65;

/// Easing curve for same-area transitions (short single-stage pan + zoom).
/// Swap for Curves.fastOutSlowIn for a snappier feel.
const Curve kSingleStageCurve = Curves.easeInOut;

// ── Nearby transition (two-stage) ────────────────────────────────────────────

/// How many zoom levels to pull back before panning in a nearby transition.
/// 1.5 levels is a subtle spatial-context nudge; raise for a more visible
/// pull-back without going as far as the long-distance arc.
const double kNearbyContextZoomPullback = 1.5;

/// Progress fraction [0 → 1] at which the zoom-out stage ends for nearby
/// transitions.  Default: first 20 % is the pull-back.
const double kNearbyStageZoomOutEnd = 0.20;

/// Easing for the zoom-out phase of nearby transitions.
const Curve kNearbyZoomOutCurve = Curves.easeOut;

/// Easing for the pan + settle phase of nearby transitions.
const Curve kNearbyPanCurve = Curves.easeInOut;

// ── Long-distance transition (three-stage) ────────────────────────────────────

/// Easing for the zoom-out (pull-back) phase of long transitions.
const Curve kZoomOutCurve = Curves.easeOut;

/// Easing for the pan (travel) phase of long transitions.
const Curve kPanCurve = Curves.easeInOut;

/// Easing for the settle (zoom-in) phase of long transitions.
const Curve kZoomInCurve = Curves.easeOut;

// ── Zoom heuristics ───────────────────────────────────────────────────────────
// Used by [MapTransitionController.focusForMarkers] to pick a target zoom.
// Each entry means: "if the bounding-box span is ≤ maxDeg degrees, use zoom".
// Entries are tested in order; the first match wins.

const List<({double maxDeg, double zoom})> kZoomTable = [
  (maxDeg: 0.005, zoom: 15.5), // same block / single venue
  (maxDeg: 0.020, zoom: 14.5), // neighbourhood
  (maxDeg: 0.080, zoom: 13.0), // city district
  (maxDeg: 0.300, zoom: 12.0), // city quarter
  (maxDeg: 1.000, zoom: 10.5), // metro area
  (maxDeg: 3.000, zoom: 9.0),  // region / state
  (maxDeg: 8.000, zoom: 7.5),  // country
];

/// Zoom used when the bounding box is wider than the last entry in [kZoomTable].
const double kFallbackZoom = 5.5;

// ─────────────────────────────────────────────────────────────────────────────
// MapFocusConfig  — the desired camera state for a day / pin cluster
// ─────────────────────────────────────────────────────────────────────────────

class MapFocusConfig {
  final LatLng center;
  final double zoom;
  const MapFocusConfig({required this.center, required this.zoom});
}

// ─────────────────────────────────────────────────────────────────────────────
// MapTransitionController
// ─────────────────────────────────────────────────────────────────────────────

enum _TransitionType { sameArea, nearby, longDistance }

class _Snapshot {
  final LatLng center;
  final double zoom;
  const _Snapshot({required this.center, required this.zoom});
}

/// Drives smooth, cinematic camera transitions on a flutter_map [MapController].
///
/// **Setup:**
/// ```dart
/// // State must also mixin TickerProviderStateMixin
/// late final MapTransitionController _transition;
///
/// @override void initState() {
///   super.initState();
///   _transition = MapTransitionController(
///     mapController: _mapController, vsync: this);
/// }
/// @override void dispose() { _transition.dispose(); super.dispose(); }
/// ```
///
/// **Triggering a transition:**
/// ```dart
/// _transition.animateTo(
///   MapTransitionController.focusForMarkers(dayMarkers),
///   reducedMotion: MediaQuery.of(context).disableAnimations,
/// );
/// ```
///
/// All timing + easing constants are k-prefixed at the top of this file.
class MapTransitionController {
  final MapController _map;
  final TickerProvider _vsync;

  AnimationController? _anim;
  _Snapshot?        _from;
  MapFocusConfig?   _target;
  _TransitionType?  _type;

  MapTransitionController({
    required MapController mapController,
    required TickerProvider vsync,
  })  : _map = mapController,
        _vsync = vsync;

  void dispose() {
    _anim?.dispose();
    _anim = null;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Animate the map camera to [target].
  ///
  /// Any in-flight animation is interrupted immediately so rapid day-tapping
  /// always snaps to the latest selection without queuing old transitions.
  ///
  /// Respects [reducedMotion] (pass `MediaQuery.of(ctx).disableAnimations`):
  /// when true the camera moves instantly with no animation.
  void animateTo(
    MapFocusConfig target, {
    bool reducedMotion = false,
  }) {
    // Read current camera state before stopping the old animation.
    final LatLng fromCenter;
    final double fromZoom;
    try {
      fromCenter = _map.camera.center;
      fromZoom   = _map.camera.zoom;
    } catch (_) {
      // Map not yet attached to a FlutterMap widget; silently bail.
      return;
    }

    // Stop + destroy any running transition first.
    _anim?.stop();
    _anim?.dispose();
    _anim = null;

    if (reducedMotion) {
      _map.move(target.center, target.zoom);
      return;
    }

    final dist = _dist(fromCenter, target.center);
    final type = _classify(dist);

    _from   = _Snapshot(center: fromCenter, zoom: fromZoom);
    _target = target;
    _type   = type;

    _anim = AnimationController(vsync: _vsync, duration: _durationFor(type))
      ..addListener(_tick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          // Eliminate floating-point drift: land exactly on target.
          _map.move(target.center, target.zoom);
        }
      })
      ..forward();
  }

  // ── Static helpers (usable without an instance) ─────────────────────────────

  /// Compute the optimal [MapFocusConfig] to frame [markers].
  ///
  /// • Zero markers → returns a wide fallback (Tokyo area).
  /// • One marker   → centres on it at a comfortable street zoom.
  /// • Many markers → centres on their bounding box with a zoom that fits the
  ///                  spread, as determined by [kZoomTable].
  static MapFocusConfig focusForMarkers(List<TripMapMarker> markers) {
    if (markers.isEmpty) {
      return const MapFocusConfig(
          center: LatLng(35.6762, 139.6503), zoom: 5.0);
    }
    if (markers.length == 1) {
      return MapFocusConfig(center: markers.first.position, zoom: 14.5);
    }

    double minLat = markers.first.position.latitude;
    double maxLat = markers.first.position.latitude;
    double minLng = markers.first.position.longitude;
    double maxLng = markers.first.position.longitude;

    for (final m in markers) {
      if (m.position.latitude  < minLat) minLat = m.position.latitude;
      if (m.position.latitude  > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span   = math.max(maxLat - minLat, maxLng - minLng);

    return MapFocusConfig(center: center, zoom: _zoomFor(span));
  }

  // ── Animation tick ──────────────────────────────────────────────────────────

  void _tick() {
    final anim   = _anim;
    final from   = _from;
    final target = _target;
    final type   = _type;
    if (anim == null || from == null || target == null || type == null) return;

    final t = anim.value; // linear progress [0 → 1]

    final LatLng pos;
    final double zoom;

    switch (type) {
      // ── Same area: single smooth curve, no zoom-out ───────────────────────
      // Pins are close enough that the user always has visual context;
      // a zoom-out would feel disorienting rather than informative.
      case _TransitionType.sameArea:
        final c = kSingleStageCurve.transform(t);
        pos  = _lerp(from.center, target.center, c);
        zoom = _lz(from.zoom, target.zoom, c);

      // ── Nearby: two-stage — subtle pull-back then pan + settle ───────────
      // Stage 1 [0 → kNearbyStageZoomOutEnd]:
      //   Zoom out slightly so the user sees the gap between origin and
      //   destination before the camera starts moving.
      // Stage 2 [kNearbyStageZoomOutEnd → 1.0]:
      //   Pan to destination and zoom back in, both on the same eased curve.
      case _TransitionType.nearby:
        final ctx = math.max(
          kMinContextZoom,
          math.min(from.zoom, target.zoom) - kNearbyContextZoomPullback,
        );

        if (t < kNearbyStageZoomOutEnd) {
          // Stage 1 — subtle zoom-out: position holds, zoom retreats
          final local = t / kNearbyStageZoomOutEnd;
          final c     = kNearbyZoomOutCurve.transform(local);
          pos  = from.center;
          zoom = _lz(from.zoom, ctx, c);
        } else {
          // Stage 2 — pan to target and zoom in together
          final local = (t - kNearbyStageZoomOutEnd) /
              (1.0 - kNearbyStageZoomOutEnd);
          final c = kNearbyPanCurve.transform(local);
          pos  = _lerp(from.center, target.center, c);
          zoom = _lz(ctx, target.zoom, c);
        }

      // ── Long distance: three-stage cinematic arc ──────────────────────────
      // Stage 1 [0 → kStageZoomOutEnd]:
      //   Pull back the zoom to give full geographic context; position holds.
      // Stage 2 [kStageZoomOutEnd → kStagePanEnd]:
      //   Pan across the map at the context zoom level.
      // Stage 3 [kStagePanEnd → 1.0]:
      //   Settle on the destination by zooming in.
      case _TransitionType.longDistance:
        final ctx = math.max(kMinContextZoom, from.zoom - kContextZoomPullback);

        if (t < kStageZoomOutEnd) {
          // Stage 1 — zoom out
          final local = t / kStageZoomOutEnd;
          final c     = kZoomOutCurve.transform(local);
          pos  = from.center;
          zoom = _lz(from.zoom, ctx, c);

        } else if (t < kStagePanEnd) {
          // Stage 2 — pan
          final local = (t - kStageZoomOutEnd) /
              (kStagePanEnd - kStageZoomOutEnd);
          final c = kPanCurve.transform(local);
          pos  = _lerp(from.center, target.center, c);
          zoom = ctx;

        } else {
          // Stage 3 — zoom in / settle
          final local = (t - kStagePanEnd) / (1.0 - kStagePanEnd);
          final c     = kZoomInCurve.transform(local);
          pos  = target.center;
          zoom = _lz(ctx, target.zoom, c);
        }
    }

    _map.move(pos, zoom);
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Euclidean distance between two LatLng points in degrees.
  /// Not true geographic distance, but sufficient for transition-type
  /// classification.
  static double _dist(LatLng a, LatLng b) {
    final dlat = a.latitude  - b.latitude;
    final dlng = a.longitude - b.longitude;
    return math.sqrt(dlat * dlat + dlng * dlng);
  }

  static _TransitionType _classify(double dist) {
    if (dist <= kSameAreaThresholdDeg) return _TransitionType.sameArea;
    if (dist <= kNearbyThresholdDeg)   return _TransitionType.nearby;
    return _TransitionType.longDistance;
  }

  static Duration _durationFor(_TransitionType t) => switch (t) {
        _TransitionType.sameArea     => kSameAreaDuration,
        _TransitionType.nearby       => kNearbyDuration,
        _TransitionType.longDistance => kLongDistanceDuration,
      };

  static LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude  + (b.latitude  - a.latitude)  * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  static double _lz(double a, double b, double t) => a + (b - a) * t;

  static double _zoomFor(double deg) {
    for (final e in kZoomTable) {
      if (deg <= e.maxDeg) return e.zoom;
    }
    return kFallbackZoom;
  }
}
