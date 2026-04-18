import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/task_model.dart';
import '../../../features/trip_board/screens/trip_board_screen.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../providers/task_center_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskCenterScreen — global task view, replaces the Tasks placeholder tab.
// ─────────────────────────────────────────────────────────────────────────────

class TaskCenterScreen extends StatefulWidget {
  const TaskCenterScreen({super.key});

  @override
  State<TaskCenterScreen> createState() => _TaskCenterScreenState();
}

class _TaskCenterScreenState extends State<TaskCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TaskCenterProvider _provider;
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();

  static const _tabLabels = ['My Tasks', 'Overdue', 'By Trip', 'By Status'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    final repos = AppRepositories.instance;
    _provider = TaskCenterProvider(
      taskRepo:      repos?.tasks,
      tripRepo:      repos?.trips,
      teamId:        repos?.currentTeamId ?? '',
      currentUserId: repos?.currentUserId,
    );
    _searchCtrl.addListener(() => _provider.setSearch(_searchCtrl.text));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _openTask(Task task) {
    final trip = _provider.tripsById[task.tripId];
    if (trip == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripBoardScreen(trip: trip, initialTaskId: task.id),
      ),
    );
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
        title: 'Tasks',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) => Column(
          children: [
            _SearchFilterBar(
              provider: _provider,
              searchCtrl: _searchCtrl,
              hPad: hPad,
            ),
            _TaskTabBar(
              controller: _tabController,
              overdueCount: _provider.overdueTasks.length,
            ),
            Expanded(
              child: _provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MyTasksView(provider: _provider, hPad: hPad, onTap: _openTask),
                        _OverdueView(provider: _provider, hPad: hPad, onTap: _openTask),
                        _ByTripView(provider: _provider, hPad: hPad, onTap: _openTask),
                        _ByStatusView(provider: _provider, hPad: hPad, onTap: _openTask),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchFilterBar extends StatelessWidget {
  final TaskCenterProvider provider;
  final TextEditingController searchCtrl;
  final double hPad;

  const _SearchFilterBar({
    required this.provider,
    required this.searchCtrl,
    required this.hPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.sm, hPad, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: searchCtrl,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search tasks or trips…',
              hintStyle: AppTextStyles.bodySmall,
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.textMuted),
              suffixIcon: provider.search.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        searchCtrl.clear();
                        provider.setSearch('');
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textMuted),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status filter
                PopupMenuButton<TaskStatus?>(
                  tooltip: 'Filter by status',
                  onSelected: provider.setFilterStatus,
                  itemBuilder: (_) => [
                    const PopupMenuItem<TaskStatus?>(
                        value: null, child: Text('All statuses')),
                    ...TaskStatus.values.map((s) => PopupMenuItem<TaskStatus?>(
                          value: s,
                          child: Text(s.label,
                              style: AppTextStyles.bodySmall),
                        )),
                  ],
                  child: _FilterChip(
                    label: provider.filterStatus?.label ?? 'Status',
                    active: provider.filterStatus != null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Priority filter
                PopupMenuButton<TaskPriority?>(
                  tooltip: 'Filter by priority',
                  onSelected: provider.setFilterPriority,
                  itemBuilder: (_) => [
                    const PopupMenuItem<TaskPriority?>(
                        value: null, child: Text('All priorities')),
                    ...TaskPriority.values.map((p) =>
                        PopupMenuItem<TaskPriority?>(
                          value: p,
                          child: Text(p.label,
                              style: AppTextStyles.bodySmall),
                        )),
                  ],
                  child: _FilterChip(
                    label: provider.filterPriority?.label ?? 'Priority',
                    active: provider.filterPriority != null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Trip filter
                PopupMenuButton<String?>(
                  tooltip: 'Filter by trip',
                  onSelected: provider.setFilterTripId,
                  itemBuilder: (_) => [
                    const PopupMenuItem<String?>(
                        value: null, child: Text('All trips')),
                    ...provider.allTrips.map((t) => PopupMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name,
                              style: AppTextStyles.bodySmall),
                        )),
                  ],
                  child: _FilterChip(
                    label: provider.filterTripId != null
                        ? (provider.tripsById[provider.filterTripId]?.name ??
                            'Trip')
                        : 'Trip',
                    active: provider.filterTripId != null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),

                // Due date filter
                PopupMenuButton<DueDateFilter?>(
                  tooltip: 'Filter by due date',
                  onSelected: provider.setFilterDueDate,
                  itemBuilder: (_) => [
                    const PopupMenuItem<DueDateFilter?>(
                        value: null, child: Text('Any due date')),
                    ...DueDateFilter.values.map((f) =>
                        PopupMenuItem<DueDateFilter?>(
                          value: f,
                          child: Text(f.label,
                              style: AppTextStyles.bodySmall),
                        )),
                  ],
                  child: _FilterChip(
                    label: provider.filterDueDate?.label ?? 'Due Date',
                    active: provider.filterDueDate != null,
                  ),
                ),

                if (provider.hasActiveFilters) ...[
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: provider.clearFilters,
                    child: Text(
                      'Clear',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  const _FilterChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: active ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: 14,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar (with overdue count badge)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskTabBar extends StatelessWidget {
  final TabController controller;
  final int overdueCount;
  const _TaskTabBar({required this.controller, required this.overdueCount});

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
            labelStyle: AppTextStyles.bodySmall
                .copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.bodySmall,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH),
            tabs: [
              const Tab(text: 'My Tasks', height: 42),
              Tab(
                height: 42,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Overdue'),
                    if (overdueCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$overdueCount',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'By Trip', height: 42),
              const Tab(text: 'By Status', height: 42),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Tasks view — tasks assigned to current user
// ─────────────────────────────────────────────────────────────────────────────

class _MyTasksView extends StatelessWidget {
  final TaskCenterProvider provider;
  final double hPad;
  final void Function(Task) onTap;
  const _MyTasksView(
      {required this.provider, required this.hPad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tasks = provider.myTasks;
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_rounded,
        title: 'No tasks assigned to you',
        subtitle: 'Tasks assigned to you across all trips will appear here.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, i) => _TaskRow(
        task: tasks[i],
        tripName: provider.tripsById[tasks[i].tripId]?.name,
        onTap: () => onTap(tasks[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue view — all overdue tasks, grouped by trip
// ─────────────────────────────────────────────────────────────────────────────

class _OverdueView extends StatelessWidget {
  final TaskCenterProvider provider;
  final double hPad;
  final void Function(Task) onTap;
  const _OverdueView(
      {required this.provider, required this.hPad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tasks = provider.overdueTasks;
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No overdue tasks',
        subtitle: 'All tasks are on schedule.',
      );
    }

    // Group by trip
    final grouped = <String, List<Task>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.tripId ?? '__no_trip__', () => []).add(t);
    }

    final items = <Widget>[];
    grouped.forEach((tripId, tripTasks) {
      final tripName =
          provider.tripsById[tripId]?.name ?? 'Unknown Trip';
      items.add(_SectionHeader(label: tripName, count: tripTasks.length));
      items.addAll(tripTasks.map((t) => _TaskRow(
            task: t,
            tripName: tripName,
            showTrip: false,
            onTap: () => onTap(t),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// By Trip view — all tasks grouped by trip name
// ─────────────────────────────────────────────────────────────────────────────

class _ByTripView extends StatelessWidget {
  final TaskCenterProvider provider;
  final double hPad;
  final void Function(Task) onTap;
  const _ByTripView(
      {required this.provider, required this.hPad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final grouped = provider.tasksByTrip;
    if (grouped.isEmpty) {
      return const EmptyState(
        icon: Icons.flight_takeoff_rounded,
        title: 'No tasks found',
        subtitle: 'Adjust your filters or create tasks in a trip.',
      );
    }

    final items = <Widget>[];
    grouped.forEach((tripId, tasks) {
      final tripName =
          provider.tripsById[tripId]?.name ?? 'Unassigned';
      items.add(_SectionHeader(label: tripName, count: tasks.length));
      items.addAll(tasks.map((t) => _TaskRow(
            task: t,
            tripName: tripName,
            showTrip: false,
            onTap: () => onTap(t),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// By Status view — tasks grouped by status in workflow order
// ─────────────────────────────────────────────────────────────────────────────

class _ByStatusView extends StatelessWidget {
  final TaskCenterProvider provider;
  final double hPad;
  final void Function(Task) onTap;
  const _ByStatusView(
      {required this.provider, required this.hPad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final grouped = provider.tasksByStatus;
    if (grouped.isEmpty) {
      return const EmptyState(
        icon: Icons.tune_rounded,
        title: 'No tasks found',
        subtitle: 'Adjust your filters to see tasks.',
      );
    }

    final items = <Widget>[];
    grouped.forEach((status, tasks) {
      items.add(_SectionHeader(
        label: status.label,
        count: tasks.length,
        dotColor: _statusColor(status),
      ));
      items.addAll(tasks.map((t) => _TaskRow(
            task: t,
            tripName: provider.tripsById[t.tripId]?.name,
            onTap: () => onTap(t),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: items,
    );
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.notStarted:    return AppColors.statusNotStartedText;
      case TaskStatus.researching:   return AppColors.statusInProgressText;
      case TaskStatus.awaitingReply: return AppColors.statusWaitingText;
      case TaskStatus.readyForReview:return AppColors.statusInProgressText;
      case TaskStatus.approved:      return AppColors.statusDoneText;
      case TaskStatus.sentToClient:  return AppColors.statusInProgressText;
      case TaskStatus.confirmed:     return AppColors.statusDoneText;
      case TaskStatus.cancelled:     return AppColors.statusBlockedText;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader — group label with count badge
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color? dotColor;
  const _SectionHeader(
      {required this.label, required this.count, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          bottom: AppSpacing.xs, top: AppSpacing.xs),
      child: Row(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('$count',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TaskRow — 2-line task list item
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Task task;
  final String? tripName;
  final bool showTrip;
  final VoidCallback onTap;

  const _TaskRow({
    required this.task,
    required this.onTap,
    this.tripName,
    this.showTrip = true,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !_isTerminal(task.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 2, right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: _statusColor(task.status),
                shape: BoxShape.circle,
              ),
            ),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _MetaLine(
                    tripName: showTrip ? tripName : null,
                    dueDate: task.dueDate,
                    isOverdue: isOverdue,
                    priority: task.priority,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Assignee avatar
            if (task.assignedTo != null)
              UserAvatar(user: task.assignedTo!, size: 22),

            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  bool _isTerminal(TaskStatus s) =>
      s == TaskStatus.confirmed || s == TaskStatus.cancelled;

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.notStarted:    return AppColors.statusNotStartedText;
      case TaskStatus.researching:   return AppColors.statusInProgressText;
      case TaskStatus.awaitingReply: return AppColors.statusWaitingText;
      case TaskStatus.readyForReview:return AppColors.statusInProgressText;
      case TaskStatus.approved:      return AppColors.statusDoneText;
      case TaskStatus.sentToClient:  return AppColors.statusInProgressText;
      case TaskStatus.confirmed:     return AppColors.statusDoneText;
      case TaskStatus.cancelled:     return AppColors.statusBlockedText;
    }
  }
}

class _MetaLine extends StatelessWidget {
  final String? tripName;
  final DateTime? dueDate;
  final bool isOverdue;
  final TaskPriority priority;

  const _MetaLine({
    this.tripName,
    this.dueDate,
    required this.isOverdue,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (tripName != null && tripName!.isNotEmpty) parts.add(tripName!);
    if (dueDate != null) {
      final formatted = DateFormat('d MMM').format(dueDate!);
      parts.add(isOverdue ? 'Due $formatted' : 'Due $formatted');
    }

    return Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join(' · '),
            style: AppTextStyles.labelSmall.copyWith(
              color: isOverdue && dueDate != null
                  ? AppColors.statusBlockedText
                  : AppColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        _PriorityDot(priority: priority),
      ],
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _color(priority).withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: _color(priority),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _color(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:   return const Color(0xFFEF4444);
      case TaskPriority.medium: return const Color(0xFFF59E0B);
      case TaskPriority.low:    return AppColors.textMuted;
    }
  }
}
