import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/board_group_model.dart';
import '../../../data/models/trip_template_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/trip_template_repository.dart';

// =============================================================================
// TemplateManagerScreen
//
// Lists all team templates. Tap to open editor. FAB creates a new template.
// =============================================================================

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  List<TripTemplate> _templates = [];
  bool _loading = true;

  TripTemplateRepository? get _repo => AppRepositories.instance?.templates;
  String? get _teamId => AppRepositories.instance?.currentTeamId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_repo == null || _teamId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final templates = await _repo!.fetchAll(_teamId!);
      if (mounted) setState(() { _templates = templates; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load templates: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _createTemplate() async {
    final name = await _showNameDialog(context, existing: null);
    if (name == null || name.isEmpty) return;
    final repos = AppRepositories.instance;
    if (repos == null || repos.currentTeamId == null) return;
    final created = await _repo!.create(
      teamId:  repos.currentTeamId!,
      userId:  repos.currentUserId ?? '',
      name:    name,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(template: created, onSaved: _load),
      ),
    );
    _load();
  }

  Future<void> _openTemplate(TripTemplate t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(template: t, onSaved: _load),
      ),
    );
    _load();
  }

  Future<void> _deleteTemplate(TripTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${t.name}" and all its tasks will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo!.delete(t.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Trip Templates', style: AppTextStyles.heading2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTemplate,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Template'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _EmptyState(onCreate: _createTemplate)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  itemCount: _templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    return _TemplateCard(
                      template: t,
                      onTap:    () => _openTemplate(t),
                      onDelete: () => _deleteTemplate(t),
                    );
                  },
                ),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final TripTemplate template;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _TemplateCard({required this.template, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentFaint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.content_copy_outlined,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name,
                        style: AppTextStyles.labelMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (template.description != null &&
                        template.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(template.description!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text('${template.taskCount} tasks',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textMuted),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.content_copy_outlined,
                size: 24, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No templates yet', style: AppTextStyles.heading2),
          const SizedBox(height: 6),
          Text('Create a template to auto-generate tasks on new trips.',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Create Template',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Name dialog ───────────────────────────────────────────────────────────────

Future<String?> _showNameDialog(BuildContext context, {required String? existing}) {
  final ctrl = TextEditingController(text: existing ?? '');
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(existing == null ? 'New Template' : 'Rename Template'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g. Luxury City Break',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          child: Text(existing == null ? 'Create' : 'Save'),
        ),
      ],
    ),
  );
}

// =============================================================================
// TemplateEditorScreen
//
// Edit tasks within a template. Tasks grouped by board group.
// =============================================================================

class TemplateEditorScreen extends StatefulWidget {
  final TripTemplate template;
  final VoidCallback onSaved;
  const TemplateEditorScreen({super.key, required this.template, required this.onSaved});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late TripTemplate _template;
  bool _saving = false;
  List<AppUser> _members = [];

  TripTemplateRepository? get _repo => AppRepositories.instance?.templates;

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final profiles = await AppRepositories.instance?.profiles.fetchAllProfiles() ?? [];
      final users = profiles.map((p) => p.toAppUser()).toList();
      if (mounted) setState(() => _members = users);
    } catch (e) {
      debugPrint('_loadMembers error: $e');
    }
  }

  Future<void> _reload() async {
    if (_repo == null) return;
    final teamId = AppRepositories.instance?.currentTeamId;
    if (teamId == null) return;
    try {
      final all = await _repo!.fetchAll(teamId);
      final fresh = all.firstWhere((t) => t.id == _template.id,
          orElse: () => _template);
      if (mounted) setState(() => _template = fresh);
    } catch (_) {}
  }

  Future<void> _renameTemplate() async {
    final name = await _showNameDialog(context, existing: _template.name);
    if (name == null || name.isEmpty) return;
    await _repo!.updateName(id: _template.id, name: name);
    await _reload();
  }

  Future<void> _addTask(String groupName) async {
    final result = await _showTaskDialog(
      context,
      groupName: groupName,
      members:   _members,
    );
    if (result == null) return;
    setState(() => _saving = true);
    final groupTasks = _template.tasksForGroup(groupName);
    await _repo!.addTask(
      templateId:        _template.id,
      groupName:         groupName,
      title:             result.title,
      priority:          result.priority,
      sortOrder:         groupTasks.length,
      defaultAssigneeId: result.assigneeId,
    );
    await _reload();
    if (mounted) setState(() => _saving = false);
    widget.onSaved();
  }

  Future<void> _editTask(TripTemplateTask task) async {
    final result = await _showTaskDialog(
      context,
      groupName:          task.groupName,
      existingTitle:      task.title,
      existingPriority:   task.priority,
      existingAssigneeId: task.defaultAssigneeId,
      members:            _members,
    );
    if (result == null) return;
    await _repo!.updateTask(task.copyWith(
      title:             result.title,
      priority:          result.priority,
      defaultAssigneeId: result.assigneeId,
      clearAssignee:     result.assigneeId == null,
    ));
    await _reload();
    widget.onSaved();
  }

  Future<void> _deleteTask(TripTemplateTask task) async {
    await _repo!.deleteTask(task.id);
    await _reload();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: GestureDetector(
          onTap: _renameTemplate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_template.name,
                    style: AppTextStyles.heading2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () { widget.onSaved(); Navigator.of(context).pop(); },
        ),
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                Text(
                  'Tap a group to add tasks. Tasks will be auto-created '
                  'when this template is used on a new trip.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.base),
                ...defaultBoardGroupNames.map((group) => _GroupSection(
                      groupName: group,
                      tasks:     _template.tasksForGroup(group),
                      members:   _members,
                      onAdd:     () => _addTask(group),
                      onEdit:    _editTask,
                      onDelete:  _deleteTask,
                    )),
              ],
            ),
    );
  }
}

