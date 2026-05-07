import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/stacked_avatars.dart';
import '../providers/board_provider.dart';
import 'task_detail/task_detail_panel.dart';

// ── Layout tier ───────────────────────────────────────────────────────────────
// Computed from the content area width (LayoutBuilder in _BoardTab).
// Task rows and the header both receive the same tier — guaranteeing alignment.

enum BoardLayout { mobile, tablet, desktop }

BoardLayout boardLayoutFor(double width) {
  if (width < 580) return BoardLayout.mobile;
  if (width < 920) return BoardLayout.tablet;
  return BoardLayout.desktop;
}

// ── Fixed column widths ───────────────────────────────────────────────────────
// Task Name is the only Expanded column — it absorbs all remaining space.
// All other columns are fixed SizedBoxes, identical in header and rows.

abstract class _BC {
  static const double status     = 130.0;
  static const double assigned   = 160.0;
  static const double startDate  = 100.0;
  static const double dueDate    = 100.0;
  static const double supplier   = 140.0;
  static const double priority   =  90.0;
  static const double costStatus = 110.0;
  static const double client     =  72.0;
}

// Shared layout constants — header and rows must use exactly these values.
// _kAccentW + AdaptiveSpacing.rowPaddingH = 19px: where task-name text begins.
// The header spacer uses the same 19px so labels land on the same pixel.
const double _kAccentW  = 3.0;   // left accent bar width
const double _kCellPadH = 10.0;  // horizontal padding inside each fixed cell
const double _kRightPad = 8.0;   // trailing padding on every row
// _kNameLPad intentionally removed — use AdaptiveSpacing.rowPaddingH (16) directly.

// ── Header row ────────────────────────────────────────────────────────────────

class BoardTableHeader extends StatelessWidget {
  final BoardLayout layout;
  const BoardTableHeader({super.key, required this.layout});

  static const TextStyle _style = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF9AA1AE),
    letterSpacing: 0.04,
  );

  static Widget _cell(String label, double width) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kCellPadH),
          child: Text(label, style: _style, overflow: TextOverflow.ellipsis),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (layout == BoardLayout.mobile) return const SizedBox.shrink();

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F3),
        border: Border(
          bottom: BorderSide(color: Color(0xFFECEAE7)),
        ),
      ),
      child: Row(
        children: [
          // Mirrors the accent bar + name-cell left padding on every task row.
          // 3px accent + 16px rowPaddingH = 19px — matches where task-name text starts in rows.
          const SizedBox(width: _kAccentW + AdaptiveSpacing.rowPaddingH),
          // Task Name — Expanded (same as in task rows)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: _kCellPadH),
              child: Text('Task Name', style: _style, overflow: TextOverflow.ellipsis),
            ),
          ),
          _cell('Status',       _BC.status),
          _cell('Assigned To',  _BC.assigned),
          if (layout == BoardLayout.desktop)
            _cell('Start Date', _BC.startDate),
          _cell('Due Date',     _BC.dueDate),
          if (layout == BoardLayout.desktop)
            _cell('Supplier',   _BC.supplier),
          _cell('Priority',     _BC.priority),
          if (layout == BoardLayout.desktop) ...[
            _cell('Cost Status', _BC.costStatus),
            _cell('Client',      _BC.client),
          ],
          const SizedBox(width: _kRightPad),
        ],
      ),
    );
  }
}

// ── Task row ──────────────────────────────────────────────────────────────────

class TaskRow extends StatefulWidget {
  final Task task;
  final BoardProvider provider;
  final BoardLayout layout;
  final bool isSelected;

  const TaskRow({
    super.key,
    required this.task,
    required this.provider,
    required this.layout,
    this.isSelected = false,
  });

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _subtasksExpanded = true;

