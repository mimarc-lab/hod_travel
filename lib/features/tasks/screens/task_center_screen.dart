import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

// ── Shared helpers (file-private) ─────────────────────────────────────────────

const _kCardRadius = 16.0;

bool _isTerminal(TaskStatus s) =>
    s == TaskStatus.confirmed || s == TaskStatus.cancelled;

bool _isOverdue(Task t) =>
    t.dueDate != null &&
    t.dueDate!.isBefore(DateTime.now()) &&
    !_isTerminal(t.status);

/// 4px accent bar colour — drives at-a-glance status scanning.
Color _accentColor(TaskStatus status, bool isOverdue) {
  if (isOverdue) return const Color(0xFFEF4444);
  switch (status) {
    case TaskStatus.notStarted:     return const Color(0xFFD1D5DB);
    case TaskStatus.researching:    return const Color(0xFF3B82F6);
    case TaskStatus.awaitingReply:  return const Color(0xFFF59E0B);
    case TaskStatus.readyForReview: return const Color(0xFF8B5CF6);
    case TaskStatus.approved:       return const Color(0xFF059669);
    case TaskStatus.sentToClient:   return const Color(0xFFC9A96E);
    case TaskStatus.confirmed:      return const Color(0xFF10B981);
    case TaskStatus.cancelled:      return const Color(0xFF9CA3AF);
  }
}

/// Human-readable operational state — more meaningful than raw status labels.
String _operationalLabel(TaskStatus status, bool isOverdue) {
  if (isOverdue) return 'Overdue';
  switch (status) {
    case TaskStatus.notStarted:     return 'Not started';
    case TaskStatus.researching:    return 'In research';
    case TaskStatus.awaitingReply:  return 'Waiting on supplier';
    case TaskStatus.readyForReview: return 'Ready for review';
    case TaskStatus.approved:       return 'Approved';
    case TaskStatus.sentToClient:   return 'Sent to client';
    case TaskStatus.confirmed:      return 'Confirmed';
    case TaskStatus.cancelled:      return 'Cancelled';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaskCenterScreen
// Future architecture: add Kanban / Timeline / Calendar tabs here by extending
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
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar — 48px, radius 14, white fill
          TextField(
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
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 12),
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
          const SizedBox(height: 10),
          // Filter chips — horizontal scroll, PopupMenuButton wrappers intact
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
                const SizedBox(width: 8),

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
                const SizedBox(width: 8),

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
                const SizedBox(width: 8),

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
                  const SizedBox(width: 12),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AppColors.accentFaint : AppColors.surface,
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
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppColors.accentDark : AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: 13,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar with overdue badge
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
          // Subtle bottom shadow separating header from content
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
          // Header
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
          // Task rows
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
    final overdue = _isOverdue(task);
    final dueText = overdue ? 'Overdue' : 'Due Today';
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
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1);
    final focusTasks = tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.isBefore(tomorrowStart) &&
            !_isTerminal(t.status))
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
        ...tasks.asMap().entries.map((e) => Padding(
              padding:
                  EdgeInsets.only(bottom: e.key < tasks.length - 1 ? 12 : 0),
              child: _TaskCard(
                task: e.value,
                tripName: provider.tripsById[e.value.tripId]?.name,
                onTap: () => onTap(e.value),
              ),
            )),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue view — grouped by trip
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

    final items = <Widget>[];
    grouped.forEach((tripId, tripTasks) {
      final tripName =
          provider.tripsById[tripId]?.name ?? 'Unknown Trip';
      items.add(_SectionHeader(label: tripName, count: tripTasks.length));
      items.addAll(tripTasks.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              task: t,
              tripName: tripName,
              showTrip: false,
              onTap: () => onTap(t),
            ),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        ...items,
        const SizedBox(height: AppSpacing.massive),
      ],
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
      items.addAll(tasks.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              task: t,
              tripName: tripName,
              showTrip: false,
              onTap: () => onTap(t),
            ),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        ...items,
        const SizedBox(height: AppSpacing.massive),
      ],
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
        dotColor: _accentColor(status, false),
      ));
      items.addAll(tasks.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              task: t,
              tripName: provider.tripsById[t.tripId]?.name,
              onTap: () => onTap(t),
            ),
          )));
      items.add(const SizedBox(height: AppSpacing.md));
    });

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      children: [
        ...items,
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header — group label with count badge
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
      padding: const EdgeInsets.only(bottom: 10, top: 8),
      child: Row(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.2,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task card — replaces _TaskRow
// Architecture note: entire card is tappable. Left accent bar visually encodes
// status for instant scanning. Designed to be extensible for swipe gestures
// and inline status editing in future iterations.
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  final String? tripName;
  final bool showTrip;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onTap,
    this.tripName,
    this.showTrip = true,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final overdue = _isOverdue(task);
    final accent = _accentColor(task.status, overdue);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: [
              BoxShadow(
                color: Color(_hovered ? 0x0E000000 : 0x07000000),
                blurRadius: _hovered ? 16 : 8,
                offset: Offset(0, _hovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardRadius),
            child: Stack(
              children: [
                // Main content — defines card height
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(18, 14, 14, 14),
                  child: _CardContent(
                    task: task,
                    tripName: widget.tripName,
                    showTrip: widget.showTrip,
                    isOverdue: overdue,
                  ),
                ),
                // Left accent bar — stretches to full card height via Positioned
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 4,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card content ──────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final Task task;
  final String? tripName;
  final bool showTrip;
  final bool isOverdue;

  const _CardContent({
    required this.task,
    required this.isOverdue,
    this.tripName,
    this.showTrip = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title + assignee avatar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                task.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111111),
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.assignedTo != null) ...[
              const SizedBox(width: 10),
              UserAvatar(user: task.assignedTo!, size: 28),
            ],
          ],
        ),

        // Trip name
        if (showTrip && tripName != null && tripName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            tripName!,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF777777),
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 8),

        // Due date + priority chip row
        Row(
          children: [
            if (task.dueDate != null) ...[
              _DueLabel(dueDate: task.dueDate!, isOverdue: isOverdue),
              const SizedBox(width: 8),
              Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                      color: Color(0xFFD1D5DB), shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            _PriorityPill(priority: task.priority),
          ],
        ),

        const SizedBox(height: 5),

        // Operational state label
        Text(
          _operationalLabel(task.status, isOverdue),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFFABAFBB),
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Due date label ────────────────────────────────────────────────────────────

class _DueLabel extends StatelessWidget {
  final DateTime dueDate;
  final bool isOverdue;

  const _DueLabel({required this.dueDate, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final text = _format(dueDate, isOverdue);
    final isToday = text == 'Due Today';
    final color = isOverdue
        ? const Color(0xFFEF4444)
        : isToday
            ? const Color(0xFFF59E0B)
            : const Color(0xFF9CA3AF);

    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight:
            (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
        color: color,
        height: 1.3,
      ),
    );
  }

  static String _format(DateTime d, bool overdue) {
    if (overdue) return 'Overdue';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Due Today';
    if (diff == 1) return 'Due Tomorrow';
    return DateFormat('d MMM').format(d);
  }
}

// ── Priority pill ─────────────────────────────────────────────────────────────

class _PriorityPill extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityPill({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        priority.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }

  static (Color, Color) _colors(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return (const Color(0xFFF3F4F6), const Color(0xFF9CA3AF));
      case TaskPriority.medium:
        return (const Color(0xFFFDF3DC), const Color(0xFFB45309));
      case TaskPriority.high:
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
    }
  }
}
