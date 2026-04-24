import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/task_assignment_model.dart';
import '../../../../data/models/task_model.dart';
import '../../../../features/trip_board/providers/board_provider.dart';
import '../../../../shared/widgets/stacked_avatars.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/user_avatar.dart';

// ── Section header ────────────────────────────────────────────────────────────

class PanelSectionHeader extends StatelessWidget {
  final String label;
  const PanelSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTextStyles.overline),
    );
  }
}

// ── Field row layout ──────────────────────────────────────────────────────────

/// A single label + value row used throughout the task detail panel.
class DetailFieldRow extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;

  const DetailFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(label, style: AppTextStyles.labelMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: value),
        ],
      ),
    );
  }
}

// ── Assignee + status quick bar ───────────────────────────────────────────────

class TaskQuickBar extends StatelessWidget {
  final Task task;
  final BoardProvider provider;

  const TaskQuickBar({super.key, required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _AssigneeDropdown(task: task, provider: provider),
        _StatusDropdown(task: task, provider: provider),
        _PriorityDropdown(task: task, provider: provider),
      ],
    );
  }
}

// ── Assignee dropdown ─────────────────────────────────────────────────────────

class _AssigneeDropdown extends StatelessWidget {
  final Task task;
  final BoardProvider provider;
  const _AssigneeDropdown({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    final assignments = task.assignments;
    return PopupMenuButton<String>(
      tooltip: 'Set primary assignee',
      onSelected: (id) {
        final selected = id == '__none__'
            ? null
            : provider.members.firstWhere((u) => u.id == id);
        provider.updateTaskAssignee(task, selected);
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: '__none__',
          child: Text('Unassigned'),
        ),
        ...provider.members.map((u) => PopupMenuItem<String>(
              value: u.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(user: u, size: 20),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      u.name,
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assignments.isEmpty) ...[
              Icon(Icons.person_add_alt_1_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text('Assign', style: AppTextStyles.labelMedium),
            ] else if (assignments.length == 1) ...[
              UserAvatar(user: assignments.first.user, size: 18),
              const SizedBox(width: 6),
              Text(
                assignments.first.user.name.split(' ').first,
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
              ),
            ] else ...[
              StackedAvatars(
                users: assignments.map((a) => a.user).toList(),
                size: 18,
                maxVisible: 3,
                overlap: 5,
              ),
              const SizedBox(width: 6),
              Text(
                '${assignments.length} assigned',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Status dropdown ───────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  final Task task;
  final BoardProvider provider;
  const _StatusDropdown({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskStatus>(
      tooltip: 'Change status',
      onSelected: (s) => provider.updateTaskStatus(task, s),
      itemBuilder: (_) => TaskStatus.values
          .map((s) => PopupMenuItem<TaskStatus>(
                value: s,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusDot(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.label, style: AppTextStyles.bodySmall),
                  ],
                ),
              ))
          .toList(),
      child: TaskStatusChip(status: task.status),
    );
  }

  Color _statusDot(TaskStatus s) {
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

// ── Priority dropdown ─────────────────────────────────────────────────────────

class _PriorityDropdown extends StatelessWidget {
  final Task task;
  final BoardProvider provider;
  const _PriorityDropdown({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskPriority>(
      tooltip: 'Change priority',
      onSelected: (p) => provider.updateTaskPriority(task, p),
      itemBuilder: (_) => TaskPriority.values
          .map((p) => PopupMenuItem<TaskPriority>(
                value: p,
                child: Text(p.label, style: AppTextStyles.bodySmall),
              ))
          .toList(),
      child: PriorityChip(priority: task.priority),
    );
  }
}

// ── Main info section — editable fields ───────────────────────────────────────

class TaskInfoSection extends StatelessWidget {
  final Task task;
  final TextEditingController destinationCtrl;
  final TextEditingController supplierCtrl;
  final void Function(Task) onUpdate;

  const TaskInfoSection({
    super.key,
    required this.task,
    required this.destinationCtrl,
    required this.supplierCtrl,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSectionHeader(label: 'DETAILS'),

        // Group (read-only)
        DetailFieldRow(
          label: 'Group',
          icon: Icons.folder_outlined,
          value: Text(task.boardGroupId, style: AppTextStyles.bodySmall),
        ),

        // Destination
        DetailFieldRow(
          label: 'Destination',
          icon: Icons.location_on_outlined,
          value: _InlineTextField(
            controller: destinationCtrl,
            hint: 'Add destination',
            onSubmit: (v) => onUpdate(task.copyWith(
              destination: v.trim().isEmpty ? null : v.trim(),
              clearDestination: v.trim().isEmpty,
            )),
          ),
        ),

        // Travel date
        DetailFieldRow(
          label: 'Start Date',
          icon: Icons.flight_outlined,
          value: _DateField(
            date: task.travelDate,
            hint: 'Set travel date',
            onPick: (d) => onUpdate(task.copyWith(travelDate: d, clearTravelDate: d == null)),
          ),
        ),

        // Due date
        DetailFieldRow(
          label: 'Due Date',
          icon: Icons.calendar_today_outlined,
          value: _DateField(
            date: task.dueDate,
            hint: 'Set due date',
            onPick: (d) => onUpdate(task.copyWith(dueDate: d, clearDueDate: d == null)),
          ),
        ),

        // Supplier
        DetailFieldRow(
          label: 'Supplier',
          icon: Icons.storefront_outlined,
          value: _InlineTextField(
            controller: supplierCtrl,
            hint: 'Add supplier ID',
            onSubmit: (v) => onUpdate(task.copyWith(
              supplierId: v.trim().isEmpty ? null : v.trim(),
              clearSupplierId: v.trim().isEmpty,
            )),
          ),
        ),

        // Cost status
        DetailFieldRow(
          label: 'Cost Status',
          icon: Icons.account_balance_wallet_outlined,
          value: _CostStatusDropdown(task: task, onUpdate: onUpdate),
        ),

        // Client visible
        DetailFieldRow(
          label: 'Client Visible',
          icon: Icons.visibility_outlined,
          value: _ClientVisibleToggle(task: task, onUpdate: onUpdate),
        ),
      ],
    );
  }
}

// ── Cost status dropdown ──────────────────────────────────────────────────────

class _CostStatusDropdown extends StatelessWidget {
  final Task task;
  final void Function(Task) onUpdate;
  const _CostStatusDropdown({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CostStatus>(
      onSelected: (s) => onUpdate(task.copyWith(costStatus: s)),
      itemBuilder: (_) => CostStatus.values
          .map((s) => PopupMenuItem<CostStatus>(
                value: s,
                child: Text(s.label, style: AppTextStyles.bodySmall),
              ))
          .toList(),
      child: CostStatusChip(status: task.costStatus),
    );
  }
}

// ── Client visible toggle ─────────────────────────────────────────────────────

class _ClientVisibleToggle extends StatelessWidget {
  final Task task;
  final void Function(Task) onUpdate;
  const _ClientVisibleToggle({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: Switch.adaptive(
            value: task.clientVisible,
            onChanged: (v) => onUpdate(task.copyWith(clientVisible: v)),
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accentLight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          task.clientVisible ? 'Visible to client' : 'Internal only',
          style: AppTextStyles.labelSmall.copyWith(
            color: task.clientVisible ? AppColors.accent : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Inline text field ─────────────────────────────────────────────────────────

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String) onSubmit;

  const _InlineTextField({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      onEditingComplete: () => onSubmit(controller.text),
      onTapOutside: (_) => onSubmit(controller.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final void Function(DateTime?) onPick;

  const _DateField({required this.date, required this.hint, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date != null ? DateFormat('d MMM yyyy').format(date!) : hint,
            style: date != null
                ? AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)
                : AppTextStyles.bodySmall,
          ),
          if (date != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onPick(null),
              child: Icon(Icons.close_rounded, size: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Assigned team section ─────────────────────────────────────────────────────

class AssignedTeamSection extends StatelessWidget {
  final Task task;
  final BoardProvider provider;

  const AssignedTeamSection({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final assignments = task.assignments;
    final assignedIds = assignments.map((a) => a.user.id).toSet();
    final available = provider.members
        .where((u) => !assignedIds.contains(u.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: PanelSectionHeader(label: 'ASSIGNED TEAM')),
            if (available.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Add assignee',
                onSelected: (id) {
                  final user = provider.members.firstWhere((u) => u.id == id);
                  provider.addTaskAssignee(task, user);
                },
                itemBuilder: (_) => available
                    .map((u) => PopupMenuItem<String>(
                          value: u.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserAvatar(user: u, size: 20),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(u.name,
                                    style: AppTextStyles.bodySmall,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                child: Icon(Icons.person_add_alt_1_outlined,
                    size: 15, color: AppColors.textMuted),
              ),
          ],
        ),
        if (assignments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('No one assigned',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          )
        else
          ...assignments.map((a) => _AssigneeRow(
                assignment: a,
                task: task,
                provider: provider,
              )),
      ],
    );
  }
}

class _AssigneeRow extends StatelessWidget {
  final TaskAssignment assignment;
  final Task task;
  final BoardProvider provider;

  const _AssigneeRow({
    required this.assignment,
    required this.task,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          UserAvatar(user: assignment.user, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(assignment.user.name,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textPrimary)),
          ),
          _RoleBadge(label: assignment.roleLabel),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => provider.removeTaskAssignee(task, assignment.user),
            child: Icon(Icons.close_rounded,
                size: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}
