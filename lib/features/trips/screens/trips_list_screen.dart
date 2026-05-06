import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../trip_board/screens/trip_board_screen.dart';
import '../providers/trip_provider.dart';
import '../widgets/trip_row.dart';
import 'create_trip_screen.dart';
import 'edit_trip_screen.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  late final TripProvider _provider;
  String _search = '';
  TripStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _provider = TripProvider(
      repository: AppRepositories.instance?.trips,
      teamId:     AppRepositories.instance?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  // ── Filter logic (unchanged) ───────────────────────────────────────────────

  List<Trip> get _filtered => _provider.trips.where((t) {
    final matchSearch =
        _search.isEmpty ||
        t.name.toLowerCase().contains(_search.toLowerCase()) ||
        t.clientName.toLowerCase().contains(_search.toLowerCase()) ||
        t.destinations.any(
          (d) => d.toLowerCase().contains(_search.toLowerCase()),
        );
    final matchStatus = _filterStatus == null || t.status == _filterStatus;
    return matchSearch && matchStatus;
  }).toList();

  // ── Navigation (unchanged) ─────────────────────────────────────────────────

  void _openTrip(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripBoardScreen(trip: trip, tripProvider: _provider),
      ),
    );
  }

  void _openCreateTrip() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTripScreen(tripProvider: _provider),
      ),
    );
  }

  void _openEditTrip(Trip trip) {
    Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (_) => EditTripScreen(
          trip: trip,
          tripProvider: _provider,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Trips',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [_CreateTripButton(onTap: _openCreateTrip)],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          // Loading state
          if (_provider.isLoading && _provider.trips.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            );
          }

          // Error state
          if (_provider.error != null && _provider.trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.base),
                  Text(_provider.error!, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.base),
                  GestureDetector(
                    onTap: _provider.reload,
                    child: Text(
                      'Retry',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              AppSpacing.pagePaddingV,
              hPad,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Search + filter bar ──────────────────────────────────
                _SearchAndFilters(
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  filterStatus: _filterStatus,
                  onFilterChanged: (s) => setState(() => _filterStatus = s),
                ),
                const SizedBox(height: 20),

                // ── Trip card grid ────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.flight_takeoff_rounded,
                          title: 'No trips found',
                          subtitle: _search.isNotEmpty
                              ? 'Try adjusting your search or filters.'
                              : 'Create your first trip to get started.',
                          actionLabel: _search.isEmpty ? 'Create Trip' : null,
                          onAction: _openCreateTrip,
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final cols =
                                constraints.maxWidth > 600 ? 2 : 1;
                            final spacing = 20.0;
                            final cardWidth = (constraints.maxWidth -
                                    (cols - 1) * spacing) /
                                cols;
                            const cardHeight = 256.0;
                            return GridView.builder(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.massive),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
                                childAspectRatio: cardWidth / cardHeight,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final trip = _filtered[i];
                                return TripCard(
                                  key: ValueKey(trip.id),
                                  trip: trip,
                                  gradientIndex:
                                      trip.id.hashCode.abs() % 6,
                                  onTap: () => _openTrip(trip),
                                  onEdit: () => _openEditTrip(trip),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Search + filter bar ───────────────────────────────────────────────────────

class _SearchAndFilters extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final TripStatus? filterStatus;
  final ValueChanged<TripStatus?> onFilterChanged;

  const _SearchAndFilters({
    required this.search,
    required this.onSearchChanged,
    required this.filterStatus,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar — 48px tall, radius 14
        TextField(
          onChanged: onSearchChanged,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search trips…',
            hintStyle: AppTextStyles.bodySmall,
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Filter chips — horizontally scrollable on all screen sizes
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              null,
              TripStatus.planning,
              TripStatus.confirmed,
              TripStatus.inProgress,
              TripStatus.completed,
              TripStatus.cancelled,
            ].asMap().entries.map((entry) {
              final i = entry.key;
              final status = entry.value;
              return Padding(
                padding: EdgeInsets.only(right: i < 5 ? 8 : 0),
                child: _FilterChip(
                  label: status == null ? 'All' : status.label,
                  selected: filterStatus == status,
                  onTap: () => onFilterChanged(status),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

// ── Create trip button ────────────────────────────────────────────────────────

class _CreateTripButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateTripButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Create Trip',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
