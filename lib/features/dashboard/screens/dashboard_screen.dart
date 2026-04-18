import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../features/trip_board/screens/trip_board_screen.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/intelligence_section.dart';
import '../widgets/my_tasks_section.dart';
import '../widgets/upcoming_trips_section.dart';
import '../widgets/team_activity_section.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int index) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardProvider _provider;

  @override
  void initState() {
    super.initState();
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    _provider = DashboardProvider(
      trips:  repos?.trips,
      tasks:  repos?.tasks,
      teamId: teamId,
      userId: repos?.currentUserId,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _openTrip(BuildContext context, Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripBoardScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile  = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);
    final hPad = isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Dashboard',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [
          _NewTripButton(onTap: () => widget.onNavigate(1)),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.pagePaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Greeting(userName: AppRepositories.instance?.currentAppUser?.name),
                const SizedBox(height: AppSpacing.xl),

                _StatGrid(provider: _provider, isDesktop: isDesktop),
                const SizedBox(height: AppSpacing.xxl),

                // ── Operational intelligence ────────────────────────────────
                if (_provider.alerts.isNotEmpty) ...[
                  IntelligenceSection(
                    alerts:       _provider.alerts,
                    alertsByTrip: _provider.alertsByTrip,
                    allTrips:     _provider.allTrips,
                    onRefresh:    _provider.reload,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                if (_provider.isLoading && _provider.allTrips.isEmpty)
                  const Center(child: CircularProgressIndicator(
                    color: AppColors.accent, strokeWidth: 2,
                  ))
                else if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            MyTasksSection(tasks: _provider.myTasks),
                            const SizedBox(height: AppSpacing.xxl),
                            UpcomingTripsSection(
                              trips: _provider.upcomingTrips,
                              onTripTap: (t) => _openTrip(context, t),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      SizedBox(
                        width: 320,
                        child: TeamActivitySection(activity: _provider.teamActivity),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      MyTasksSection(tasks: _provider.myTasks),
                      const SizedBox(height: AppSpacing.xxl),
                      UpcomingTripsSection(
                        trips: _provider.upcomingTrips,
                        onTripTap: (t) => _openTrip(context, t),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      TeamActivitySection(activity: _provider.teamActivity),
                    ],
                  ),

                const SizedBox(height: AppSpacing.massive),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final String? userName;
  const _Greeting({this.userName});

  @override
  Widget build(BuildContext context) {
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final first    = (userName ?? 'there').split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $first.', style: AppTextStyles.displayMedium),
        const SizedBox(height: 4),
        Text(
          "Here's what's happening today.",
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Stat grid ─────────────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final DashboardProvider provider;
  final bool isDesktop;
  const _StatGrid({required this.provider, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        label:    'Active Trips',
        value:    '${provider.activeTrips.length}',
        icon:     Icons.flight_takeoff_rounded,
        iconColor: const Color(0xFF6366F1),
        iconBg:   const Color(0xFFEEF2FF),
        subtitle: 'in progress now',
      ),
      _StatData(
        label:    'Tasks Due Today',
        value:    '${provider.tasksDueToday.length}',
        icon:     Icons.task_alt_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg:   const Color(0xFFFEF3C7),
        subtitle: 'assigned to you',
      ),
      _StatData(
        label:    'My Tasks',
        value:    '${provider.myTasks.length}',
        icon:     Icons.checklist_rounded,
        iconColor: const Color(0xFFEC4899),
        iconBg:   const Color(0xFFFCE7F3),
        subtitle: 'across all trips',
      ),
      _StatData(
        label:    'Upcoming Departures',
        value:    '${provider.upcomingDepartureCount}',
        icon:     Icons.luggage_rounded,
        iconColor: const Color(0xFF10B981),
        iconBg:   const Color(0xFFD1FAE5),
        subtitle: 'within 30 days',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: constraints.maxWidth > 700 ? 1.4 : 1.5,
          children: stats.map((s) => StatCard(
            label:     s.label,
            value:     s.value,
            icon:      s.icon,
            iconColor: s.iconColor,
            iconBg:    s.iconBg,
            subtitle:  s.subtitle,
          )).toList(),
        );
      },
    );
  }
}

class _StatData {
  final String label, value, subtitle;
  final IconData icon;
  final Color iconColor, iconBg;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.subtitle,
  });
}

// ── New Trip button ───────────────────────────────────────────────────────────

class _NewTripButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTripButton({required this.onTap});

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
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'New Trip',
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
