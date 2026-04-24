import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/role_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/approval_model.dart';
import '../../../../data/models/task_model.dart';
import '../../../../features/trip_board/providers/board_provider.dart';
import '../../../../shared/widgets/approval_chip.dart';
import 'task_attachments_section.dart';
import 'task_comments_section.dart';
import 'task_info_section.dart';
import 'task_linked_section.dart';
import 'task_subtasks_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskDetailPanel — side panel container (desktop/tablet)
// ─────────────────────────────────────────────────────────────────────────────

/// Outer container. Rendered as a side panel by TripBoardScreen.
/// key: ValueKey(task.id) is set by the caller so state resets per task.
class TaskDetailPanel extends StatelessWidget {
  final Task task;
  final BoardProvider provider;

  const TaskDetailPanel({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: _TaskDetailContent(task: task, provider: provider),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaskDetailScreen — full-screen wrapper for mobile
// ─────────────────────────────────────────────────────────────────────────────

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  final BoardProvider provider;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _TaskDetailContent(task: task, provider: provider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TaskDetailContent — shared StatefulWidget for both panel and screen
// ─────────────────────────────────────────────────────────────────────────────

class _TaskDetailContent extends StatefulWidget {
  final Task task;
  final BoardProvider provider;

  const _TaskDetailContent({required this.task, required this.provider});

  @override
  State<_TaskDetailContent> createState() => _TaskDetailContentState();
}

class _TaskDetailContentState extends State<_TaskDetailContent> {
  late Task _task;

  // Text controllers — persisted within a single task view session.
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _destinationCtrl;
  late final TextEditingController _supplierCtrl;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleCtrl       = TextEditingController(text: _task.name);
    _descriptionCtrl = TextEditingController(text: _task.description ?? '');
    _destinationCtrl = TextEditingController(text: _task.destination ?? '');
    _supplierCtrl    = TextEditingController(text: _task.supplierId ?? '');
  }

  @override
  void didUpdateWidget(_TaskDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The provider (via BoardProvider.updateTaskStatus / updateTaskAssignee etc.)
    // updates selectedTask and notifies listeners, which causes TripBoardScreen
    // to pass a new widget.task here.  Without this sync, _task stays at its
    // initial snapshot, so a second change (e.g. assignee after status) writes
    // back the old value and erases the first change.
    if (widget.task != _task) {
      setState(() => _task = widget.task);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _destinationCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  /// Apply a field change locally and push to the provider immediately.
  void _update(Task updated) {
    setState(() => _task = updated);
    widget.provider.updateTask(updated);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final nav      = Navigator.of(context);
    final isMobile = Responsive.isMobile(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text('Delete task?', style: AppTextStyles.heading3),
        content: Text(
          '"${_task.name}" will be permanently removed.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
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
    if (confirmed == true && mounted) {
      widget.provider.deleteTask(_task.id);
      // On mobile the detail is a full-screen route — pop it.
      // On desktop/tablet the panel closes automatically when the provider
      // clears selectedTask; calling nav.pop() would exit the board entirely.
      if (isMobile && nav.canPop()) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Fixed header ───────────────────────────────────────────────────
        _PanelHeader(
          task: _task,
          titleCtrl: _titleCtrl,
          provider: widget.provider,
          onTitleCommit: (v) {
            final trimmed = v.trim();
            if (trimmed.isNotEmpty && trimmed != _task.name) {
              _update(_task.copyWith(name: trimmed));
            }
          },
          onClose: widget.provider.clearSelection,
          onDelete: () => _confirmDelete(context),
        ),

        // ── Scrollable body ────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.base,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assignee · Status · Priority quick row
                TaskQuickBar(task: _task, provider: widget.provider),
                const SizedBox(height: AppSpacing.base),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Assigned team
                AssignedTeamSection(task: _task, provider: widget.provider),
                const SizedBox(height: AppSpacing.base),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Description
                _DescriptionField(
                  ctrl: _descriptionCtrl,
                  onCommit: (v) => _update(_task.copyWith(
                    description: v.trim().isEmpty ? null : v.trim(),
                    clearDescription: v.trim().isEmpty,
                  )),
                ),
                const SizedBox(height: AppSpacing.base),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Editable fields
                TaskInfoSection(
                  task: _task,
                  destinationCtrl: _destinationCtrl,
                  supplierCtrl: _supplierCtrl,
                  onUpdate: _update,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Subtasks
                TaskSubtasksSection(
                  task:     _task,
                  provider: widget.provider,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Approval
                _TaskApprovalSection(task: _task, provider: widget.provider),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Activity & Comments
                TaskCommentsSection(
                  taskId: _task.id,
                  provider: widget.provider,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Attachments placeholder
                const TaskAttachmentsSection(),
                const SizedBox(height: AppSpacing.xl),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.base),

                // Linked items
                TaskLinkedSection(task: _task),
                const SizedBox(height: AppSpacing.massive),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approval section
// ─────────────────────────────────────────────────────────────────────────────

class _TaskApprovalSection extends StatelessWidget {
  final Task task;
  final BoardProvider provider;
  const _TaskApprovalSection({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    final rs = RoleScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSectionHeader(label: 'APPROVAL'),
        ApprovalActionBar(
          current: task.approvalStatus,
          canApprove: rs.canApprove,
          canSubmit: rs.canSubmitForReview,
          onSubmitForReview: () => provider.updateTaskApproval(
              task, ApprovalStatus.pendingReview),
          onApprove: () =>
              provider.updateTaskApproval(task, ApprovalStatus.approved),
          onReject: () =>
              provider.updateTaskApproval(task, ApprovalStatus.rejected),
          onReturnToDraft: () =>
              provider.updateTaskApproval(task, ApprovalStatus.draft),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel header — title + close button
// ─────────────────────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final Task task;
  final TextEditingController titleCtrl;
  final BoardProvider provider;
  final void Function(String) onTitleCommit;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const _PanelHeader({
    required this.task,
    required this.titleCtrl,
    required this.provider,
    required this.onTitleCommit,
    required this.onClose,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: titleCtrl,
              style: AppTextStyles.heading2,
              maxLines: null,
              onEditingComplete: () => onTitleCommit(titleCtrl.text),
              onTapOutside: (_) => onTitleCommit(titleCtrl.text),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // More options menu (delete, etc.)
          PopupMenuButton<_PanelMenuAction>(
            onSelected: (action) {
              if (action == _PanelMenuAction.delete) onDelete();
            },
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _PanelMenuAction.delete,
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
          ),
          const SizedBox(width: 4),
          // Close button
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PanelMenuAction { delete }

// ─────────────────────────────────────────────────────────────────────────────
// Description field
// ─────────────────────────────────────────────────────────────────────────────

class _DescriptionField extends StatelessWidget {
  final TextEditingController ctrl;
  final void Function(String) onCommit;

  const _DescriptionField({required this.ctrl, required this.onCommit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          maxLines: null,
          minLines: 3,
          onEditingComplete: () => onCommit(ctrl.text),
          onTapOutside: (_) => onCommit(ctrl.text),
          decoration: InputDecoration(
            hintText: 'Add a description, notes, or instructions…',
            hintStyle: AppTextStyles.bodySmall,
            filled: true,
            fillColor: AppColors.surfaceAlt,
            isDense: true,
            contentPadding: const EdgeInsets.all(AppSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
