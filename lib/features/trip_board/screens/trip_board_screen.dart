import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_model.dart';
import '../../../features/budget/screens/trip_budget_screen.dart';
import '../../../features/client_view/client_itinerary_screen.dart';
import '../../../features/documents/screens/trip_documents_screen.dart';
import '../../../features/itinerary/screens/itinerary_screen.dart';
import '../../../features/run_sheet/run_sheet_screen.dart';
import '../../../features/timeline/timeline_screen.dart';
import '../../../features/map_view/trip_map_screen.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../core/supabase/app_db.dart';
import '../providers/board_provider.dart';
import '../../../features/intelligence/widgets/trip_intelligence_panel.dart';
import '../../../features/budget/providers/budget_provider.dart';
import '../../../features/itinerary/providers/itinerary_provider.dart';
import '../../../features/trip_components/screens/trip_components_screen.dart';
import '../../../features/health/screens/trip_health_screen.dart';
import '../../../features/trips/providers/trip_provider.dart';
import '../../../features/trips/screens/edit_trip_screen.dart';
import '../widgets/board_group.dart';
import '../widgets/planning_timeline_banner.dart';
import '../widgets/task_detail/task_detail_panel.dart';
import '../widgets/task_row.dart' show BoardTableHeader, boardLayoutFor, BoardLayout;

class TripBoardScreen extends StatefulWidget {
  final Trip trip;

  /// When set, the board auto-selects this task after loading (used by Task Center).
  final String? initialTaskId;

  /// When provided, delete is routed through this provider so the trips list
  /// updates immediately without requiring a manual refresh.
  final TripProvider? tripProvider;

  const TripBoardScreen({
    super.key,
    required this.trip,
    this.initialTaskId,
    this.tripProvider,
  });

  @override
  State<TripBoardScreen> createState() => _TripBoardScreenState();
}

class _TripBoardScreenState extends State<TripBoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final BoardProvider _provider;
  late final ItineraryProvider _itineraryProvider;
  late final BudgetProvider _budgetProvider;

  /// Mutable local copy of the trip — updated when the user saves edits.
  late Trip _currentTrip;

  static const _clientViewIndex = 8;
  bool _isClientView = false;

  static const _tabs = [
    'Board',
    'Timeline',
    'Map',
    'Itinerary',
    'Components',
    'Budget',
    'Documents',
    'Intelligence',
    'Client View',
    'Health',
  ];

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
    _tabController.addListener(() {
      final onClient = _tabController.index == _clientViewIndex;
      if (onClient != _isClientView) {
        setState(() => _isClientView = onClient);
      }
    });
    _provider = BoardProvider(
      widget.trip,
      repository: AppRepositories.instance?.tasks,
      subtaskRepository: AppRepositories.instance?.subtasks,
      teamId: AppRepositories.instance?.currentTeamId,
      currentUserId: AppRepositories.instance?.currentUserId,
      initialTaskId: widget.initialTaskId,
    );
    _itineraryProvider = ItineraryProvider(
      widget.trip,
      repository: AppRepositories.instance?.itinerary,
      teamId: AppRepositories.instance?.currentTeamId,
    );
    _budgetProvider = BudgetProvider.forTrip(
      widget.trip.id,
      repository: AppRepositories.instance?.budget,
      teamId: AppRepositories.instance?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _provider.dispose();
    _itineraryProvider.dispose();
    _budgetProvider.dispose();
    super.dispose();
  }

  Future<void> _openEditTrip(BuildContext context) async {
    final updated = await Navigator.of(context).push<Trip>(
      MaterialPageRoute(
        builder: (_) => EditTripScreen(
          trip: _currentTrip,
          tripProvider: widget.tripProvider,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentTrip = updated);
    }
  }

  void _openRunSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RunSheetScreen(trip: widget.trip)),
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
        const SnackBar(
          content: Text('Could not delete trip. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (!_isClientView)
            _TripHeader(
              trip: _currentTrip,
              provider: _provider,
              onBack: () => Navigator.of(context).pop(),
              onEdit: () => _openEditTrip(context),
              onDelete: () => _deleteTrip(context),
              onRunSheet: () => _openRunSheet(context),
            ),
          _NavBar(controller: _tabController, tabs: _tabs),
          if (!_isClientView && !Responsive.isMobile(context))
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
                      _BoardTab(provider: _provider),
                      TimelineScreen(
                        trip: widget.trip,
                        provider: _provider,
                      ), // Timeline
                      TripMapScreen(
                        trip: widget.trip,
                        provider: _itineraryProvider,
                      ), // Map
                      ItineraryScreen(
                        trip: widget.trip,
                        provider: _itineraryProvider,
                      ),
                      TripComponentsScreen(
                        trip: widget.trip,
                        itineraryProvider: _itineraryProvider,
                        budgetProvider:    _budgetProvider,
                      ),
                      TripBudgetScreen(
                        trip: widget.trip,
                        budgetProvider: _budgetProvider,
                      ),
                      TripDocumentsScreen(trip: widget.trip),
                      TripIntelligencePanel(
                        trip: widget.trip,
                        boardProvider: _provider,
                        itineraryProvider: _itineraryProvider,
                      ),
                      ClientItineraryScreen(trip: widget.trip),
                      TripHealthScreen(trip: widget.trip),
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

class _TripHeader extends StatefulWidget {
  final Trip trip;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRunSheet;
  final BoardProvider provider;

  const _TripHeader({
    required this.trip,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onRunSheet,
    required this.provider,
  });

  @override
  State<_TripHeader> createState() => _TripHeaderState();
}

class _TripHeaderState extends State<_TripHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final trip = widget.trip;

    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yyyy').format(trip.endDate!)}'
        : 'Dates TBD';

    final topRow = Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Trips', style: AppTextStyles.bodySmall),
                Text(' / ', style: AppTextStyles.bodySmall),
                Flexible(
                  child: Text(
                    trip.name,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TripStatusChip(status: trip.status),
        const SizedBox(width: AppSpacing.sm),
        _TripOptionsMenu(
          onEdit: widget.onEdit,
          onRunSheet: widget.onRunSheet,
          onDelete: widget.onDelete,
        ),
      ],
    );

    final metaContent = Wrap(
      spacing: AppSpacing.lg,
      runSpacing: 6,
      children: [
        _MetaItem(icon: Icons.person_outline_rounded, label: trip.clientName),
        _MetaItem(icon: Icons.calendar_today_outlined, label: dateStr),
        _MetaItem(icon: Icons.location_on_outlined, label: trip.destinationSummary),
        _MetaItem(icon: Icons.people_outline_rounded, label: '${trip.guestCount} guests'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(user: trip.tripLead, size: 18),
            const SizedBox(width: 5),
            Text(trip.tripLead.name, style: AppTextStyles.bodySmall),
          ],
        ),
      ],
    );

    if (!isMobile) {
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical: AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topRow,
            const SizedBox(height: AppSpacing.sm),
            metaContent,
          ],
        ),
      );
    }

    // Mobile: collapsible details card
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingH, AppSpacing.base,
              AppSpacing.pagePaddingH, AppSpacing.sm,
            ),
            child: topRow,
          ),

          // Animated details section
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH, 0,
                    AppSpacing.pagePaddingH, AppSpacing.base,
                  ),
                  child: metaContent,
                ),
                PlanningTimelineBanner(trip: trip, provider: widget.provider, compact: true),
              ],
            ),
          ),

          // Expand / collapse toggle strip
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? 'Hide details' : 'Trip details',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(width: 3),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.expand_more_rounded, size: 14, color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extracted popup menu so it can be reused without duplication
class _TripOptionsMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onRunSheet;
  final VoidCallback onDelete;

  const _TripOptionsMenu({
    required this.onEdit,
    required this.onRunSheet,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'run_sheet') onRunSheet();
        if (value == 'delete') onDelete();
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
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 16, color: AppColors.textSecondary),
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

