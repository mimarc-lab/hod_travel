import 'package:flutter/material.dart';
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
// TimelineScreen — full Gantt / timeline view for one trip
// ─────────────────────────────────────────────────────────────────────────────

/// Replaces the "Timeline" placeholder tab in TripBoardScreen.
/// Reuses the existing [BoardProvider] — no duplicate subscriptions.
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
  // ── Scroll controllers ───────────────────────────────────────────────────

  final _hHeader    = ScrollController(); // date header horizontal
  final _hBars      = ScrollController(); // bars horizontal
  final _hScrollbar = ScrollController(); // bottom scrollbar strip
  final _vLeft      = ScrollController(); // left label column vertical
  final _vRight     = ScrollController(); // bars vertical
  bool _hSyncing = false;
  bool _vSyncing = false;

  // ── Filter / display state ───────────────────────────────────────────────

  _Filter _filter       = _Filter.all;
  bool    _grouped      = true;

  @override
  bool get wantKeepAlive => true;

  // ── Left panel width ─────────────────────────────────────────────────────
  static const double _leftW = 220.0;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _hHeader.addListener(() => _syncAllH(_hHeader));
    _hBars.addListener(() => _syncAllH(_hBars));
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

  // ── Scroll sync ──────────────────────────────────────────────────────────

  /// Keeps all three horizontal controllers (header, bars, scrollbar strip) in
  /// sync. [source] is the one that moved; the others are jumped to match.
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? get _currentUserId =>
      widget.provider.members.isEmpty
          ? null
          : null; // resolved via AppRepositories in provider

  List<({String id, String name, List<Task> tasks})> _toGroups() {
    return widget.provider.groups
        .map((g) => (id: g.id, name: g.name, tasks: g.tasks))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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

        final allTasks = widget.provider.groups
            .expand((g) => g.tasks)
            .toList();

        if (allTasks.isEmpty) {
          return _EmptyTimeline(tripName: widget.trip.name);
        }

        final range = TimelineMapperService.computeDateRange(allTasks, widget.trip);
        final rows  = TimelineMapperService.buildRows(
          groups:       _toGroups(),
          range:        range,
          grouped:      _grouped,
          filterUserId: _filter == _Filter.mine ? _currentUserId : null,
          overdueOnly:  _filter == _Filter.overdue,
        );

        final bodyH = TimelineMapperService.totalBodyHeight(rows);
        final rowOffsets = _computeRowOffsets(rows);

        return Column(
          children: [
            // ── Toolbar ─────────────────────────────────────────────────
            _Toolbar(
              filter:   _filter,
              grouped:  _grouped,
              onFilter: (f) => setState(() => _filter = f),
              onToggleGroup: () => setState(() => _grouped = !_grouped),
            ),

            // ── Date header + left header ────────────────────────────────
            SizedBox(
              height: kHeaderHeight,
              child: Row(
                children: [
                  // Left header cell
                  _LeftHeaderCell(grouped: _grouped),

                  // Scrolling date scale
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

            const Divider(height: 1, color: AppColors.border),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: task labels
                        SizedBox(
                          width: _leftW,
                          child: SingleChildScrollView(
                            controller: _vLeft,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              height: bodyH,
                              child: _LeftColumn(rows: rows),
                            ),
                          ),
                        ),

                        // Vertical divider
                        Container(width: 1, color: AppColors.border),

                        // Right: timeline bars
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
                                      // Grid background
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: TimelineGridPainter(
                                            range:           range,
                                            totalBodyHeight: bodyH,
                                            rowOffsets:      rowOffsets,
                                          ),
                                        ),
                                      ),

                                      // Task bars
                                      _BarColumn(
                                        rows:     rows,
                                        range:    range,
                                        provider: widget.provider,
                                        onTaskTap: (task) =>
                                            widget.provider.selectTask(task),
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

                  // ── Horizontal scrollbar strip ───────────────────────────
                  // Always visible at the bottom, synced with the bars and
                  // date header so dragging it scrolls the whole timeline.
                  // RawScrollbar + interactive:true is required so the thumb
                  // is draggable on desktop/web. The SizedBox content fills
                  // the full strip height so hit-testing always succeeds.
                  SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        // Spacer matching the left label column + divider
                        SizedBox(width: _leftW + 1),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                top: BorderSide(color: AppColors.border, width: 0.5),
                              ),
                            ),
                            child: RawScrollbar(
                              controller: _hScrollbar,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              thickness: 6,
                              radius: const Radius.circular(3),
                              thumbColor: AppColors.textMuted.withAlpha(120),
                              trackColor: AppColors.border.withAlpha(80),
                              trackBorderColor: Colors.transparent,
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _hScrollbar,
                                physics: const ClampingScrollPhysics(),
                                // Content fills the strip height so the entire
                                // 16 px area is hittable for the thumb drag.
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
// _Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final _Filter filter;
  final bool grouped;
  final ValueChanged<_Filter> onFilter;
  final VoidCallback onToggleGroup;

  const _Toolbar({
    required this.filter,
    required this.grouped,
    required this.onFilter,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Filter pills
          ..._Filter.values.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterPill(
                  label:    f.label,
                  selected: filter == f,
                  onTap:    () => onFilter(f),
                ),
              )),

          const Spacer(),

          // Group toggle
          _ToggleButton(
            icon:    Icons.list_alt_rounded,
            label:   grouped ? 'Grouped' : 'Flat',
            active:  grouped,
            onTap:   onToggleGroup,
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel
// ─────────────────────────────────────────────────────────────────────────────

class _LeftHeaderCell extends StatelessWidget {
  final bool grouped;
  const _LeftHeaderCell({required this.grouped});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _TimelineScreenState._leftW,
      height: kHeaderHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: 0),
      alignment: Alignment.centerLeft,
      child: Text('TASKS', style: AppTextStyles.overline.copyWith(letterSpacing: 1.5)),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  final List<TimelineRow> rows;
  const _LeftColumn({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map(_buildRow).toList(),
    );
  }

  Widget _buildRow(TimelineRow row) {
    if (row is GroupHeaderRow) {
      return _LeftGroupHeader(row: row);
    }
    if (row is TaskRow) {
      return _LeftTaskLabel(row: row);
    }
    return const SizedBox.shrink();
  }
}

class _LeftGroupHeader extends StatelessWidget {
  final GroupHeaderRow row;
  const _LeftGroupHeader({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kGroupHeaderHeight,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            row.groupName.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
                color: AppColors.textSecondary, letterSpacing: 1.2),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${row.taskCount}',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftTaskLabel extends StatelessWidget {
  final TaskRow row;
  const _LeftTaskLabel({required this.row});

  @override
  Widget build(BuildContext context) {
    final isOverdue = TimelineMapperService.isOverdue(row.task);
    return Container(
      height: kRowHeight,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOverdue
                  ? const Color(0xFFEF4444)
                  : _statusDot(row.task.status),
            ),
          ),
          Expanded(
            child: Text(
              row.task.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: isOverdue
                    ? const Color(0xFFEF4444)
                    : AppColors.textSecondary,
                fontSize: 12,
                decoration: row.task.status == TaskStatus.cancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
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
  final BoardProvider provider;
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
        // Group header row — no bar, just background
        widgets.add(Positioned(
          left: 0, top: y, right: 0,
          height: kGroupHeaderHeight,
          child: Container(color: AppColors.surfaceAlt.withAlpha(180)),
        ));
      } else if (row is TaskRow) {
        final bar = row.bar;
        if (bar != null) {
          // Position the bar precisely in the Stack so TaskBarWidget can be
          // a plain (non-Positioned) widget — avoids Positioned-inside-Positioned.
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
      dueDate:    task.dueDate?.add(Duration(days: daysDelta)),
      clearDueDate: task.dueDate == null,
      travelDate: task.travelDate?.add(Duration(days: daysDelta)),
      clearTravelDate: task.travelDate == null,
    );
    provider.updateTask(updated);
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.timeline_rounded,
                color: AppColors.accent, size: 24),
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
// Filter enum
// ─────────────────────────────────────────────────────────────────────────────

enum _Filter {
  all,
  mine,
  overdue;

  String get label => switch (this) {
    _Filter.all     => 'All Tasks',
    _Filter.mine    => 'Assigned to Me',
    _Filter.overdue => 'Overdue',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Status dot colors
// ─────────────────────────────────────────────────────────────────────────────

Color _statusDot(TaskStatus s) => switch (s) {
  TaskStatus.notStarted     => const Color(0xFFD1D5DB),
  TaskStatus.researching    => const Color(0xFF93C5FD),
  TaskStatus.awaitingReply  => const Color(0xFFFCD34D),
  TaskStatus.readyForReview => const Color(0xFFC4B5FD),
  TaskStatus.approved       => const Color(0xFF6EE7B7),
  TaskStatus.sentToClient   => const Color(0xFFFCD34D),
  TaskStatus.confirmed      => const Color(0xFF6EE7B7),
  TaskStatus.cancelled      => const Color(0xFFE5E7EB),
};
