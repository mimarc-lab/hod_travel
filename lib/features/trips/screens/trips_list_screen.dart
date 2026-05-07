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
    // Status dropdown + search bar inline
    return Row(
      children: [
        _TripStatusDropdown(
          selected: filterStatus,
          onChanged: onFilterChanged,
        ),
        const SizedBox(width: 10),
        Expanded(child: _TripSearchBar(onChanged: onSearchChanged)),
      ],
    );
  }
}

// ── Trip search bar ───────────────────────────────────────────────────────────

class _TripSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _TripSearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.75),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search trips, clients, destinations…',
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}

// ── Trip status dropdown ──────────────────────────────────────────────────────

class _TripStatusDropdown extends StatelessWidget {
  final TripStatus? selected;
  final ValueChanged<TripStatus?> onChanged;

  const _TripStatusDropdown({
    required this.selected,
    required this.onChanged,
  });

  static const _statusColors = {
    TripStatus.planning:   Color(0xFF3B82F6),
    TripStatus.confirmed:  Color(0xFFC9A96E),
    TripStatus.inProgress: Color(0xFFF59E0B),
    TripStatus.completed:  Color(0xFF10B981),
    TripStatus.cancelled:  Color(0xFF9CA3AF),
  };

  Color get _dotColor =>
      selected != null ? _statusColors[selected]! : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;
    final label = selected?.label ?? 'Status';
    final dotColor = _dotColor;
    final borderColor =
        hasSelection ? dotColor.withAlpha(100) : AppColors.border;
    final bgColor = hasSelection ? dotColor.withAlpha(18) : AppColors.surface;

    return PopupMenuButton<TripStatus?>(
      onSelected: onChanged,
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      shadowColor: const Color(0x18000000),
      constraints: const BoxConstraints(minWidth: 180),
      itemBuilder: (_) => [
        // All trips
        PopupMenuItem<TripStatus?>(
          value: null,
          child: _DropdownItem(
            label: 'All Trips',
            dotColor: AppColors.textMuted,
            isSelected: selected == null,
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...TripStatus.values.map(
          (s) => PopupMenuItem<TripStatus?>(
            value: s,
            child: _DropdownItem(
              label: s.label,
              dotColor: _statusColors[s]!,
              isSelected: selected == s,
            ),
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.75),
          boxShadow: const [
            BoxShadow(
              color: Color(0x09000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight:
                    hasSelection ? FontWeight.w600 : FontWeight.w400,
                color:
                    hasSelection ? dotColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: hasSelection ? dotColor : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool isSelected;
  const _DropdownItem({
    required this.label,
    required this.dotColor,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? dotColor : AppColors.textSecondary,
          ),
        ),
        if (isSelected) ...[
          const Spacer(),
          Icon(Icons.check_rounded, size: 14, color: dotColor),
        ],
      ],
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
