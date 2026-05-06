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
      // Empty title — dashboard uses its own greeting section below
      appBar: AppHeader(
        title: '',
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
            padding: EdgeInsets.fromLTRB(
              hPad,
              AppSpacing.xl,
              hPad,
              AppSpacing.massive,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──────────────────────────────────────────────
                _Greeting(
                  userName:    AppRepositories.instance?.currentAppUser?.name,
                  activeCount: _provider.activeTrips.length,
                  taskCount:   _provider.myTasks.length,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // ── KPI grid (compact) ────────────────────────────────────
                _StatGrid(provider: _provider, isDesktop: isDesktop),
                const SizedBox(height: AppSpacing.xxl),

                // ── Operational intelligence (conditional) ────────────────
                if (_provider.alerts.isNotEmpty) ...[
                  IntelligenceSection(
                    alerts:       _provider.alerts,
                    alertsByTrip: _provider.alertsByTrip,
                    allTrips:     _provider.allTrips,
                    onRefresh:    _provider.reload,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Main content ──────────────────────────────────────────
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
                            // Trips first — emotional center
                            UpcomingTripsSection(
                              trips: _provider.upcomingTrips,
                              onTripTap: (t) => _openTrip(context, t),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            MyTasksSection(tasks: _provider.myTasks),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      SizedBox(
                        width: 300,
                        child: TeamActivitySection(activity: _provider.teamActivity),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      UpcomingTripsSection(
                        trips: _provider.upcomingTrips,
                        onTripTap: (t) => _openTrip(context, t),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      MyTasksSection(tasks: _provider.myTasks),
                      const SizedBox(height: AppSpacing.xxl),
                      TeamActivitySection(activity: _provider.teamActivity),
                    ],
                  ),
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
  final int activeCount;
  final int taskCount;

  const _Greeting({
    this.userName,
    required this.activeCount,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final first    = (userName ?? 'there').split(' ').first;

    final parts = <String>[];
    if (activeCount > 0) {
      parts.add('$activeCount ${activeCount == 1 ? 'trip' : 'trips'} active today.');
    }
    if (taskCount > 0) {
      parts.add('$taskCount ${taskCount == 1 ? 'task needs' : 'tasks need'} attention.');
    }
    final subtitle = parts.isNotEmpty ? parts.join('  ') : "Let's plan something great.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $first.',
          style: AppTextStyles.displayMedium.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
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
        iconColor: const Color(0xFFC9A96E),  // gold
        iconBg:   const Color(0xFFFDF8F0),
        subtitle: 'in progress now',
      ),
      _StatData(
        label:    'Due Today',
        value:    '${provider.tasksDueToday.length}',
        icon:     Icons.task_alt_rounded,
        iconColor: const Color(0xFFEF4444),  // muted red
        iconBg:   const Color(0xFFFEF2F2),
        subtitle: 'tasks due today',
      ),
      _StatData(
        label:    'My Tasks',
        value:    '${provider.myTasks.length}',
        icon:     Icons.checklist_rounded,
        iconColor: const Color(0xFF3B82F6),  // blue
        iconBg:   const Color(0xFFEFF6FF),
        subtitle: 'across all trips',
      ),
      _StatData(
        label:    'Departures',
        value:    '${provider.upcomingDepartureCount}',
        icon:     Icons.luggage_rounded,
        iconColor: const Color(0xFF10B981),  // muted green
        iconBg:   const Color(0xFFECFDF5),
        subtitle: 'within 30 days',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          // Taller aspect ratio = shorter cards (~35% height reduction)
          childAspectRatio: constraints.maxWidth > 600 ? 2.0 : 1.8,
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
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'New Trip',
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