// ── Navigation bar (tab dropdown + contextual actions) ───────────────────────

class _NavBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  const _NavBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isBoardTab = controller.index == 0;
        return Container(
          color: AppColors.surface,
          child: Column(
            children: [
              const Divider(height: 1, color: AppColors.divider),
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: controller,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600),
                      unselectedLabelStyle: AppTextStyles.bodySmall,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.accent,
                      indicatorWeight: 2,
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pagePaddingH),
                      tabs: tabs.map((t) => Tab(text: t, height: 42)).toList(),
                    ),
                  ),
                  if (isBoardTab) ...[
                    _PrimaryBtn(
                      bgColor: AppColors.accentFaint,
                      borderColor: AppColors.accent,
                      iconColor: AppColors.accent,
                      textColor: AppColors.accent,
                      icon: Icons.add,
                      label: 'Add Group',
                    ),
                    const SizedBox(width: AppSpacing.pagePaddingH),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Board tab ─────────────────────────────────────────────────────────────────

class _BoardTab extends StatelessWidget {
  final BoardProvider provider;
  const _BoardTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder wraps everything so header + rows share the same layout tier.
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = boardLayoutFor(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sticky header — sits above the scroll area, never scrolls away.
            // Mirrors BudgetColumnHeader placement in TripBudgetScreen.
            BoardTableHeader(layout: layout),
            if (layout != BoardLayout.mobile)
              const Divider(height: 1, color: AppColors.border),

            // ── Scrollable content
            Expanded(
              child: ListenableBuilder(
                listenable: provider,
                builder: (context, _) {
                  final selectedId = provider.selectedTask?.id;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (layout == BoardLayout.mobile)
                          const SizedBox(height: 8),
                        ...provider.groups.map(
                          (g) => BoardGroupWidget(
                            key:            ValueKey(g.id),
                            group:          g,
                            provider:       provider,
                            layout:         layout,
                            selectedTaskId: selectedId,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.massive),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}




class _PrimaryBtn extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData? icon;
  final String label;

  const _PrimaryBtn({
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor.withAlpha(70), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
