import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_chip.dart';

class MyTasksSection extends StatelessWidget {
  final List<Task> tasks;

  const MyTasksSection({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'My Tasks', actionLabel: 'View all'),
        const SizedBox(height: AppSpacing.base),
        if (tasks.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No tasks assigned',
            subtitle: 'Tasks assigned to you will appear here.',
          )
        else
          Column(
            children: tasks.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TaskCard(task: e.value),
            )).toList(),
          ),
      ],
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  const _TaskCard({required this.task});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task    = widget.task;
    final dueDate = task.dueDate;
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surfaceAlt : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: _hovered ? AppColors.border : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(_hovered ? 0x0A000000 : 0x05000000),
              blurRadius: _hovered ? 8 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox-style dot indicator
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Task name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dueDate != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Due ${DateFormat('MMM d').format(dueDate)}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isOverdue
                              ? AppColors.statusBlockedText
                              : AppColors.textMuted,
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Status + priority chips
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PriorityChip(priority: task.priority),
                  const SizedBox(width: 6),
                  TaskStatusChip(status: task.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
