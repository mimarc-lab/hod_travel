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
        const SizedBox(height: AppSpacing.md),
        if (tasks.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No tasks assigned',
            subtitle: 'Tasks assigned to you will appear here.',
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const _TaskRowHeader(),
                const Divider(height: 1, color: AppColors.divider),
                ...tasks.asMap().entries.map((e) => Column(
                  children: [
                    _TaskRowItem(task: e.value),
                    if (e.key < tasks.length - 1)
                      const Divider(height: 1, color: AppColors.divider),
                  ],
                )),
              ],
            ),
          ),
      ],
    );
  }
}

class _TaskRowHeader extends StatelessWidget {
  const _TaskRowHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingH,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TASK',     style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('TRIP',     style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('STATUS',   style: AppTextStyles.tableHeader)),
          Expanded(flex: 1, child: Text('DUE',      style: AppTextStyles.tableHeader)),
          Expanded(flex: 1, child: Text('PRIORITY', style: AppTextStyles.tableHeader)),
        ],
      ),
    );
  }
}

class _TaskRowItem extends StatelessWidget {
  final Task task;
  const _TaskRowItem({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingH,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              task.name,
              style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '—',
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TaskStatusChip(status: task.status),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              task.dueDate != null
                  ? DateFormat('MMM d').format(task.dueDate!)
                  : '—',
              style: AppTextStyles.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PriorityChip(priority: task.priority),
            ),
          ),
        ],
      ),
    );
  }
}
