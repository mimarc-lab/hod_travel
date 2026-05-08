import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/trip_model.dart';
import '../itinerary/providers/itinerary_provider.dart';
import 'services/map_transition_controller.dart';
import 'services/map_view_mapper_service.dart';
import 'services/trip_location_service.dart';
import 'widgets/day_navigator_panel.dart';
import 'widgets/map_filters_bar.dart';
import 'widgets/map_pin_detail_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripMapScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Map View tab — premium geographic visualization of a trip's itinerary.
///
/// Uses flutter_map + CartoDB light tiles.
/// Data is loaded via [ItineraryProvider] (same pattern as ItineraryScreen).
/// State is preserved across tab switches via [AutomaticKeepAliveClientMixin].
class TripMapScreen extends StatefulWidget {
  final Trip trip;
  final ItineraryProvider? provider;
  const TripMapScreen({super.key, required this.trip, this.provider});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // ── Providers ──────────────────────────────────────────────────────────────
  late final ItineraryProvider _itinerary;
  bool _ownsProvider = false; // true when we created the provider ourselves

  // ── Map ────────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  late final MapTransitionController _transition;
  bool _mapReady = false;

  // ── Mobile bottom sheet ────────────────────────────────────────────────────
  bool _mobilePanelExpanded = false;

  // ── Filter state ───────────────────────────────────────────────────────────
  String?   _selectedDayId;
  ItemType? _selectedType;
  bool      _showRoute = true; // Route on by default

  // ── Selection state ────────────────────────────────────────────────────────
  String? _focusedMarkerId; // item.id of the tapped pin
  bool    _relocating = false; // true while waiting for the user to tap a new location

