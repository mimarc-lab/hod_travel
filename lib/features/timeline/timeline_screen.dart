import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';
import '../trip_board/providers/board_provider.dart';
import 'services/timeline_mapper_service.dart';
import 'widgets/task_bar_widget.dart' show TaskBarWidget, UnscheduledBarPlaceholder, kBarHeight;
import 'widgets/timeline_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TimelineScreen — premium operational planning timeline for one trip
// ─────────────────────────────────────────────────────────────────────────────

class TimelineScreen extends StatefulWidget {
  final Trip trip;
  final BoardProvider provider;

  const TimelineScreen({
    super.key,
    required this.trip,
    required this.provider,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with AutomaticKeepAliveClientMixin {

  // ── Scroll controllers ─────────────────────────────────────────────────────
  final _hHeader    = ScrollController();
  final _hBars      = ScrollController();
  final _hScrollbar = ScrollController();
  final _vLeft      = ScrollController();
  final _vRight     = ScrollController();
  bool _hSyncing = false;
  bool _vSyncing = false;

  // ── UI state ───────────────────────────────────────────────────────────────
  _Filter        _filter          = _Filter.all;
  bool           _grouped         = true;
  _TimelineScale _scale           = _TimelineScale.week;
  final          _collapsedGroups = <String>{};

  @override
  bool get wantKeepAlive => true;

  static const double _leftW = 260.0;

  // ── Init / dispose ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _hHeader.addListener(   () => _syncAllH(_hHeader));
    _hBars.addListener(     () => _syncAllH(_hBars));
    _hScrollbar.addListener(() => _syncAllH(_hScrollbar));
    _vLeft.addListener(_syncVFromLeft);
    _vRight.addListener(_syncVFromRight);
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBars.dispose();
    _hScrollbar.dispose();
    _vLeft.dispose();
    _vRight.dispose();
    super.dispose();
  }

  // ── Scroll sync ────────────────────────────────────────────────────────────
  void _syncAllH(ScrollController source) {
    if (_hSyncing) return;
    _hSyncing = true;
    final offset = source.offset;
    for (final c in [_hHeader, _hBars, _hScrollbar]) {
      if (!identical(c, source) && c.hasClients) c.jumpTo(offset);
    }
    _hSyncing = false;
  }

  void _syncVFromLeft() {
    if (_vSyncing) return;
    _vSyncing = true;
    if (_vRight.hasClients) _vRight.jumpTo(_vLeft.offset);
    _vSyncing = false;
  }

  void _syncVFromRight() {
    if (_vSyncing) return;
    _vSyncing = true;
    if (_vLeft.hasClients) _vLeft.jumpTo(_vRight.offset);
    _vSyncing = false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String? get _currentUserId => null;

  List<({String id, String name, List<Task> tasks})> _toGroups() =>
      widget.provider.groups
          .map((g) => (id: g.id, name: g.name, tasks: g.tasks))
          .toList();

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        if (widget.provider.isLoading && widget.provider.groups.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          );
        }

        final allTasks = widget.provider.groups.expand((g) => g.tasks).toList();
        if (allTasks.isEmpty) return _EmptyTimeline(tripName: widget.trip.name);

        final range = TimelineMapperService.computeDateRange(allTasks, widget.trip);
        final rows  = TimelineMapperService.buildRows(
          groups:           _toGroups(),
          range:            range,
          grouped:          _grouped,
          filterUserId:     _filter == _Filter.mine ? _currentUserId : null,
          overdueOnly:      _filter == _Filter.overdue,
          collapsedGroupIds: _collapsedGroups,
        );

        final bodyH     = TimelineMapperService.totalBodyHeight(rows);
        final rowOffsets = _computeRowOffsets(rows);
        final isMobile  = MediaQuery.sizeOf(context).width < 600;

        return Container(
          color: const Color(0xFFFAF9F7),
          child: Column(
            children: [
              // ── Toolbar ────────────────────────────────────────────────────
              _Toolbar(
                filter:        _filter,
                grouped:       _grouped,
                scale:         _scale,
                isMobile:      isMobile,
                onFilter:      (f) => setState(() => _filter = f),
                onToggleGroup: ()  => setState(() => _grouped = !_grouped),
                onScale:       (s) => setState(() => _scale = s),
              ),

              // ── Mobile: list view ──────────────────────────────────────────
              if (isMobile)
                Expanded(
                  child: _MobileTaskList(
                    rows:     rows,
                    grouped:  _grouped,
                    onToggleCollapse: (id) => setState(() {
                      if (_collapsedGroups.contains(id)) {
                        _collapsedGroups.remove(id);
                      } else {
                        _collapsedGroups.add(id);
                      }
                    }),
                    collapsedGroups: _collapsedGroups,
                    onTaskTap: (t) => widget.provider.selectTask(t),
                  ),
                )

              // ── Desktop: gantt ──────────────────────────────────────────────
              else ...[
                // Date header row
                SizedBox(
                  height: kHeaderHeight,
                  child: Row(
                    children: [
                      _LeftHeaderCell(leftW: _leftW),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _hHeader,
                          physics: const ClampingScrollPhysics(),
                          child: TimelineHeader(range: range),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: AppColors.border),

                // Body
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task navigator panel
                            SizedBox(
                              width: _leftW,
                              child: SingleChildScrollView(
                                controller: _vLeft,
                                physics: const ClampingScrollPhysics(),
                                child: SizedBox(
                                  height: bodyH,
                                  child: _TaskNavigatorPanel(
                                    rows:            rows,
                                    collapsedGroups: _collapsedGroups,
                                    onToggleCollapse: (id) => setState(() {
                                      if (_collapsedGroups.contains(id)) {
                                        _collapsedGroups.remove(id);
                                      } else {
                                        _collapsedGroups.add(id);
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            ),

                            // Divider
                            Container(width: 1, color: AppColors.border),

                            // Bar area
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _vRight,
                                physics: const ClampingScrollPhysics(),
                                child: SizedBox(
                                  height: bodyH,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: _hBars,
                                    physics: const ClampingScrollPhysics(),
                                    child: SizedBox(
                                      width: range.totalWidth,
                                      height: bodyH,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: CustomPaint(
                                              painter: TimelineGridPainter(
                                                range:           range,
                                                totalBodyHeight: bodyH,
                                                rowOffsets:      rowOffsets,
                                              ),
                                            ),
                                          ),
                                          _BarColumn(
                                            rows:     rows,
                                            range:    range,
                                            provider: widget.provider,
                                            onTaskTap: (t) => widget.provider.selectTask(t),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Horizontal scrollbar strip
                      SizedBox(
                        height: 16,
                        child: Row(
                          children: [
                            SizedBox(width: _leftW + 1),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border(
                                    top: BorderSide(
                                        color: AppColors.border, width: 0.5),
                                  ),
                                ),
                                child: RawScrollbar(
                                  controller:          _hScrollbar,
                                  thumbVisibility:     true,
                                  trackVisibility:     true,
                                  interactive:         true,
                                  thickness:           6,
                                  radius:              const Radius.circular(3),
                                  thumbColor:          AppColors.textMuted.withAlpha(120),
                                  trackColor:          AppColors.border.withAlpha(80),
                                  trackBorderColor:    Colors.transparent,
                                  scrollbarOrientation: ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: _hScrollbar,
                                    physics: const ClampingScrollPhysics(),
                                    child: SizedBox(
                                      width: range.totalWidth,
                                      height: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static List<double> _computeRowOffsets(List<TimelineRow> rows) {
    final offsets = <double>[];
    double y = 0;
    for (final row in rows) {
      offsets.add(y);
      y += row.height;
    }
    return offsets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final _Filter        filter;
  final bool           grouped;
  final _TimelineScale scale;
  final bool           isMobile;
  final ValueChanged<_Filter>        onFilter;
  final VoidCallback                 onToggleGroup;
  final ValueChanged<_TimelineScale> onScale;

  const _Toolbar({
    required this.filter,
    required this.grouped,
    required this.scale,
    required this.isMobile,
    required this.onFilter,
    required this.onToggleGroup,
    required this.onScale,
  });

  @override
  Widget build(BuildContext context) {
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: _Filter.values.map((f) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _PlanningChip(
          label:    f.label,
          selected: filter == f,
          onTap:    () => onFilter(f),
        ),
      )).toList(),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: isMobile
          ? SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: chips,
              ),
            )
          : SizedBox(
              height: 48,
              child: Row(
                children: [
                  chips,
                  const Spacer(),
                  // Scale selector (architecture prepared — non-functional visual)
                  _ScaleSelector(
                    scale: scale, onChanged: onScale),
                  const SizedBox(width: AppSpacing.sm),
                  // Group toggle
                  _ToolbarButton(
                    icon:   grouped
                        ? Icons.account_tree_rounded
                        : Icons.format_list_bulleted_rounded,
                    label:  grouped ? 'Grouped' : 'Flat',
                    active: grouped,
                    onTap:  onToggleGroup,
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanningChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _PlanningChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent.withAlpha(140) : AppColors.border,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:      selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize:   11,
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _ToolbarButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? AppColors.accentFaint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent.withAlpha(120) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: active ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                  color:      active ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize:   11,
                )),
          ],
        ),
      ),
    );
  }
}

class _ScaleSelector extends StatelessWidget {
  final _TimelineScale              scale;
  final ValueChanged<_TimelineScale> onChanged;
  const _ScaleSelector({required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TimelineScale>(
      initialValue: scale,
      onSelected:   onChanged,
      tooltip:      'Zoom level',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 36),
      itemBuilder: (_) => _TimelineScale.values.map((s) => PopupMenuItem(
        value: s,
        child: Row(
          children: [
            Icon(s.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(s.label,
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: scale == s ? FontWeight.w600 : FontWeight.w400)),
            if (scale == s) ...[
              const Spacer(),
              const Icon(Icons.check_rounded, size: 13, color: AppColors.accent),
            ],
          ],
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(scale.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(scale.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color:      AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize:   11,
                )),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 13, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left header cell
// ─────────────────────────────────────────────────────────────────────────────

class _LeftHeaderCell extends StatelessWidget {
  final double leftW;
  const _LeftHeaderCell({required this.leftW});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: leftW,
      height: kHeaderHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right:  BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Icon(Icons.route_rounded, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Text(
            'TASK NAVIGATOR',
            style: AppTextStyles.overline.copyWith(
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task navigator panel
// ─────────────────────────────────────────────────────────────────────────────

class _TaskNavigatorPanel extends StatelessWidget {
  final List<TimelineRow>  rows;
  final Set<String>        collapsedGroups;
  final ValueChanged<String> onToggleCollapse;

  const _TaskNavigatorPanel({
    required this.rows,
    required this.collapsedGroups,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((row) {
        if (row is GroupHeaderRow) {
          return _NavGroupHeader(
            row:       row,
            collapsed: collapsedGroups.contains(row.groupId),
            onToggle:  () => onToggleCollapse(row.groupId),
          );
        }
        if (row is TaskRow) return _NavTaskRow(row: row);
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}

class _NavGroupHeader extends StatelessWidget {
  final GroupHeaderRow row;
  final bool           collapsed;
  final VoidCallback   onToggle;

  const _NavGroupHeader({
    required this.row,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _groupAccent(row.groupName);
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: kGroupHeaderHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EFec),
          border: Border(
            left:   BorderSide(color: accent, width: 3),
            bottom: BorderSide(color: AppColors.border.withAlpha(80), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.groupName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize:      10,
                  fontWeight:    FontWeight.w700,
                  color:         accent,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color:        accent.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${row.taskCount}',
                style: GoogleFonts.inter(
                  fontSize:   9,
                  fontWeight: FontWeight.w700,
                  color:      accent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTaskRow extends StatelessWidget {
  final TaskRow row;
  const _NavTaskRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final task      = row.task;
    final isOverdue = TimelineMapperService.isOverdue(task);
    final isCancelled = task.status == TaskStatus.cancelled;
    final isUrgent  = task.priority == TaskPriority.high;

    return Container(
      height: kRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withAlpha(60), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Status indicator dot
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOverdue
                  ? const Color(0xFFEF4444)
                  : _statusDot(task.status),
            ),
          ),

          // Task name
          Expanded(
            child: Text(
              task.name,
              style: GoogleFonts.inter(
                fontSize:   12,
                fontWeight: FontWeight.w500,
                color:      isOverdue
                    ? const Color(0xFFDC2626)
                    : isCancelled
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          // Priority warning
          if (isUrgent && !isCancelled) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                shape: BoxShape.circle,
              ),
            ),
          ],

          // Assignee mini avatar
          if (task.assignedTo != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color:  AppColors.accent.withAlpha(220),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                task.assignedTo!.initials.isNotEmpty
                    ? task.assignedTo!.initials[0]
                    : '?',
                style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar column
// ─────────────────────────────────────────────────────────────────────────────

class _BarColumn extends StatelessWidget {
  final List<TimelineRow> rows;
  final TimelineDateRange range;
  final BoardProvider     provider;
  final void Function(Task) onTaskTap;

  const _BarColumn({
    required this.rows,
    required this.range,
    required this.provider,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    double y = 0;
    final widgets = <Widget>[];

    for (final row in rows) {
      if (row is GroupHeaderRow) {
        widgets.add(Positioned(
          left: 0, top: y, right: 0,
          height: kGroupHeaderHeight,
          child: Container(color: const Color(0xFFF0EFec)),
        ));
      } else if (row is TaskRow) {
        final bar = row.bar;
        if (bar != null) {
          widgets.add(Positioned(
            left:   bar.left,
            top:    y + (kRowHeight - kBarHeight) / 2,
            width:  bar.width,
            height: kBarHeight,
            child: TaskBarWidget(
              task:     row.task,
              bar:      bar,
              range:    range,
              onTap:    () => onTaskTap(row.task),
              onDragEnd: (daysDelta) => _onDragEnd(row.task, daysDelta),
            ),
          ));
        } else {
          widgets.add(Positioned(
            left: 0, top: y, right: 0,
            height: kRowHeight,
            child: UnscheduledBarPlaceholder(
              task:  row.task,
              onTap: () => onTaskTap(row.task),
            ),
          ));
        }
      }
      y += row.height;
    }

    return Stack(children: widgets);
  }

  void _onDragEnd(Task task, int daysDelta) {
    final updated = task.copyWith(
      dueDate:         task.dueDate?.add(Duration(days: daysDelta)),
      clearDueDate:    task.dueDate == null,
      travelDate:      task.travelDate?.add(Duration(days: daysDelta)),
      clearTravelDate: task.travelDate == null,
    );
    provider.updateTask(updated);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile task list
// ─────────────────────────────────────────────────────────────────────────────

class _MobileTaskList extends StatelessWidget {
  final List<TimelineRow>    rows;
  final bool                 grouped;
  final Set<String>          collapsedGroups;
  final ValueChanged<String> onToggleCollapse;
  final ValueChanged<Task>   onTaskTap;

  const _MobileTaskList({
    required this.rows,
    required this.grouped,
    required this.collapsedGroups,
    required this.onToggleCollapse,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        if (row is GroupHeaderRow) {
          return _MobileGroupHeader(
            row:       row,
            collapsed: collapsedGroups.contains(row.groupId),
            onToggle:  () => onToggleCollapse(row.groupId),
          );
        }
        if (row is TaskRow) {
          return _MobileTaskCard(row: row, onTap: () => onTaskTap(row.task));
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _MobileGroupHeader extends StatelessWidget {
  final GroupHeaderRow row;
  final bool           collapsed;
  final VoidCallback   onToggle;
  const _MobileGroupHeader({required this.row, required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final accent = _groupAccent(row.groupName);
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:        accent.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: accent.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              width: 4, height: 14,
              decoration: BoxDecoration(
                color:        accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.groupName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: accent, letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withAlpha(20), borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${row.taskCount}',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700, color: accent)),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTaskCard extends StatelessWidget {
  final TaskRow      row;
  final VoidCallback onTap;
  const _MobileTaskCard({required this.row, required this.onTap});

  static final _dateFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final task      = row.task;
    final isOverdue = TimelineMapperService.isOverdue(task);
    final barColor  = _barBgColor(task.status);
    final dotColor  = isOverdue ? const Color(0xFFEF4444) : _statusDot(task.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.border.withAlpha(120)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status color strip
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12), bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.name,
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isOverdue
                                    ? const Color(0xFFDC2626)
                                    : AppColors.textPrimary,
                                decoration: task.status == TaskStatus.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:        barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.status.label,
                              style: AppTextStyles.labelSmall.copyWith(
                                color:    _barTextColor(task.status),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Date row
                      Row(
                        children: [
                          if (task.travelDate != null) ...[
                            Icon(Icons.flight_takeoff_rounded,
                                size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text(_dateFmt.format(task.travelDate!),
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary, fontSize: 11)),
                            const SizedBox(width: 10),
                          ],
                          if (task.dueDate != null) ...[
                            Icon(
                              Icons.flag_rounded,
                              size: 11,
                              color: isOverdue
                                  ? const Color(0xFFEF4444)
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _dateFmt.format(task.dueDate!),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isOverdue
                                    ? const Color(0xFFEF4444)
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (task.travelDate == null && task.dueDate == null)
                            Text('No dates set',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textMuted, fontSize: 11)),
                          const Spacer(),
                          if (task.assignedTo != null)
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(200),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                task.assignedTo!.initials.isNotEmpty
                                    ? task.assignedTo!.initials[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  final String tripName;
  const _EmptyTimeline({required this.tripName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color:        AppColors.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timeline_rounded, color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No tasks yet', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            'Add tasks on the Board tab to see them here.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _Filter {
  all, mine, overdue;

  String get label => switch (this) {
    _Filter.all     => 'All Tasks',
    _Filter.mine    => 'Assigned to Me',
    _Filter.overdue => 'Overdue',
  };
}

enum _TimelineScale {
  day, week, month;

  String get label => switch (this) {
    _TimelineScale.day   => 'Day',
    _TimelineScale.week  => 'Week',
    _TimelineScale.month => 'Month',
  };

  IconData get icon => switch (this) {
    _TimelineScale.day   => Icons.today_rounded,
    _TimelineScale.week  => Icons.date_range_rounded,
    _TimelineScale.month => Icons.calendar_month_rounded,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _statusDot(TaskStatus s) => switch (s) {
  TaskStatus.notStarted     => const Color(0xFFD1D5DB),
  TaskStatus.researching    => const Color(0xFF60A5FA),
  TaskStatus.awaitingReply  => const Color(0xFFFCD34D),
  TaskStatus.readyForReview => const Color(0xFFA78BFA),
  TaskStatus.approved       => const Color(0xFF34D399),
  TaskStatus.sentToClient   => const Color(0xFFFBBF24),
  TaskStatus.confirmed      => const Color(0xFF34D399),
  TaskStatus.cancelled      => const Color(0xFFE5E7EB),
};

Color _barBgColor(TaskStatus s) => switch (s) {
  TaskStatus.notStarted     => const Color(0xFFEAE9E6),
  TaskStatus.researching    => const Color(0xFFDCEBFD),
  TaskStatus.awaitingReply  => const Color(0xFFFEF0C7),
  TaskStatus.readyForReview => const Color(0xFFEDE9FE),
  TaskStatus.approved       => const Color(0xFFD2F5E4),
  TaskStatus.sentToClient   => const Color(0xFFFEF0C7),
  TaskStatus.confirmed      => const Color(0xFFD2F5E4),
  TaskStatus.cancelled      => const Color(0xFFF1F0EE),
};

Color _barTextColor(TaskStatus s) => switch (s) {
  TaskStatus.notStarted     => const Color(0xFF6B7280),
  TaskStatus.researching    => const Color(0xFF1E40AF),
  TaskStatus.awaitingReply  => const Color(0xFF92400E),
  TaskStatus.readyForReview => const Color(0xFF5B21B6),
  TaskStatus.approved       => const Color(0xFF065F46),
  TaskStatus.sentToClient   => const Color(0xFFB45309),
  TaskStatus.confirmed      => const Color(0xFF065F46),
  TaskStatus.cancelled      => const Color(0xFF9CA3AF),
};

Color _groupAccent(String groupName) {
  final lower = groupName.toLowerCase();
  if (lower.contains('pre') || lower.contains('plan')) return const Color(0xFF6366F1);
  if (lower.contains('accom'))                          return const Color(0xFF7C3AED);
  if (lower.contains('exp'))                            return const Color(0xFF0891B2);
  if (lower.contains('logis'))                          return const Color(0xFF0369A1);
  if (lower.contains('financ'))                         return const Color(0xFF059669);
  if (lower.contains('client') || lower.contains('delivery')) return const Color(0xFFC9A96E);
  return AppColors.textSecondary;
}