  void _onTap(BuildContext context) {
    if (widget.layout == BoardLayout.mobile) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          key: ValueKey(widget.task.id),
          task: widget.task,
          provider: widget.provider,
        ),
      ));
    } else {
      widget.provider.selectTask(widget.task);
    }
  }

  Future<void> _onRightClick(BuildContext context, Offset position) async {
    final result = await showMenu<_RowAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        const PopupMenuItem(
          value: _RowAction.delete,
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFF991B1B)),
            SizedBox(width: 10),
            Text('Delete task', style: TextStyle(color: Color(0xFF991B1B))),
          ]),
        ),
      ],
    );
    if (result == _RowAction.delete && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete task?'),
          content: Text(
            '"${widget.task.name}" will be permanently removed.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF991B1B)),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) widget.provider.deleteTask(widget.task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.layout == BoardLayout.mobile) {
      return _MobileTaskCard(
        task: widget.task,
        onTap: () => _onTap(context),
      );
    }

    final task   = widget.task;
    final layout = widget.layout;

    return GestureDetector(
      onSecondaryTapUp: (d) => _onRightClick(context, d.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Main row ───────────────────────────────────────────────────────
          Material(
            color: widget.isSelected ? AppColors.accentFaint : Colors.white,
            child: InkWell(
              onTap: () => _onTap(context),
              hoverColor: widget.isSelected
                  ? AppColors.accentFaint
                  : const Color(0xFFFAF9F7),
              highlightColor: Colors.transparent,
              splashColor:    Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Left accent bar ────────────────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _kAccentW,
                        color: widget.isSelected
                            ? AppColors.accent
                            : Colors.transparent,
                      ),

                      // ── Task Name — Expanded ───────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AdaptiveSpacing.rowPaddingH,
                              AdaptiveSpacing.rowPaddingV,
                              _kCellPadH,
                              AdaptiveSpacing.rowPaddingV),
                          child: _TaskNameCell(
                            task: task,
                            isSelected: widget.isSelected,
                            subtasksExpanded: _subtasksExpanded,
                            onToggleSubtasks: () => setState(
                                () => _subtasksExpanded = !_subtasksExpanded),
                          ),
                        ),
                      ),

                      // ── Status ─────────────────────────────────────────────
                      SizedBox(
                        width: _BC.status,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: _kCellPadH),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TaskStatusChip(status: task.status),
                          ),
                        ),
                      ),

                      // ── Assigned To ────────────────────────────────────────
                      SizedBox(
                        width: _BC.assigned,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: _kCellPadH),
                          child: task.assignments.isEmpty
                              ? _emptyText
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StackedAvatars(
                                      users: task.assignments
                                          .map((a) => a.user)
                                          .toList(),
                                      size: 20,
                                      maxVisible: 3,
                                      overlap: 6,
                                    ),
                                    if (task.assignments.length == 1) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          task.assignments.first.user.name
                                              .split(' ')
                                              .first,
                                          style: AppTextStyles.tableCell,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),

                      // ── Start Date (desktop only) ──────────────────────────
                      if (layout == BoardLayout.desktop)
                        SizedBox(
                          width: _BC.startDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kCellPadH),
                            child: Text(
                              task.travelDate != null
                                  ? DateFormat('d MMM').format(task.travelDate!)
                                  : '—',
                              style: AppTextStyles.tableCell,
                            ),
                          ),
                        ),

                      // ── Due Date ───────────────────────────────────────────
                      SizedBox(
                        width: _BC.dueDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: _kCellPadH),
                          child: _DueDateCell(dueDate: task.dueDate),
                        ),
                      ),

                      // ── Supplier (desktop only) ────────────────────────────
                      if (layout == BoardLayout.desktop)
                        SizedBox(
                          width: _BC.supplier,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kCellPadH),
                            child: Text(
                              task.supplierId ?? '—',
                              style: AppTextStyles.tableCell.copyWith(
                                color: task.supplierId != null
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                      // ── Priority ───────────────────────────────────────────
                      SizedBox(
                        width: _BC.priority,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: _kCellPadH),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PriorityChip(priority: task.priority),
                          ),
                        ),
                      ),

                      // ── Cost Status (desktop only) ─────────────────────────
                      if (layout == BoardLayout.desktop)
                        SizedBox(
                          width: _BC.costStatus,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kCellPadH),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: CostStatusChip(status: task.costStatus),
                            ),
                          ),
                        ),

                      // ── Client (desktop only) ──────────────────────────────
                      if (layout == BoardLayout.desktop)
                        SizedBox(
                          width: _BC.client,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kCellPadH),
                            child: Icon(
                              task.clientVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                              size: 15,
                              color: task.clientVisible
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),

                      const SizedBox(width: _kRightPad),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Inline subtask rows ────────────────────────────────────────────
          if (task.hasSubtasks && _subtasksExpanded)
            ListenableBuilder(
              listenable: widget.provider,
              builder: (context, _) {
                final subtasks = widget.provider.subtasksFor(task.id);
                if (subtasks.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: subtasks
                      .map((s) => _InlineSubtaskRow(
                            key:      ValueKey(s.id),
                            subtask:  s,
                            provider: widget.provider,
                          ))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  static final Widget _emptyText = Text('—',
      style: AppTextStyles.tableCell.copyWith(color: AppColors.textMuted));
}

enum _RowAction { delete }

// ── Task name cell ────────────────────────────────────────────────────────────

class _TaskNameCell extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final bool subtasksExpanded;
  final VoidCallback onToggleSubtasks;

  const _TaskNameCell({
    required this.task,
    required this.isSelected,
    required this.subtasksExpanded,
    required this.onToggleSubtasks,
  });

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppTextStyles.tableCell.copyWith(
      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
    );

    if (!task.hasSubtasks) {
      return Text(task.name, style: nameStyle, overflow: TextOverflow.ellipsis);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleSubtasks,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedRotation(
              turns: subtasksExpanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.expand_more_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(task.name,
                  style: nameStyle, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.subtaskProgress,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(
                          task.subtaskProgress == 1.0
                              ? const Color(0xFF16A34A)
                              : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${task.completedSubtaskCount}/${task.subtaskCount}',
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mobile task card ──────────────────────────────────────────────────────────

class _MobileTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const _MobileTaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate;
    final isOverdue =
        dueDate != null && dueDate.isBefore(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFECEAE7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task name + status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TaskStatusChip(status: task.status),
              ],
            ),

            const SizedBox(height: 10),

            // Assignees + due date + priority
            Row(
              children: [
                if (task.assignments.isNotEmpty) ...[
                  StackedAvatars(
                    users: task.assignments.map((a) => a.user).toList(),
                    size: 18,
                    maxVisible: 3,
                    overlap: 5,
                  ),
                  const SizedBox(width: 8),
                ],
                if (dueDate != null) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 11,
                    color: isOverdue
                        ? AppColors.statusBlockedText
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    DateFormat('d MMM').format(dueDate),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isOverdue
                          ? AppColors.statusBlockedText
                          : AppColors.textSecondary,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                PriorityChip(priority: task.priority),
                const Spacer(),
                CostStatusChip(status: task.costStatus),
              ],
            ),

            // Subtask progress
            if (task.hasSubtasks) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.subtaskProgress,
                        minHeight: 3,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(
                          task.subtaskProgress == 1.0
                              ? const Color(0xFF16A34A)
                              : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${task.completedSubtaskCount}/${task.subtaskCount}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Inline subtask row ────────────────────────────────────────────────────────

class _InlineSubtaskRow extends StatefulWidget {
  final dynamic subtask;
  final BoardProvider provider;
  const _InlineSubtaskRow(
      {super.key, required this.subtask, required this.provider});

  @override
  State<_InlineSubtaskRow> createState() => _InlineSubtaskRowState();
}

class _InlineSubtaskRowState extends State<_InlineSubtaskRow> {
  bool _hovered = false;
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.subtask.title as String);
  }

  @override
  void didUpdateWidget(_InlineSubtaskRow old) {
    super.didUpdateWidget(old);
    if (!_editing && old.subtask.title != widget.subtask.title) {
      _ctrl.text = widget.subtask.title as String;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commitEdit() {
    final text = _ctrl.text.trim();
    if (text.isNotEmpty && text != widget.subtask.title) {
      widget.provider.updateSubtaskTitle(widget.subtask, text);
    } else {
      _ctrl.text = widget.subtask.title as String;
    }
    setState(() => _editing = false);
  }

  void _delete() => widget.provider.deleteSubtask(widget.subtask);

  @override
  Widget build(BuildContext context) {
    final s    = widget.subtask;
    final done = s.isCompleted as bool;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Container(
        height: 32,
        color: _hovered
            ? const Color(0xFFF5F4F1)
            : const Color(0xFFFAF9F7),
        child: Row(
          children: [
            // Aligns with the accent bar on task rows
            const SizedBox(width: _kAccentW),
            Container(
                width: 1, height: 32, color: const Color(0xFFECEAE7)),
            // Indent to sit under the task name text
            const SizedBox(width: AdaptiveSpacing.rowPaddingH + 8),

            // Checkbox
            GestureDetector(
              onTap: () => widget.provider.toggleSubtask(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: done ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: done ? AppColors.accent : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 9, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 8),

            // Title — spans full remaining width
            Expanded(
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: AppTextStyles.tableCell.copyWith(fontSize: 11),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _commitEdit(),
                      onTapOutside: (_) => _commitEdit(),
                    )
                  : GestureDetector(
                      onDoubleTap: () => setState(() => _editing = true),
                      child: Text(
                        s.title as String,
                        style: AppTextStyles.tableCell.copyWith(
                          fontSize: 11,
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),

            // Hover actions
            if (_hovered || _editing) ...[
              _ActionIcon(
                icon:    Icons.edit_outlined,
                tooltip: 'Edit',
                onTap:   () => setState(() => _editing = true),
              ),
              _ActionIcon(
                icon:    Icons.close_rounded,
                tooltip: 'Delete',
                color:   const Color(0xFFEF4444),
                onTap:   _delete,
              ),
              const SizedBox(width: 4),
            ] else
              const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }
}

// ── Due date cell ─────────────────────────────────────────────────────────────

class _DueDateCell extends StatelessWidget {
  final DateTime? dueDate;
  const _DueDateCell({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    if (dueDate == null) {
      return Text('—',
          style: AppTextStyles.tableCell
              .copyWith(color: AppColors.textMuted));
    }
    final isOverdue = dueDate!.isBefore(DateTime.now());
    final isToday   = _sameDay(dueDate!, DateTime.now());
    final label     = isToday ? 'Today' : DateFormat('d MMM').format(dueDate!);
    return Text(
      label,
      style: AppTextStyles.tableCell.copyWith(
        color: isOverdue
            ? AppColors.statusBlockedText
            : isToday
                ? AppColors.statusWaitingText
                : AppColors.textPrimary,
        fontWeight:
            (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