  // ── Computed markers (rebuilt on provider update + filter change) ──────────
  List<TripMapMarker> _allMarkers = const [];

  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.provider != null) {
      _itinerary = widget.provider!;
    } else {
      _itinerary = ItineraryProvider(
        widget.trip,
        repository: AppRepositories.instance?.itinerary,
        teamId:     AppRepositories.instance?.currentTeamId,
      );
      _ownsProvider = true;
    }
    _transition = MapTransitionController(
      mapController: _mapController,
      vsync:         this,
    );
    _itinerary.addListener(_onItineraryChanged);
    // If the provider already has data (shared instance, loaded before this
    // screen mounted), prime the markers immediately instead of waiting for
    // the next notify call.
    if (_itinerary.days.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onItineraryChanged());
    }
  }

  @override
  void dispose() {
    _itinerary.removeListener(_onItineraryChanged);
    if (_ownsProvider) _itinerary.dispose();
    _transition.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  void _onItineraryChanged() {
    final markers = MapViewMapperService.buildMarkers(
      days:          _itinerary.days,
      itemsByDayId:  _itineraryItemsByDayId,
    );
    setState(() {
      _allMarkers = markers;
      // Auto-select the first day so only Day 1 pins are visible on load.
      // Only set once; preserves the user's current selection on subsequent updates.
      if (_selectedDayId == null && _itinerary.days.isNotEmpty) {
        _selectedDayId = _itinerary.days.first.id;
      }
    });

    // Fit camera once on first load — use pins if available, city names otherwise.
    if (!_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (markers.isNotEmpty) {
          _fitVisible();
        } else {
          _fitToCities();
        }
      });
    }
  }

  /// Centres the map on the trip's day cities when no itinerary pins exist yet.
  void _fitToCities() {
    final points = <LatLng>[];
    for (final day in _itinerary.days) {
      final pt = TripLocationService.resolve(null, day.city);
      if (pt != null) points.add(pt);
    }
    if (points.isEmpty) {
      setState(() => _mapReady = true);
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 1.5, minLng - 1.5),
          LatLng(maxLat + 1.5, maxLng + 1.5),
        ),
        padding: const EdgeInsets.all(72),
      ),
    );
    setState(() => _mapReady = true);
  }

  Map<String, List<ItineraryItem>> get _itineraryItemsByDayId {
    final result = <String, List<ItineraryItem>>{};
    for (final day in _itinerary.days) {
      result[day.id] = _itinerary.itemsForDay(day.id);
    }
    return result;
  }

  // ── Visibility helpers ─────────────────────────────────────────────────────

  /// Day-only filtered — used for the route polyline so the full path is always
  /// visible regardless of the active type filter.
  List<TripMapMarker> get _routeMarkers =>
      MapViewMapperService.filterByDay(_allMarkers, _selectedDayId);

  /// Day + type filtered — used for bounding-box / zoom calculations and the
  /// empty-state check.
  List<TripMapMarker> get _focusMarkers {
    var m = MapViewMapperService.filterByDay(_allMarkers, _selectedDayId);
    m     = MapViewMapperService.filterByType(m, _selectedType);
    return m;
  }

  /// Pins to render: day + type filtered.
  List<TripMapMarker> get _displayMarkers {
    final byDay = MapViewMapperService.filterByDay(_allMarkers, _selectedDayId);
    return MapViewMapperService.filterByType(byDay, _selectedType);
  }

  TripMapMarker? get _focusedMarker =>
      _focusedMarkerId == null
          ? null
          : _allMarkers.where((m) => m.id == _focusedMarkerId).firstOrNull;

  // ── Camera ─────────────────────────────────────────────────────────────────

  /// Instant fit — used on first data load only.
  /// All subsequent navigation uses the animated [_transition] controller.
  void _fitVisible() {
    final bounds = MapViewMapperService.bounds(_focusMarkers);
    if (bounds == null) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds:  LatLngBounds(bounds.sw, bounds.ne),
        padding: const EdgeInsets.all(72),
      ),
    );
    setState(() => _mapReady = true);
  }

  bool get _reducedMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _flyTo(LatLng target, {double zoom = 14.5}) {
    _transition.animateTo(
      MapFocusConfig(center: target, zoom: zoom),
      reducedMotion: _reducedMotion,
    );
  }

  // ── Interaction ────────────────────────────────────────────────────────────

  void _onDayTap(String? dayId) {
    setState(() {
      _selectedDayId   = dayId;
      _focusedMarkerId = null;
    });

    // On first load (map not ready yet) fall back to instant fit.
    if (!_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitVisible());
      return;
    }

    // Compute target focus from the newly selected day's markers.
    // _focusMarkers reads _selectedDayId which was just updated above.
    final targets = _focusMarkers;
    if (targets.isEmpty) return;

    _transition.animateTo(
      MapTransitionController.focusForMarkers(targets),
      reducedMotion: _reducedMotion,
    );
  }

  void _onItemTap(String itemId) {
    final marker = _allMarkers.where((m) => m.id == itemId).firstOrNull;
    if (marker == null) return;
    setState(() => _focusedMarkerId = itemId);
    _flyTo(marker.position);
  }

  void _onPinTap(TripMapMarker marker) {
    setState(() => _focusedMarkerId = marker.id);
    _flyTo(marker.position);
  }

  void _dismissCard() => setState(() {
    _focusedMarkerId = null;
    _relocating      = false;
  });

  void _onMovePinRequested() => setState(() => _relocating = true);

  Future<void> _onMapTap(LatLng position) async {
    if (!_relocating || _focusedMarkerId == null) return;
    final marker = _focusedMarker;
    if (marker == null) return;
    setState(() => _relocating = false);
    await _itinerary.updateItem(marker.item.copyWith(
      latitude:  position.latitude,
      longitude: position.longitude,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: _itinerary,
      builder: (context, _) {
        if (_itinerary.isLoading && _itinerary.days.isEmpty) {
          return _LoadingState();
        }
        if (_itinerary.days.isEmpty) {
          return _EmptyState();
        }

        final isMobile = Responsive.isMobile(context);
        return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
      },
    );
  }

  // ── Desktop layout ─────────────────────────────────────────────────────────
  // [DayNavigatorPanel 260px] | [Map area fills remaining]

  Widget _buildDesktopLayout() {
    final panelW = Responsive.isDesktop(context) ? 280.0 : 220.0;

    return Row(
      children: [
        // Left panel
        SizedBox(
          width: panelW,
          child: DayNavigatorPanel(
            days:          _itinerary.days,
            itemsByDayId:  _itineraryItemsByDayId,
            allMarkers:    _allMarkers,
            selectedDayId: _selectedDayId,
            focusedItemId: _focusedMarkerId,
            onDayTap:      _onDayTap,
            onItemTap:     _onItemTap,
          ),
        ),
        // Map
        Expanded(child: _MapArea(
          displayMarkers:      _displayMarkers,
          routeMarkers:        _routeMarkers,
          focusedMarker:       _focusedMarker,
          showRoute:           _showRoute,
          selectedType:        _selectedType,
          mapController:       _mapController,
          relocating:          _relocating,
          onPinTap:            _onPinTap,
          onDismissCard:       _dismissCard,
          onMovePinRequested:  _onMovePinRequested,
          onMapTap:            _onMapTap,
          onFitAll:            _fitVisible,
          onTypeChanged:       (t) => setState(() {
            _selectedType    = t;
            _focusedMarkerId = null;
          }),
          onRouteToggled: (v) => setState(() => _showRoute = v),
        )),
      ],
    );
  }

  // ── Mobile layout ──────────────────────────────────────────────────────────
  // Full-screen map with AnimatedPositioned bottom sheet for the day navigator.

  Widget _buildMobileLayout() {
    final screenH      = MediaQuery.of(context).size.height;
    const collapsedH   = 108.0;
    final expandedH    = screenH * 0.56;
    final panelH       = _mobilePanelExpanded ? expandedH : collapsedH;

    return Stack(
      children: [
        // Full-screen map
        Positioned.fill(
          child: _MapArea(
            displayMarkers:     _displayMarkers,
            routeMarkers:       _routeMarkers,
            focusedMarker:      _focusedMarker,
            showRoute:          _showRoute,
            selectedType:       _selectedType,
            mapController:      _mapController,
            relocating:         _relocating,
            bottomInset:        panelH,
            onPinTap:           _onPinTap,
            onDismissCard:      _dismissCard,
            onMovePinRequested: _onMovePinRequested,
            onMapTap:           _onMapTap,
            onFitAll:           _fitVisible,
            onTypeChanged: (t) => setState(() {
              _selectedType    = t;
              _focusedMarkerId = null;
            }),
            onRouteToggled: (v) => setState(() => _showRoute = v),
          ),
        ),
        // Expandable bottom panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeOutCubic,
          bottom:   0,
          left:     0,
          right:    0,
          height:   panelH,
          child: _MobileBottomPanel(
            days:          _itinerary.days,
            itemsByDayId:  _itineraryItemsByDayId,
            allMarkers:    _allMarkers,
            selectedDayId: _selectedDayId,
            focusedItemId: _focusedMarkerId,
            expanded:      _mobilePanelExpanded,
            onToggle:      () => setState(() => _mobilePanelExpanded = !_mobilePanelExpanded),
            onDayTap:      _onDayTap,
            onItemTap:     _onItemTap,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MapArea — the flutter_map widget + overlays
// ─────────────────────────────────────────────────────────────────────────────

class _MapArea extends StatefulWidget {
  /// Day+type filtered markers — already scoped to the selected day at source.
  final List<TripMapMarker>  displayMarkers;

  /// Day+type filtered markers — used for the route polyline and empty-state.
  final List<TripMapMarker>  routeMarkers;

  final TripMapMarker?       focusedMarker;
  final bool                 showRoute;
  final ItemType?            selectedType;
  final MapController        mapController;
  final bool                 relocating;
  final double               bottomInset;
  final ValueChanged<TripMapMarker> onPinTap;
  final VoidCallback         onDismissCard;
  final VoidCallback         onMovePinRequested;
  final ValueChanged<LatLng> onMapTap;
  final VoidCallback         onFitAll;
  final ValueChanged<ItemType?> onTypeChanged;
  final ValueChanged<bool>   onRouteToggled;

  const _MapArea({
    required this.displayMarkers,
    required this.routeMarkers,
    required this.focusedMarker,
    required this.showRoute,
    required this.selectedType,
    required this.mapController,
    required this.relocating,
    required this.onPinTap,
    required this.onDismissCard,
    required this.onMovePinRequested,
    required this.onMapTap,
    required this.onFitAll,
    required this.onTypeChanged,
    required this.onRouteToggled,
    this.bottomInset = 0,
  });

  @override
  State<_MapArea> createState() => _MapAreaState();
}

class _MapAreaState extends State<_MapArea> {
  // Tracks the hovered marker id. Null = no hover.
  // ValueNotifier instead of setState so hover changes never rebuild FlutterMap
  // or destroy MouseRegion widgets, avoiding the enter/exit loop.
  final ValueNotifier<String?> _hoveredMarkerId = ValueNotifier(null);

  @override
  void dispose() {
    _hoveredMarkerId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayMarkers = widget.displayMarkers;
    final routeMarkers   = widget.routeMarkers;
    final focusedMarker  = widget.focusedMarker;
    final showRoute      = widget.showRoute;
    return Stack(
      children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: const LatLng(46.0, 14.0), // Central Europe fallback
            initialZoom:   5,
            minZoom:       2,
            maxZoom:       18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: widget.relocating
                ? (_, latLng) => widget.onMapTap(latLng)
                : null,
          ),
          children: [
            // Layer 1 — CartoDB Positron (no labels): preserves the original
            // clean, premium aesthetic exactly.
            TileLayer(
              urlTemplate:
                  'https://a.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.hodtravel.app',
              maxZoom: 19,
            ),

            // Layer 2 — Esri World Light Gray Reference: English-only label
            // overlay rendered in English regardless of the map location.
            // Esri tile order is /{z}/{row}/{col}; flutter_map substitutes
            // {y} and {x} by name so the template /{z}/{y}/{x} is correct.
            TileLayer(
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.hodtravel.app',
              maxZoom: 19,
            ),

            // Main trip route overlay (user-toggled).
            // Only the active day's route is drawn so the line stays readable.
            if (showRoute && routeMarkers.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points:      MapViewMapperService.routePoints(routeMarkers),
                    color:       AppColors.accent.withAlpha(200),
                    strokeWidth: 2.5,
                    pattern:     const StrokePattern.dotted(spacingFactor: 2.5),
                  ),
                ],
              ),

            // Markers — displayMarkers is already day+type filtered at source.
            MarkerLayer(
              markers: displayMarkers.map((m) {
                final focused     = focusedMarker?.id == m.id;
                final isTransport = m.isTransportIcon;
                final sz = isTransport
                    ? (focused ? 32.0 : 26.0)
                    : (focused ? 44.0 : 36.0);
                return Marker(
                  point:     m.position,
                  width:     sz,
                  height:    isTransport ? sz : (focused ? 52.0 : 43.0),
                  alignment: Alignment.center,
                  child: MouseRegion(
                    onEnter: isTransport ? null : (_) { _hoveredMarkerId.value = m.id; },
                    onExit:  isTransport ? null : (_) { _hoveredMarkerId.value = null; },
                    child: _MapPin(
                      marker:  m,
                      focused: focused,
                      onTap:   () => widget.onPinTap(m),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Distance labels — only shows segments touching the hovered pin.
            // ValueListenableBuilder rebuilds ONLY this layer on hover changes.
            if (showRoute && routeMarkers.length > 1)
              ValueListenableBuilder<String?>(
                valueListenable: _hoveredMarkerId,
                builder: (_, hoveredId, _) {
                  if (hoveredId == null) return const SizedBox.shrink();
                  final segments = MapViewMapperService.routeSegments(routeMarkers)
                      .where((seg) => seg.fromId == hoveredId || seg.toId == hoveredId)
                      .toList();
                  if (segments.isEmpty) return const SizedBox.shrink();
                  return MarkerLayer(
                    markers: segments.map((seg) => Marker(
                          point:     seg.midpoint,
                          width:     76,
                          height:    24,
                          alignment: Alignment.center,
                          child: _DistanceLabel(distanceKm: seg.distanceKm),
                        )).toList(),
                  );
                },
              ),
          ],
        ),

        // ── Attribution (required) ──────────────────────────────────────────
        Positioned(
          bottom: 4 + widget.bottomInset,
          right:  4,
          child: _Attribution(),
        ),

        // ── Type filter bar ─────────────────────────────────────────────────
        Positioned(
          top:   12,
          left:  12,
          right: 12,
          child: Row(
            children: [
              MapFiltersBar(
                selectedType:   widget.selectedType,
                showRoute:      showRoute,
                onTypeChanged:  widget.onTypeChanged,
                onRouteToggled: widget.onRouteToggled,
              ),
              const Spacer(),
              // Fit-all button
              _FitAllButton(onTap: widget.onFitAll),
            ],
          ),
        ),

        // ── Pin detail card ─────────────────────────────────────────────────
        if (focusedMarker != null)
          Positioned(
            bottom: 24 + widget.bottomInset,
            right:  16,
            child:  AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset:   const Offset(0, 0),
              child:    MapPinDetailCard(
                marker:    focusedMarker,
                onClose:   widget.onDismissCard,
                onMovePin: widget.relocating ? null : widget.onMovePinRequested,
              ),
            ),
          ),

        // ── Empty-day overlay ───────────────────────────────────────────────
        if (routeMarkers.isEmpty && displayMarkers.isEmpty)
          Center(child: _NoLocationsHint()),

        // ── Relocation mode overlay ─────────────────────────────────────────
        if (widget.relocating) ...[
          // Crosshair at centre
          const Center(
            child: Icon(Icons.add, size: 36, color: Colors.black54),
          ),
          // Instruction banner
          Positioned(
            top:   12,
            left:  12,
            right: 12,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color:        Colors.black.withAlpha(170),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tap the map to place the pin',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MapPin — custom pin widget used as a flutter_map Marker child
// ─────────────────────────────────────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final TripMapMarker marker;
  final bool          focused;
  final VoidCallback  onTap;

  const _MapPin({
    required this.marker,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color   = marker.item.effectiveColor;
    final icon    = marker.item.effectiveIcon;
    final pinSize = focused ? 36.0 : 28.0;

    return GestureDetector(
      onTap: onTap,
      child: marker.isTransportIcon
          // Transport items: flat badge that sits on the route line
          ? _TransportBadge(
              color:   color,
              focused: focused,
              icon:    icon,
            )
          // Location items: standard circle pin with pointer tip
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width:    pinSize,
                  height:   pinSize,
                  decoration: BoxDecoration(
                    color:  color.withAlpha(focused ? 240 : 200),
                    shape:  BoxShape.circle,
                    border: Border.all(
                      color: focused ? AppColors.accent : Colors.white,
                      width: focused ? 3.0 : 1.5,
                    ),
                    boxShadow: [
                      if (focused)
                        BoxShadow(
                          color:        AppColors.accent.withAlpha(60),
                          blurRadius:   14,
                          spreadRadius: 2,
                        ),
                      BoxShadow(
                        color:      Colors.black.withAlpha(focused ? 40 : 22),
                        blurRadius: focused ? 10 : 5,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size:  focused ? 16 : 13,
                    color: Colors.white,
                  ),
                ),
                CustomPaint(
                  size: const Size(10, 6),
                  painter: _PinTipPainter(
                    color: color.withAlpha(focused ? 230 : 200),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── _TransportBadge ───────────────────────────────────────────────────────────
/// Flat circular badge for transport items.
/// Sits on the route line at the midpoint between two adjacent location stops.
/// White fill + coloured border keeps it visually distinct from location pins
/// while reading clearly as an in-transit waypoint.

class _TransportBadge extends StatelessWidget {
  final Color    color;
  final bool     focused;
  final IconData icon;

  const _TransportBadge({
    required this.color,
    required this.focused,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final size = focused ? 32.0 : 26.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width:    size,
      height:   size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: focused ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(focused ? 35 : 18),
            blurRadius: focused ? 8 : 4,
            offset:     const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        icon,
        size:  focused ? 15 : 12,
        color: color,
      ),
    );
  }
}

// ── _PinTipPainter ─────────────────────────────────────────────────────────────

class _PinTipPainter extends CustomPainter {
  final Color color;
  const _PinTipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FitAllButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FitAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  38,
        height: 38,
        decoration: BoxDecoration(
          color:        AppColors.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border, width: 0.75),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(14),
              blurRadius: 10,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.fit_screen_outlined,
          size:  17,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '© OpenStreetMap contributors, © CARTO · Labels © Esri',
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 8,
          color:    AppColors.textMuted,
        ),
      ),
    );
  }
}

class _NoLocationsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color:        AppColors.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(10),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined,
              size: 24, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            'No locations to show',
            style: AppTextStyles.heading3
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a location to itinerary items\nto see them on the map.',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.accent,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DistanceLabel — small chip shown at the midpoint of each route segment
// ─────────────────────────────────────────────────────────────────────────────

class _DistanceLabel extends StatelessWidget {
  final double distanceKm;
  const _DistanceLabel({required this.distanceKm});

  String get _text {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withAlpha(100),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(14),
            blurRadius: 4,
            offset:     const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        _text,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize:   10,
          color:      AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile bottom panel — collapsible day navigator sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MobileBottomPanel extends StatelessWidget {
  final List<TripDay> days;
  final Map<String, List<ItineraryItem>> itemsByDayId;
  final List<TripMapMarker> allMarkers;
  final String? selectedDayId;
  final String? focusedItemId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String?> onDayTap;
  final ValueChanged<String>  onItemTap;

  const _MobileBottomPanel({
    required this.days,
    required this.itemsByDayId,
    required this.allMarkers,
    required this.selectedDayId,
    required this.focusedItemId,
    required this.expanded,
    required this.onToggle,
    required this.onDayTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withAlpha(20),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _PanelHandle(expanded: expanded, onToggle: onToggle),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: expanded
                ? DayNavigatorPanel(
                    days:          days,
                    itemsByDayId:  itemsByDayId,
                    allMarkers:    allMarkers,
                    selectedDayId: selectedDayId,
                    focusedItemId: focusedItemId,
                    onDayTap:      onDayTap,
                    onItemTap:     onItemTap,
                    showBorder:    false,
                    showHeader:    false,
                  )
                : _DayCarousel(
                    days:          days,
                    selectedDayId: selectedDayId,
                    onDayTap:      onDayTap,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── _PanelHandle ──────────────────────────────────────────────────────────────

class _PanelHandle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _PanelHandle({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  36,
              height: 4,
              decoration: BoxDecoration(
                color:        AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, size: 12, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'JOURNEY',
                    style: AppTextStyles.overline.copyWith(
                      color:        AppColors.accentDark,
                      fontSize:     10,
                      letterSpacing: 1.2,
                      fontWeight:   FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size:  18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DayCarousel ──────────────────────────────────────────────────────────────

/// Horizontal scrollable row of day cards shown in the collapsed bottom sheet.
class _DayCarousel extends StatelessWidget {
  final List<TripDay> days;
  final String? selectedDayId;
  final ValueChanged<String?> onDayTap;

  const _DayCarousel({
    required this.days,
    required this.selectedDayId,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding:         const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount:       days.length,
      itemBuilder:     (_, i) {
        final day        = days[i];
        final isSelected = selectedDayId == day.id;

        return GestureDetector(
          onTap: () => onDayTap(isSelected ? null : day.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:  84,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentFaint : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent.withAlpha(120)
                    : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DAY ${day.dayNumber}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      isSelected ? AppColors.accent : AppColors.textMuted,
                    fontSize:   9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day.city.isNotEmpty ? day.city : 'Day ${day.dayNumber}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize:   12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (day.date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM').format(day.date!),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 9,
                      color:    AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No itinerary yet',
            style: AppTextStyles.heading2
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Build the itinerary to see trip locations on the map.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