// ── Group section ─────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  final String groupName;
  final List<TripTemplateTask> tasks;
  final List<AppUser> members;
  final VoidCallback onAdd;
  final Future<void> Function(TripTemplateTask) onEdit;
  final Future<void> Function(TripTemplateTask) onDelete;

  const _GroupSection({
    required this.groupName,
    required this.tasks,
    required this.members,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text(groupName,
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${tasks.length}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onAdd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text('Add task',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (tasks.isNotEmpty)
            const Divider(height: 1, color: AppColors.divider),
          // Task rows
          ...tasks.map((t) => _TaskRow(
                task:     t,
                members:  members,
                onEdit:   () => onEdit(t),
                onDelete: () => onDelete(t),
              )),
        ],
      ),
    );
  }
}

// ── Task row ──────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final TripTemplateTask task;
  final List<AppUser> members;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TaskRow({
    required this.task,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  static const _priorityColors = {
    'high':   Color(0xFFD4845A),
    'medium': Color(0xFFC9A96E),
    'low':    Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    final assignee = task.defaultAssigneeId == null
        ? null
        : members.where((m) => m.id == task.defaultAssigneeId).firstOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _priorityColors[task.priority] ?? AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(task.title,
                    style: AppTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (assignee != null) ...[
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: assignee.avatarColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(assignee.initials,
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white, fontSize: 9)),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(task.priority,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: _priorityColors[task.priority] ??
                          AppColors.textMuted)),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task result record ────────────────────────────────────────────────────────

typedef _TaskDialogResult = ({String title, String priority, String? assigneeId});

// ── Task dialog ───────────────────────────────────────────────────────────────

Future<_TaskDialogResult?> _showTaskDialog(
  BuildContext context, {
  required String groupName,
  required List<AppUser> members,
  String? existingTitle,
  String? existingPriority,
  String? existingAssigneeId,
}) {
  final titleCtrl = TextEditingController(text: existingTitle ?? '');
  String priority      = existingPriority ?? 'medium';
  String? assigneeId   = existingAssigneeId;

  return showDialog<_TaskDialogResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        title: Text(existingTitle == null
            ? 'Add Task to $groupName'
            : 'Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Task title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            DropdownButtonFormField<String>(
              key: ValueKey(priority),
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: ['high', 'medium', 'low']
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p[0].toUpperCase() + p.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) setDlgState(() => priority = v); },
            ),
            const SizedBox(height: AppSpacing.base),
            DropdownButtonFormField<String?>(
                key: ValueKey(assigneeId),
                initialValue: assigneeId,
                decoration: const InputDecoration(
                  labelText: 'Default assignee',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...members.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name),
                      )),
                ],
                onChanged: (v) => setDlgState(() => assigneeId = v),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              Navigator.of(ctx).pop(
                (title: title, priority: priority, assigneeId: assigneeId),
              );
            },
            child: Text(existingTitle == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
