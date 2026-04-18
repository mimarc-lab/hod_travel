import 'package:flutter/material.dart';
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

  void _openTrip(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripBoardScreen(trip: trip)),
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
    // Provider notifies ListenableBuilder automatically after update.
  }

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
          if (_provider.isLoading && _provider.trips.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            );
          }

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
                    child: Text('Retry',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.pagePaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchAndFilters(
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  filterStatus: _filterStatus,
                  onFilterChanged: (s) => setState(() => _filterStatus = s),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const TripTableHeader(),
                        const Divider(height: 1, color: AppColors.divider),
                        Expanded(
                          child: _filtered.isEmpty
                              ? EmptyState(
                                  icon: Icons.flight_takeoff_rounded,
                                  title: 'No trips found',
                                  subtitle: _search.isNotEmpty
                                      ? 'Try adjusting your search or filters.'
                                      : 'Create your first trip to get started.',
                                  actionLabel:
                                      _search.isEmpty ? 'Create Trip' : null,
                                  onAction: _openCreateTrip,
                                )
                              : ListView.separated(
                                  itemCount: _filtered.length,
                                  separatorBuilder: (context, i) => const Divider(
                                    height: 1,
                                    color: AppColors.divider,
                                  ),
                                  itemBuilder: (_, i) => TripRow(
                                    trip: _filtered[i],
                                    onTap: () => _openTrip(_filtered[i]),
                                    onEdit: () => _openEditTrip(_filtered[i]),
                                  ),
                                ),
                        ),
                      ],
                    ),
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

// ── Search + filter bar ────────────────────────────────────────────────────────

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
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 38,
          child: TextField(
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
                vertical: 0,
                horizontal: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(
                    color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        ...[null, TripStatus.planning, TripStatus.confirmed,
            TripStatus.inProgress, TripStatus.completed, TripStatus.cancelled]
            .map((status) => _FilterChip(
                  label: status == null ? 'All' : status.label,
                  selected: filterStatus == status,
                  onTap: () => onFilterChanged(status),
                )),
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
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius:
              BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Create trip button ─────────────────────────────────────────────────────────

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
          borderRadius:
              BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Create Trip',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
