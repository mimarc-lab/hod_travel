import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/task_model.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../providers/board_provider.dart';
import 'task_detail/task_detail_panel.dart';

/// Column widths for the board task table.
abstract class BoardColumns {
  static const double taskName     = 240.0;
  static const double status       = 130.0;
  static const double assignedTo   = 130.0;
  static const double destination  = 110.0;
  static const double travelDate   = 100.0;
  static const double dueDate      = 100.0;
  static const double supplier     = 140.0;
  static const double priority     =  90.0;
  static const double costStatus   = 110.0;
  static const double clientVisible =  90.0;
}

/// Header row with all column labels.
class BoardTableHeader extends StatelessWidget {
  const BoardTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      child: Row(
        children: [
          _HeaderCell(label: 'TASK NAME',   width: BoardColumns.taskName),
          _HeaderCell(label: 'STATUS',      width: BoardColumns.status),
          _HeaderCell(label: 'ASSIGNED TO', width: BoardColumns.assignedTo),
          _HeaderCell(label: 'DESTINATION', width: BoardColumns.destination),
          _HeaderCell(label: 'START DATE', width: BoardColumns.travelDate),
          _HeaderCell(label: 'DUE DATE',    width: BoardColumns.dueDate),
          _HeaderCell(label: 'SUPPLIER',    width: BoardColumns.supplier),
          _HeaderCell(label: 'PRIORITY',    width: BoardColumns.priority),
          _HeaderCell(label: 'COST STATUS', width: BoardColumns.costStatus),
          _HeaderCell(label: 'CLIENT',      width: BoardColumns.clientVisible),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(label, style: AppTextStyles.tableHeader, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ── Task row ──────────────────────────────────────────────────────────────────

class TaskRow extends StatelessWidget {
  final Task task;
  final BoardProvider provider;
  final bool isSelected;

  const TaskRow({
    super.key,
    required this.task,
    required this.provider,
    this.isSelected = false,
  });

  void _onTap(BuildContext context) {
    if (Responsive.isMobile(context)) {
      // Mobile: push full-screen detail
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          key: ValueKey(task.id),
          task: task,
          provider: provider,
        ),
      ));
    } else {
      // Desktop/tablet: open side panel
      provider.selectTask(task);
    }
  }

  Future<void> _onRightClick(BuildContext context, Offset position) async {
    final result = await showMenu<_RowAction>(
      context:  context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        const PopupMenuItem(
          value: _RowAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFF991B1B)),
              SizedBox(width: 10),
              Text('Delete task',
                  style: TextStyle(color: Color(0xFF991B1B))),
            ],
          ),
        ),
      ],
    );
    if (result == _RowAction.delete && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete task?'),
          content: Text(
            '"${task.name}" will be permanently removed.',
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
      if (confirmed == true) provider.deleteTask(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (d) => _onRightClick(context, d.globalPosition),
      child: Material(
      color: isSelected ? AppColors.accentFaint : Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        hoverColor: isSelected ? AppColors.accentFaint : AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: SizedBox(
          height: AppSpacing.boardTaskRowH,
          child: Row(
            children: [
              // Selected accent bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: AppSpacing.boardTaskRowH,
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),

              // Task name + optional subtask progress
              SizedBox(
                width: BoardColumns.taskName - 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: task.hasSubtasks
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.name,
                              style: AppTextStyles.tableCell.copyWith(
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value:            task.subtaskProgress,
                                      backgroundColor:  AppColors.border,
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
                                    fontSize: 9,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Text(
                          task.name,
                          style: AppTextStyles.tableCell.copyWith(
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),

              // Status
              SizedBox(
                width: BoardColumns.status,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TaskStatusChip(status: task.status),
                  ),
                ),
              ),

              // Assigned to
              SizedBox(
                width: BoardColumns.assignedTo,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: task.assignedTo != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(user: task.assignedTo!, size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                task.assignedTo!.name.split(' ').first,
                                style: AppTextStyles.tableCell,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text('—', style: AppTextStyles.tableCell.copyWith(color: AppColors.textMuted)),
                ),
              ),

              // Destination
              SizedBox(
                width: BoardColumns.destination,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    task.destination ?? '—',
                    style: AppTextStyles.tableCell,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Travel date
              SizedBox(
                width: BoardColumns.travelDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    task.travelDate != null ? DateFormat('d MMM').format(task.travelDate!) : '—',
                    style: AppTextStyles.tableCell,
                  ),
                ),
              ),

              // Due date
              SizedBox(
                width: BoardColumns.dueDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: _DueDateCell(dueDate: task.dueDate),
                ),
              ),

              // Supplier
              SizedBox(
                width: BoardColumns.supplier,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    task.supplierId ?? '—',
                    style: AppTextStyles.tableCell.copyWith(
                      color: task.supplierId != null ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Priority
              SizedBox(
                width: BoardColumns.priority,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PriorityChip(priority: task.priority),
                  ),
                ),
              ),

              // Cost status
              SizedBox(
                width: BoardColumns.costStatus,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CostStatusChip(status: task.costStatus),
                  ),
                ),
              ),

              // Client visible
              SizedBox(
                width: BoardColumns.clientVisible,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(
                    task.clientVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                    size: 15,
                    color: task.clientVisible ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ), // GestureDetector
    );
  }
}

enum _RowAction { delete }

// ── Due date cell ─────────────────────────────────────────────────────────────

class _DueDateCell extends StatelessWidget {
  final DateTime? dueDate;
  const _DueDateCell({required this.dueDate});

  @override
  Widget build(BuildContext context) {
    if (dueDate == null) {
      return Text('—', style: AppTextStyles.tableCell.copyWith(color: AppColors.textMuted));
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
        fontWeight: (isOverdue || isToday) ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
