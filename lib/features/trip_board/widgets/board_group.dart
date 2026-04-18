import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/board_group_model.dart';
import '../providers/board_provider.dart';
import 'add_task_dialog.dart';
import 'task_row.dart';

// Total board table width — keeps the group header aligned with the columns.
const double _kBoardTotalWidth =
    BoardColumns.taskName +
    BoardColumns.status +
    BoardColumns.assignedTo +
    BoardColumns.destination +
    BoardColumns.travelDate +
    BoardColumns.dueDate +
    BoardColumns.supplier +
    BoardColumns.priority +
    BoardColumns.costStatus +
    BoardColumns.clientVisible;

/// Collapsible board group with a colored header and task rows.
class BoardGroupWidget extends StatefulWidget {
  final BoardGroup group;
  final BoardProvider provider;
  final String? selectedTaskId;

  const BoardGroupWidget({
    super.key,
    required this.group,
    required this.provider,
    this.selectedTaskId,
  });

  @override
  State<BoardGroupWidget> createState() => _BoardGroupWidgetState();
}

class _BoardGroupWidgetState extends State<BoardGroupWidget> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Group header ────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: SizedBox(
            width: _kBoardTotalWidth,
            height: AppSpacing.boardGroupHeaderH,
            child: ColoredBox(
              color: AppColors.surface,
              child: Row(
                children: [
                  // Colored left accent bar
                  Container(
                    width: 3,
                    height: AppSpacing.boardGroupHeaderH,
                    color: group.accentColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Expand / collapse chevron
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Group name
                  Text(
                    group.name,
                    style: AppTextStyles.heading3.copyWith(color: group.accentColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Task count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: group.accentColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${group.tasks.length}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: group.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // Spacer works here because the Row has a bounded width from SizedBox
                  const Spacer(),

                  // "Add task" button — its own GestureDetector stops
                  // the tap from bubbling up to the collapse handler above.
                  if (_expanded)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showAddTaskDialog(
                        context,
                        group:    group,
                        provider: widget.provider,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: AppColors.accent),
                            const SizedBox(width: 3),
                            Text(
                              'Add task',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Task rows (animated collapse) ───────────────────────────────────
        AnimatedCrossFade(
          firstChild: Column(
            children: group.tasks.map((task) => Column(
              children: [
                const Divider(height: 1, color: AppColors.divider),
                TaskRow(
                  task: task,
                  provider: widget.provider,
                  isSelected: task.id == widget.selectedTaskId,
                ),
              ],
            )).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 180),
        ),

        // Group bottom border
        Container(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
