import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_model.dart';
import '../../../features/budget/screens/trip_budget_screen.dart';
import '../../../features/client_view/client_itinerary_screen.dart';
import '../../../features/itinerary/screens/itinerary_screen.dart';
import '../../../features/run_sheet/run_sheet_screen.dart';
import '../../../features/timeline/timeline_screen.dart';
import '../../../features/map_view/trip_map_screen.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../core/supabase/app_db.dart';
import '../providers/board_provider.dart';
import '../../../features/intelligence/widgets/trip_intelligence_panel.dart';
import '../../../features/itinerary/providers/itinerary_provider.dart';
import '../../../features/trips/providers/trip_provider.dart';
import '../../../features/trips/screens/edit_trip_screen.dart';
import '../widgets/board_group.dart';
import '../widgets/planning_timeline_banner.dart';
import '../widgets/task_detail/task_detail_panel.dart';
import '../widgets/task_row.dart';

class TripBoardScreen extends StatefulWidget {
  final Trip trip;

  /// When set, the board auto-selects this task after loading (used by Task Center).
  final String? initialTaskId;

  /// When provided, delete is routed through this provider so the trips list
  /// updates immediately without requiring a manual refresh.
  final TripProvider? tripProvider;

  const TripBoardScreen({super.key, required this.trip, this.initialTaskId, this.tripProvider});

  @override
  State<TripBoardScreen> createState() => _TripBoardScreenState();
}

class _TripBoardScreenState extends State<TripBoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController     _tabController;
  late final BoardProvider     _provider;
  late final ItineraryProvider _itineraryProvider;

  /// Mutable local copy of the trip — updated when the user saves edits.
  late Trip _currentTrip;

  static const _tabs = ['Board', 'Timeline', 'Map', 'Itinerary', 'Budget', 'Intelligence', 'Client View'];

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _provider = BoardProvider(
      widget.trip,
      repository:        AppRepositories.instance?.tasks,
      subtaskRepository: AppRepositories.instance?.subtasks,
      teamId:            AppRepositories.instance?.currentTeamId,
      currentUserId:     AppRepositories.instance?.currentUserId,
      initialTaskId:     widget.initialTaskId,
    );
    _itineraryProvider = ItineraryProvider(
      widget.trip,
      repository: AppRepositories.instance?.itinerary,
      teamId:     AppRepositories.instance?.currentTeamId,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _provider.dispose();
    _itineraryProvider.dispose();
    super.dispose();
  }

  Future<void> _openEditTrip(BuildContext context) async {
    final updated = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (_) => EditTripScreen(trip: _currentTrip),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentTrip = updated);
    }
  }

  Future<void> _onRecalculate(BuildContext context) async {
    if (_currentTrip.startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip has no start date — cannot recalculate schedule.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recalculate Schedule?'),
        content: const Text(
          'This will re-run the planning engine and update the start date and '
          'due date of every task based on their current durations.\n\n'
          'Any manual date adjustments will be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final analysis = await _provider.recalculateSchedule();
      if (!mounted) return;
      if (analysis == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks to reschedule.')),
        );
        return;
      }
      final start    = analysis.earliestStartDate;
      final deadline = analysis.planningDeadline;
      final msg = analysis.hasWarnings
          ? analysis.warnings.first
          : 'Schedule updated — ${analysis.tasks.length} tasks rescheduled. '
            'Planning: ${_fmtDate(start)} → ${_fmtDate(deadline)}  ·  '
            '${analysis.timelineDurationDays} days  ·  ${analysis.totalEffortDays} task-days';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: analysis.isCompressed
              ? Colors.orange.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('[Recalculate] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not recalculate schedule. Please try again.')),
      );
    }
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month]} ${d.day}';
  }

  void _openRunSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunSheetScreen(trip: widget.trip),
      ),
    );
  }

  Future<void> _deleteTrip(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'This will permanently delete "${_currentTrip.name}" and all its tasks, '
          'budget items, and itinerary. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (widget.tripProvider != null) {
        // Routes through provider so the trips list removes the entry immediately.
        await widget.tripProvider!.deleteTrip(_currentTrip.id);
      } else {
        await AppRepositories.instance?.trips.delete(_currentTrip.id);
      }
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // back to trips list
    } catch (_) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete trip. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TripHeader(
            trip: _currentTrip,
            onBack: () => Navigator.of(context).pop(),
            onEdit: () => _openEditTrip(context),
            onDelete: () => _deleteTrip(context),
            onRunSheet: () => _openRunSheet(context),
          ),
          _BoardTabBar(controller: _tabController, tabs: _tabs),
          PlanningTimelineBanner(trip: _currentTrip, provider: _provider),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main content — board + placeholder tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _BoardTab(
                        provider: _provider,
                        onAiAssist: () =>
                            _tabController.animateTo(5), // Intelligence tab
                        onRecalculate: () => _onRecalculate(context),
                      ),
                      TimelineScreen(trip: widget.trip, provider: _provider), // Timeline
                      TripMapScreen(trip: widget.trip, provider: _itineraryProvider), // Map
                      ItineraryScreen(trip: widget.trip, provider: _itineraryProvider),
                      TripBudgetScreen(trip: widget.trip),
                      TripIntelligencePanel(
                        trip: widget.trip,
                        boardProvider: _provider,
                        itineraryProvider: _itineraryProvider,
                      ),
                      ClientItineraryScreen(trip: widget.trip),
                    ],
                  ),
                ),

                // Animated side panel (desktop/tablet only)
                if (Responsive.showSidebar(context))
                  _PanelSlot(provider: _provider),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated panel slot ───────────────────────────────────────────────────────
