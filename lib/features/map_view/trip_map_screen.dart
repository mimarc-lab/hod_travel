import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  const TripMapScreen({super.key, required this.trip});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  // ── Providers ──────────────────────────────────────────────────────────────
  late final ItineraryProvider _itinerary;

  // ── Map ────────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  late final MapTransitionController _transition;
  bool _mapReady = false;

  // ── Filter state ───────────────────────────────────────────────────────────
  String?   _selectedDayId;
  ItemType? _selectedType;
  bool      _showRoute = false;

  // ── Selection state ────────────────────────────────────────────────────────
  String? _focusedMarkerId; // item.id of the tapped pin

  // ── Computed markers (rebuilt on provider update + filter change) ──────────
  List<TripMapMarker> _allMarkers = const [];

  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _itinerary = ItineraryProvider(
      widget.trip,
      repository: AppRepositories.instance?.itinerary,
      teamId:     AppRepositories.instance?.currentTeamId,
    );
    _transition = MapTransitionController(
      mapController: _mapController,
      vsync:         this,
    );
    _itinerary.addListener(_onItineraryChanged);
  }

  @override
  void dispose() {
    _itinerary.removeListener(_onItineraryChanged);
    _itinerary.dispose();
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
    setState(() => _allMarkers = markers);

    // Fit camera once on first load
    if (!_mapReady && markers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitVisible());
    }
  }

  Map<String, List<ItineraryItem>> get _itineraryItemsByDayId {
    final result = <String, List<ItineraryItem>>{};
    for (final day in _itinerary.days) {
      result[day.id] = _itinerary.itemsForDay(day.id);
    }
    return result;
  }

  // ── Visibility helpers ─────────────────────────────────────────────────────

  /// Day + type filtered — used for route polyline, empty-state detection,
  /// and bounding-box / zoom calculations.
  List<TripMapMarker> get _focusMarkers {
    var m = MapViewMapperService.filterByDay(_allMarkers, _selectedDayId);
    m     = MapViewMapperService.filterByType(m, _selectedType);
    return m;
  }

  /// Type filtered only (no day filter) — all pins rendered on the map.
  /// Day filtering is expressed visually via per-pin opacity, keeping all
  /// locations visible for geographic context while emphasising the active day.
  List<TripMapMarker> get _displayMarkers =>
      MapViewMapperService.filterByType(_allMarkers, _selectedType);

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

  void _dismissCard() => setState(() => _focusedMarkerId = null);

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
    final panelW = Responsive.isDesktop(context) ? 260.0 : 220.0;

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
          displayMarkers: _displayMarkers,
          routeMarkers:   _focusMarkers,
          activeDayId:    _selectedDayId,
          focusedMarker:  _focusedMarker,
          showRoute:      _showRoute,
          selectedType:   _selectedType,
          mapController:  _mapController,
          onPinTap:       _onPinTap,
          onDismissCard:  _dismissCard,
          onFitAll:       _fitVisible,
          onTypeChanged:  (t) => setState(() {
            _selectedType    = t;
            _focusedMarkerId = null;
          }),
          onRouteToggled: (v) => setState(() => _showRoute = v),
        )),
      ],
    );
  }

  // ── Mobile layout ──────────────────────────────────────────────────────────
  // [Map ~55%] / [Bottom day panel ~45%]

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Map
        Expanded(
          flex: 55,
          child: _MapArea(
            displayMarkers: _displayMarkers,
            routeMarkers:   _focusMarkers,
            activeDayId:    _selectedDayId,
            focusedMarker:  _focusedMarker,
            showRoute:      _showRoute,
            selectedType:   _selectedType,
            mapController:  _mapController,
            onPinTap:       _onPinTap,
            onDismissCard:  _dismissCard,
            onFitAll:       _fitVisible,
            onTypeChanged:  (t) => setState(() {
              _selectedType    = t;
              _focusedMarkerId = null;
            }),
            onRouteToggled: (v) => setState(() => _showRoute = v),
          ),
        ),
        // Bottom day panel
        Expanded(
          flex: 45,
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MapArea — the flutter_map widget + overlays
// ─────────────────────────────────────────────────────────────────────────────

class _MapArea extends StatelessWidget {
  /// All type-filtered markers — rendered on the map, with inactive-day ones
  /// faded to give geographic context without visual clutter.
  final List<TripMapMarker>  displayMarkers;

  /// Day + type filtered markers — used for the route polyline and the
  /// "no locations" empty-state check.
  final List<TripMapMarker>  routeMarkers;

  /// The currently selected day ID.  Pins from other days are rendered at
  /// reduced opacity.  Null = all days active (no dimming).
  final String?              activeDayId;

  final TripMapMarker?       focusedMarker;
  final bool                 showRoute;
  final ItemType?            selectedType;
  final MapController        mapController;
  final ValueChanged<TripMapMarker> onPinTap;
  final VoidCallback         onDismissCard;
  final VoidCallback         onFitAll;
  final ValueChanged<ItemType?> onTypeChanged;
  final ValueChanged<bool>   onRouteToggled;

  const _MapArea({
    required this.displayMarkers,
    required this.routeMarkers,
    required this.activeDayId,
    required this.focusedMarker,
    required this.showRoute,
    required this.selectedType,
    required this.mapController,
    required this.onPinTap,
    required this.onDismissCard,
    required this.onFitAll,
    required this.onTypeChanged,
    required this.onRouteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(35.6762, 139.6503), // Tokyo fallback
            initialZoom:   5,
            minZoom:       2,
            maxZoom:       18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
                    color:       AppColors.accent.withAlpha(140),
                    strokeWidth: 1.8,
                    pattern:     const StrokePattern.dotted(spacingFactor: 3),
                  ),
                ],
              ),

            // Markers — all type-filtered pins are shown; pins from inactive
            // days fade to 22 % opacity so the full journey is always visible
            // for geographic context while the active day stays prominent.
            MarkerLayer(
              markers: displayMarkers.map((m) {
                final focused     = focusedMarker?.id == m.id;
                final isActive    = activeDayId == null || m.day.id == activeDayId;
                final isTransport = m.isTransportIcon;
                final sz = isTransport
                    ? (focused ? 32.0 : 26.0)
                    : (focused ? 44.0 : 36.0);
                return Marker(
                  point:     m.position,
                  width:     sz,
                  height:    isTransport ? sz : (focused ? 52.0 : 43.0),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    // Inactive-day pins fade smoothly when a day is selected.
                    duration: const Duration(milliseconds: 350),
                    opacity:  isActive ? 1.0 : 0.22,
                    child: _MapPin(
                      marker:  m,
                      focused: focused,
                      onTap:   () => onPinTap(m),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // ── Attribution (required) ──────────────────────────────────────────
        Positioned(
          bottom: 4,
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
                selectedType:   selectedType,
                showRoute:      showRoute,
                onTypeChanged:  onTypeChanged,
                onRouteToggled: onRouteToggled,
              ),
              const Spacer(),
              // Fit-all button
              _FitAllButton(onTap: onFitAll),
            ],
          ),
        ),

        // ── Pin detail card ─────────────────────────────────────────────────
        if (focusedMarker != null)
          Positioned(
            bottom: 24,
            right:  16,
            child:  AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset:   const Offset(0, 0),
              child:    MapPinDetailCard(
                marker:  focusedMarker!,
                onClose: onDismissCard,
              ),
            ),
          ),

        // ── Empty-day overlay ───────────────────────────────────────────────
        if (routeMarkers.isEmpty && displayMarkers.isEmpty)
          Center(child: _NoLocationsHint()),
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
    final color   = marker.item.type.color;
    final pinSize = focused ? 36.0 : 28.0;

    return GestureDetector(
      onTap: onTap,
      child: marker.isTransportIcon
          // Transport items: flat badge that sits on the route line
          ? _TransportBadge(
              color:   color,
              focused: focused,
              icon:    marker.item.type.icon,
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
                    color:  color.withAlpha(focused ? 230 : 200),
                    shape:  BoxShape.circle,
                    border: Border.all(
                      color: focused ? AppColors.accent : Colors.white,
                      width: focused ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withAlpha(focused ? 40 : 22),
                        blurRadius: focused ? 10 : 5,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    marker.item.type.icon,
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
