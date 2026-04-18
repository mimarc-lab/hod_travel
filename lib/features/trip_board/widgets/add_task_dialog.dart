import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/board_group_model.dart';
import '../../../data/models/task_model.dart';
import '../providers/board_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AddTaskDialog
//
// Modal dialog for creating a new task in a board group.
// When [allGroups] is supplied the user can pick which column to add to;
// otherwise the dialog targets the single [group] passed in.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showAddTaskDialog(
  BuildContext context, {
  required BoardGroup group,
  required BoardProvider provider,
  // Supply all groups to let the user pick the destination column.
  List<BoardGroup>? allGroups,
  // Optional prefill — used when applying an AI suggestion.
  String?       initialName,
  TaskPriority? initialPriority,
}) {
  return showDialog(
    context: context,
    builder: (_) => _AddTaskDialog(
      group:           group,
      provider:        provider,
      allGroups:       allGroups,
      initialName:     initialName,
      initialPriority: initialPriority,
    ),
  );
}

class _AddTaskDialog extends StatefulWidget {
  final BoardGroup      group;
  final BoardProvider   provider;
  final List<BoardGroup>? allGroups;
  final String?         initialName;
  final TaskPriority?   initialPriority;

  const _AddTaskDialog({
    required this.group,
    required this.provider,
    this.allGroups,
    this.initialName,
    this.initialPriority,
  });

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  late BoardGroup  _selectedGroup;
  late TaskPriority _priority;
  DateTime? _dueDate;
  bool      _saving = false;
  String?   _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _priority       = widget.initialPriority ?? TaskPriority.medium;
    _selectedGroup  = widget.group;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final task = Task(
      id:           '',
      boardGroupId: _selectedGroup.id,
      name:         _nameController.text.trim(),
      status:       TaskStatus.notStarted,
      priority:     _priority,
      costStatus:   TaskCostStatus.pending,
      dueDate:      _dueDate,
    );

    await widget.provider.createTask(task);

    if (!mounted) return;

    // Surface any error the provider set
    if (widget.provider.error != null) {
      setState(() {
        _saving = false;
        _error  = widget.provider.error;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _dueDate ?? now,
      firstDate:   now.subtract(const Duration(days: 365)),
      lastDate:    now.add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.allGroups;
    final showGroupPicker = groups != null && groups.length > 1;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _selectedGroup.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        showGroupPicker
                            ? 'Add Task to Board'
                            : 'Add Task — ${_selectedGroup.name}',
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Board column picker (AI flow) ─────────────────────────
                if (showGroupPicker) ...[
                  Text('Board Column', style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<BoardGroup>(
                    value: _selectedGroup,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textPrimary),
                    decoration: _inputDecoration(null),
                    dropdownColor: AppColors.surface,
                    validator: (v) => v == null ? 'Select a board column' : null,
                    items: groups.map((g) => DropdownMenuItem(
                      value: g,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: g.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(g.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedGroup = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                // ── Task name ──────────────────────────────────────────────
                Text('Task Name', style: AppTextStyles.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller:    _nameController,
                  autofocus:     true,
                  textCapitalization: TextCapitalization.sentences,
                  style:         AppTextStyles.bodyMedium,
                  decoration:    _inputDecoration('e.g. Confirm Adora Luxury Hotel'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Task name is required' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.base),

                // ── Priority + Due date ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Priority', style: AppTextStyles.labelMedium),
                          const SizedBox(height: AppSpacing.xs),
                          DropdownButtonFormField<TaskPriority>(
                            value: _priority,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textPrimary),
                            decoration:   _inputDecoration(null),
                            dropdownColor: AppColors.surface,
                            items: TaskPriority.values.map((p) =>
                              DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ),
                            ).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _priority = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due Date (optional)',
                              style: AppTextStyles.labelMedium),
                          const SizedBox(height: AppSpacing.xs),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.inputRadius),
                                color: AppColors.surface,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dueDate != null
                                          ? _formatDate(_dueDate!)
                                          : 'Select date',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: _dueDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 14, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Error banner ───────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: Color(0xFF991B1B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: const Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                // ── Actions ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.buttonRadius),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add Task'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText:  hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:   const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled:    true,
        fillColor: AppColors.surface,
      );

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
