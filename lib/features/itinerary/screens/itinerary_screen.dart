import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_model.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/day_navigator.dart';
import '../widgets/itinerary_day_view.dart';

/// Itinerary Builder tab — shown inside TripBoardScreen's TabBarView.
/// Uses AutomaticKeepAliveClientMixin to preserve state across tab switches.
/// Pass [provider] to share an existing ItineraryProvider (e.g. from TripBoardScreen).
class ItineraryScreen extends StatefulWidget {
  final Trip trip;
  /// If supplied, this provider is used instead of creating a new one.
  /// The caller is responsible for disposing it.
  final ItineraryProvider? provider;
  const ItineraryScreen({super.key, required this.trip, this.provider});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen>
    with AutomaticKeepAliveClientMixin {
  late final ItineraryProvider _provider;
  late final bool _ownsProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.provider != null) {
      _provider = widget.provider!;
      _ownsProvider = false;
    } else {
      _provider = ItineraryProvider(
        widget.trip,
        repository: AppRepositories.instance?.itinerary,
        teamId:     AppRepositories.instance?.currentTeamId,
      );
      _ownsProvider = true;
    }
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.isLoading && _provider.days.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (_provider.error != null && _provider.days.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 32, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _provider.error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  TextButton.icon(
                    onPressed: _provider.reload,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (_provider.days.isEmpty) {
          return _EmptyItinerary(provider: _provider);
        }
        if (Responsive.isMobile(context)) {
          return _MobileLayout(provider: _provider);
        }
        return _DesktopLayout(provider: _provider);
      },
    );
  }
}

// ── Desktop layout ────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final ItineraryProvider provider;
  const _DesktopLayout({required this.provider});

  @override
  Widget build(BuildContext context) {
    final day = provider.selectedDay;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DayNavigatorPanel(provider: provider),
        Expanded(
          child: day == null
              ? const SizedBox.shrink()
              : ItineraryDayView(
                  key: ValueKey(day.id),
                  day: day,
                  provider: provider,
                ),
        ),
      ],
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final ItineraryProvider provider;
  const _MobileLayout({required this.provider});

  @override
  Widget build(BuildContext context) {
    final day = provider.selectedDay;
    return Column(
      children: [
        DayChipsRow(provider: provider),
        Expanded(
          child: day == null
              ? const SizedBox.shrink()
              : ItineraryDayView(
                  key: ValueKey(day.id),
                  day: day,
                  provider: provider,
                ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyItinerary extends StatelessWidget {
  final ItineraryProvider provider;
  const _EmptyItinerary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.map_outlined,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No itinerary yet', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text(
            'Add your first day to start building the schedule.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => showAddDaySheet(context, provider: provider),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Day'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
