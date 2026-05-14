import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/adaptive_control_row.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/task_model.dart';
import '../../../features/trip_board/screens/trip_board_screen.dart';
import '../../../shared/adaptive_table/adaptive_group_header.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/task_center_provider.dart';
import '../widgets/task_row.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskCenterScreen
// Future architecture: add Kanban / Timeline / Calendar tabs by extending
// _tabLabels and adding corresponding views inside TabBarView.
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

  // Navigation unchanged — preserves routing to TripBoardScreen with task focus
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
    final hPad =
        isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

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
            // ── Search + filter toolbar ─────────────────────────────────
            _SearchFilterBar(
              provider: _provider,
              searchCtrl: _searchCtrl,
              hPad: hPad,
            ),
            // ── Tab bar ─────────────────────────────────────────────────
            _TaskTabBar(
              controller: _tabController,
              overdueCount: _provider.overdueTasks.length,
              hPad: hPad,
            ),
            // ── Tab content ─────────────────────────────────────────────
            Expanded(
              child: _provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MyTasksView(
                            provider: _provider,
                            hPad: hPad,
                            onTap: _openTask),
                        _OverdueView(
                            provider: _provider,
                            hPad: hPad,
                            onTap: _openTask),
                        _ByTripView(
                            provider: _provider,
                            hPad: hPad,
                            onTap: _openTask),
                        _ByStatusView(
                            provider: _provider,
                            hPad: hPad,
                            onTap: _openTask),
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
// Search + filter bar (unchanged logic)
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
    final isDesktop = !Responsive.isMobile(context);

    final searchField = TextField(
      controller: searchCtrl,
      style: AppTextStyles.bodyMedium,
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
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );

    final statusChip = PopupMenuButton<TaskStatus?>(
      tooltip: 'Filter by status',
      onSelected: provider.setFilterStatus,
      itemBuilder: (_) => [
        const PopupMenuItem<TaskStatus?>(
            value: null, child: Text('All statuses')),
        ...TaskStatus.values.map((s) => PopupMenuItem<TaskStatus?>(
              value: s,
              child: Text(s.label, style: AppTextStyles.bodySmall),
            )),
      ],
      child: _FilterChip(
        label: provider.filterStatus?.label ?? 'Status',
        active: provider.filterStatus != null,
        fullWidth: true,
      ),
    );

    final priorityChip = PopupMenuButton<TaskPriority?>(
      tooltip: 'Filter by priority',
      onSelected: provider.setFilterPriority,
      itemBuilder: (_) => [
        const PopupMenuItem<TaskPriority?>(
            value: null, child: Text('All priorities')),
        ...TaskPriority.values.map((p) => PopupMenuItem<TaskPriority?>(
              value: p,
              child: Text(p.label, style: AppTextStyles.bodySmall),
            )),
      ],
      child: _FilterChip(
        label: provider.filterPriority?.label ?? 'Priority',
        active: provider.filterPriority != null,
        fullWidth: true,
      ),
    );

    final tripChip = PopupMenuButton<String?>(
      tooltip: 'Filter by trip',
      onSelected: provider.setFilterTripId,
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(value: null, child: Text('All trips')),
        ...provider.allTrips.map((t) => PopupMenuItem<String?>(
              value: t.id,
              child: Text(t.name, style: AppTextStyles.bodySmall),
            )),
      ],
      child: _FilterChip(
        label: provider.filterTripId != null
            ? (provider.tripsById[provider.filterTripId]?.name ?? 'Trip')
            : 'Trip',
        active: provider.filterTripId != null,
        fullWidth: true,
      ),
    );

    final dueDateChip = PopupMenuButton<DueDateFilter?>(
      tooltip: 'Filter by due date',
      onSelected: provider.setFilterDueDate,
      itemBuilder: (_) => [
        const PopupMenuItem<DueDateFilter?>(
            value: null, child: Text('Any due date')),
        ...DueDateFilter.values.map((f) => PopupMenuItem<DueDateFilter?>(
              value: f,
              child: Text(f.label, style: AppTextStyles.bodySmall),
            )),
      ],
      child: _FilterChip(
        label: provider.filterDueDate?.label ?? 'Due Date',
        active: provider.filterDueDate != null,
        fullWidth: true,
      ),
    );

    final clearBtn = provider.hasActiveFilters
        ? GestureDetector(
            onTap: provider.clearFilters,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Clear',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.accent),
              ),
            ),
          )
        : null;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 12),
      child: isDesktop
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desktop Row 1: [══ Search ══][══ Status ══]
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    Expanded(child: statusChip),
                  ],
                ),
                const SizedBox(height: 10),
                // Desktop Row 2: [══ Priority ══][══ Trip ══][══ Due Date ══][Clear?]
                Row(
                  children: [
                    Expanded(child: priorityChip),
                    const SizedBox(width: 8),
                    Expanded(child: tripChip),
                    const SizedBox(width: 8),
                    Expanded(child: dueDateChip),
                    ?clearBtn,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mobile: search full width
                searchField,
                const SizedBox(height: 10),
                // Mobile Row 1: Status + Priority
                AdaptiveControlRow(
                  gap: 8,
                  children: [statusChip, priorityChip],
                ),
                const SizedBox(height: 8),
                // Mobile Row 2: Trip + Due Date + Clear
                Row(
                  children: [
                    Expanded(child: tripChip),
                    const SizedBox(width: 8),
                    Expanded(child: dueDateChip),
                    if (provider.hasActiveFilters) ...[
                      const SizedBox(width: 10),
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
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool fullWidth;
  const _FilterChip({
    required this.label,
    required this.active,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? AppColors.accentFaint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: fullWidth
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.accentDark : AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar with overdue badge (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskTabBar extends StatelessWidget {
  final TabController controller;
  final int overdueCount;
  final double hPad;

  const _TaskTabBar({
    required this.controller,
    required this.overdueCount,
    required this.hPad,
  });

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
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            tabs: [
              const Tab(text: 'My Tasks', height: 44),
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Overdue'),
                    if (overdueCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$overdueCount',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'By Trip', height: 44),
              const Tab(text: 'By Status', height: 44),
            ],
          ),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today Focus section — compact urgency summary at top of My Tasks
// ─────────────────────────────────────────────────────────────────────────────

class _TodayFocusSection extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onTap;

  const _TodayFocusSection({required this.tasks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE8D0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text(
                'Today Focus',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${tasks.length} urgent',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFB45309),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tasks.map((t) => _FocusRow(task: t, onTap: () => onTap(t))),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const _FocusRow({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue  = taskIsOverdue(task);
    final dueText  = overdue ? 'Overdue' : 'Due Today';
    final dueColor = overdue
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: dueColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                task.name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF374151),
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dueText,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: dueColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Tasks view
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

    // Today Focus: overdue OR due today, non-terminal, up to 5
    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
    final focusTasks = tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.isBefore(tomorrowStart) &&
            !taskIsTerminal(t.status))
        .take(5)
        .toList();

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        if (focusTasks.isNotEmpty) ...[
          _TodayFocusSection(tasks: focusTasks, onTap: onTap),
          const SizedBox(height: 16),
        ],
        for (int i = 0; i < tasks.length; i++) ...[
          TaskRow(
            key: ValueKey(tasks[i].id),
            task: tasks[i],
            tripName: provider.tripsById[tasks[i].tripId]?.name,
            onTap: () => onTap(tasks[i]),
          ),
          if (i < tasks.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue view — grouped by trip, collapsible sections
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

    // Group by trip — unchanged logic
    final grouped = <String, List<Task>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.tripId ?? '__no_trip__', () => []).add(t);
    }

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        for (final entry in grouped.entries) ...[
          AdaptiveGroupHeader(
            title: provider.tripsById[entry.key]?.name ?? 'Unknown Trip',
            count: entry.value.length,
            accentColor: const Color(0xFFEF4444),
            children: [
              for (int i = 0; i < entry.value.length; i++) ...[
                TaskRow(
                  key: ValueKey(entry.value[i].id),
                  task: entry.value[i],
                  tripName: provider.tripsById[entry.key]?.name,
                  showTrip: false,
                  onTap: () => onTap(entry.value[i]),
                ),
                if (i < entry.value.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// By Trip view — collapsible group per trip
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

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        for (final entry in grouped.entries) ...[
          AdaptiveGroupHeader(
            title: provider.tripsById[entry.key]?.name ?? 'Unassigned',
            count: entry.value.length,
            children: [
              for (int i = 0; i < entry.value.length; i++) ...[
                TaskRow(
                  key: ValueKey(entry.value[i].id),
                  task: entry.value[i],
                  tripName: provider.tripsById[entry.key]?.name,
                  showTrip: false,
                  onTap: () => onTap(entry.value[i]),
                ),
                if (i < entry.value.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// By Status view — collapsible group per workflow status
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

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        for (final entry in grouped.entries) ...[
          AdaptiveGroupHeader(
            title: entry.key.label,
            count: entry.value.length,
            accentColor: taskAccentColor(entry.key, false),
            children: [
              for (int i = 0; i < entry.value.length; i++) ...[
                TaskRow(
                  key: ValueKey(entry.value[i].id),
                  task: entry.value[i],
                  tripName: provider.tripsById[entry.value[i].tripId]?.name,
                  onTap: () => onTap(entry.value[i]),
                ),
                if (i < entry.value.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}
