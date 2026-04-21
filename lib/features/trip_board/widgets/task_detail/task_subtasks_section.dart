import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/models/subtask.dart';
import '../../../../data/models/task_model.dart';
import '../../providers/board_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskSubtasksSection
//
// Displays a checklist of subtasks for the currently selected task.
// - Progress bar + fraction at the top
// - Reorderable checklist rows (tap checkbox to toggle, swipe to delete)
// - Inline "Add subtask" field at the bottom
// ─────────────────────────────────────────────────────────────────────────────

class TaskSubtasksSection extends StatefulWidget {
  final Task         task;
  final BoardProvider provider;

  const TaskSubtasksSection({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  State<TaskSubtasksSection> createState() => _TaskSubtasksSectionState();
}

class _TaskSubtasksSectionState extends State<TaskSubtasksSection> {
  final _addCtrl    = TextEditingController();
  final _addFocus   = FocusNode();
  bool  _showInput  = false;

  @override
  void initState() {
    super.initState();
    // Ensure subscription exists regardless of how this screen was opened
    // (desktop selectTask vs mobile direct push both need this).
    widget.provider.subscribeToSubtasks(widget.task.id);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _showInput = false);
      return;
    }
    widget.provider.createSubtask(widget.task.id, text);
    _addCtrl.clear();
    // Keep input open for rapid entry
    _addFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, child) {
        final subtasks = widget.provider.subtasksFor(widget.task.id);
        final total     = subtasks.length;
        final completed = subtasks.where((s) => s.isCompleted).length;
        final progress  = total == 0 ? 0.0 : completed / total;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header + progress ──────────────────────────────────
            Row(
              children: [
                Text('SUBTASKS',
                    style: AppTextStyles.labelSmall.copyWith(
                      color:       AppColors.textMuted,
                      fontWeight:  FontWeight.w600,
                      letterSpacing: 0.6,
                    )),
                const Spacer(),
                if (total > 0)
                  Text('$completed / $total',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      )),
              ],
            ),

            if (total > 0) ...[
              const SizedBox(height: 6),
              _ProgressBar(value: progress),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 8),

            // ── Checklist ─────────────────────────────────────────────────
            if (subtasks.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap:      true,
                physics:         const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: subtasks.length,
                onReorder: (oldIdx, newIdx) {
                  if (newIdx > oldIdx) newIdx--;
                  widget.provider.reorderSubtasks(widget.task.id, oldIdx, newIdx);
                },
                itemBuilder: (_, i) {
                  final s = subtasks[i];
                  return _SubtaskItem(
                    key:      ValueKey(s.id),
                    subtask:  s,
                    index:    i,
                    provider: widget.provider,
                  );
                },
              ),

            // ── Add subtask ───────────────────────────────────────────────
            if (_showInput)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    const Icon(Icons.add, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller:  _addCtrl,
                        focusNode:   _addFocus,
                        style:       AppTextStyles.bodySmall,
                        autofocus:   true,
                        decoration:  const InputDecoration(
                          hintText:       'Add subtask…',
                          border:         InputBorder.none,
                          isDense:        true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                        onSubmitted: (_) => _submit(),
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    IconButton(
                      icon:       const Icon(Icons.check, size: 16),
                      padding:    EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color:      AppColors.accent,
                      onPressed:  _submit,
                    ),
                    IconButton(
                      icon:       const Icon(Icons.close, size: 16),
                      padding:    EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color:      AppColors.textMuted,
                      onPressed: () {
                        _addCtrl.clear();
                        setState(() => _showInput = false);
                      },
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _showInput = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Add subtask',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual subtask row
// ─────────────────────────────────────────────────────────────────────────────

class _SubtaskItem extends StatefulWidget {
  final Subtask      subtask;
  final int          index;
  final BoardProvider provider;

  const _SubtaskItem({
    super.key,
    required this.subtask,
    required this.index,
    required this.provider,
  });

  @override
  State<_SubtaskItem> createState() => _SubtaskItemState();
}

class _SubtaskItemState extends State<_SubtaskItem> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.subtask.title);
  }

  @override
  void didUpdateWidget(_SubtaskItem old) {
    super.didUpdateWidget(old);
    if (old.subtask.title != widget.subtask.title && !_editing) {
      _ctrl.text = widget.subtask.title;
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
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subtask;
    return Dismissible(
      key:        ValueKey('dismiss_${s.id}'),
      direction:  DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 12),
        color:     const Color(0xFFFEE2E2),
        child:     const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
      ),
      onDismissed: (_) => widget.provider.deleteSubtask(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => widget.provider.toggleSubtask(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width:  18,
                height: 18,
                decoration: BoxDecoration(
                  color:        s.isCompleted ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border:       Border.all(
                    color: s.isCompleted ? AppColors.accent : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: s.isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),

            // Title — tap to edit inline
            Expanded(
              child: _editing
                  ? TextField(
                      controller:      _ctrl,
                      autofocus:       true,
                      style:           AppTextStyles.bodySmall.copyWith(
                        decoration: TextDecoration.none,
                      ),
                      decoration:      const InputDecoration(
                        border:         InputBorder.none,
                        isDense:        true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted:     (_) => _commitEdit(),
                      onEditingComplete: _commitEdit,
                    )
                  : GestureDetector(
                      onDoubleTap: () => setState(() => _editing = true),
                      child: Text(
                        s.title,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: s.isCompleted
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration: s.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
            ),

            // Drag handle
            ReorderableDragStartListener(
              index: widget.index,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              height: 4,
              width:  width,
              decoration: BoxDecoration(
                color:        AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height:   4,
              width:    width * value,
              decoration: BoxDecoration(
                color:        value == 1.0
                    ? const Color(0xFF16A34A)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}