// Isolated ListenableBuilder so only the panel rebuilds on provider changes,
// leaving the TabBarView and TabController untouched.

class _PanelSlot extends StatelessWidget {
  final BoardProvider provider;
  const _PanelSlot({required this.provider});

  static const double _panelWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final task = provider.selectedTask;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: task != null ? _panelWidth : 0.0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: task != null
              ? TaskDetailPanel(
                  key: ValueKey(task.id),
                  task: task,
                  provider: provider,
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

// ── Trip Header ───────────────────────────────────────────────────────────────

class _TripHeader extends StatelessWidget {
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRunSheet;
  const _TripHeader({
    required this.trip,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onRunSheet,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yyyy').format(trip.endDate!)}'
        : 'Dates TBD';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical: AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Trips', style: AppTextStyles.bodySmall),
                Text(' / ', style: AppTextStyles.bodySmall),
                Text(trip.name, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Trip name + status + options
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(trip.name, style: AppTextStyles.displayMedium)),
              TripStatusChip(status: trip.status),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit')      onEdit();
                  if (value == 'run_sheet') onRunSheet();
                  if (value == 'delete')    onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Edit Trip'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'run_sheet',
                    child: Row(
                      children: [
                        Icon(Icons.assignment_outlined, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Run Sheet'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete trip', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.more_horiz_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Meta row
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: 6,
            children: [
              _MetaItem(icon: Icons.person_outline_rounded,   label: trip.clientName),
              _MetaItem(icon: Icons.calendar_today_outlined,  label: dateStr),
              _MetaItem(icon: Icons.location_on_outlined,     label: trip.destinationSummary),
              _MetaItem(icon: Icons.people_outline_rounded,   label: '${trip.guestCount} guests'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(user: trip.tripLead, size: 18),
                  const SizedBox(width: 5),
                  Text(trip.tripLead.name, style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _BoardTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  const _BoardTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.divider),
          TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle:            AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle:  AppTextStyles.bodySmall,
            labelColor:            AppColors.accent,
            unselectedLabelColor:  AppColors.textSecondary,
            indicatorColor:        AppColors.accent,
            indicatorWeight:       2,
            dividerColor:          Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
            tabs: tabs.map((t) => Tab(text: t, height: 42)).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Board tab ─────────────────────────────────────────────────────────────────

class _BoardTab extends StatelessWidget {
  final BoardProvider provider;
  final VoidCallback? onAiAssist;
  final VoidCallback? onRecalculate;
  const _BoardTab({required this.provider, this.onAiAssist, this.onRecalculate});

  static const double _totalWidth = BoardColumns.totalWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BoardToolbar(onAiAssist: onAiAssist, onRecalculate: onRecalculate, provider: provider),
        Expanded(
          child: ListenableBuilder(
            listenable: provider,
            builder: (context, _) {
              final selectedId = provider.selectedTask?.id;
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: _totalWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BoardTableHeader(),
                        const Divider(height: 1, color: AppColors.border),
                        ...provider.groups.map((g) => BoardGroupWidget(
                              key: ValueKey(g.id),
                              group: g,
                              provider: provider,
                              selectedTaskId: selectedId,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _BoardToolbar extends StatelessWidget {
  final BoardProvider provider;
  final VoidCallback? onAiAssist;
  final VoidCallback? onRecalculate;
  const _BoardToolbar({required this.provider, this.onAiAssist, this.onRecalculate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _ToolbarBtn(icon: Icons.filter_list_rounded,  label: 'Filter'),
          const SizedBox(width: AppSpacing.sm),
          _ToolbarBtn(icon: Icons.group_outlined,        label: 'Group by'),
          const SizedBox(width: AppSpacing.sm),
          _ToolbarBtn(icon: Icons.sort_rounded,          label: 'Sort'),
          const Spacer(),
          // Recalculate Schedule button
          if (onRecalculate != null) ...[
            ListenableBuilder(
              listenable: provider,
              builder: (_, __) {
                final busy = provider.isRecalculating;
                return GestureDetector(
                  onTap: busy ? null : onRecalculate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF16A34A).withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF16A34A),
                            ),
                          )
                        else
                          const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF16A34A)),
                        const SizedBox(width: 5),
                        Text(
                          busy ? 'Recalculating…' : 'Recalculate Schedule',
                          style: AppTextStyles.labelMedium.copyWith(color: const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (onAiAssist != null) ...[
            GestureDetector(
              onTap: onAiAssist,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 5),
                    Text('AI Assist',
                        style: AppTextStyles.labelMedium.copyWith(
                            color: const Color(0xFF7C3AED))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 15, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('Add Group', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ToolbarBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

