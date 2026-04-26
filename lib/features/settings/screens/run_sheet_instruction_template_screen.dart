import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/repositories/run_sheet_instruction_template_repository.dart';

// =============================================================================
// RunSheetInstructionTemplateScreen
// =============================================================================

class RunSheetInstructionTemplateScreen extends StatefulWidget {
  const RunSheetInstructionTemplateScreen({super.key});

  @override
  State<RunSheetInstructionTemplateScreen> createState() =>
      _RunSheetInstructionTemplateScreenState();
}

class _RunSheetInstructionTemplateScreenState
    extends State<RunSheetInstructionTemplateScreen> {
  // Built-in types (from ItemType enum)
  static const _builtInTypes = [
    ItemType.hotel,
    ItemType.transport,
    ItemType.flight,
    ItemType.dining,
    ItemType.experience,
  ];
  static final _builtInDbValues =
      _builtInTypes.map((t) => t.dbValue).toSet();

  RunSheetInstructionTemplateRepository? get _repo =>
      AppRepositories.instance?.runSheetInstructionTemplates;
  String? get _teamId => AppRepositories.instance?.currentTeamId;

  // Map keyed by "componentType:instructionType" → template
  final Map<String, RunSheetInstructionTemplate> _customTemplates = {};
  // Custom type names not in the built-in list (loaded from DB + newly added)
  final List<String> _customTypeNames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_repo == null || _teamId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await _repo!.fetchForTeam(_teamId!);
      final map  = <String, RunSheetInstructionTemplate>{};
      final extraTypes = <String>{};
      for (final r in rows) {
        final key = '${r.componentType}:${r.instructionType.dbValue}';
        map[key] = r;
        if (!_builtInDbValues.contains(r.componentType)) {
          extraTypes.add(r.componentType);
        }
      }
      if (mounted) {
        setState(() {
          _customTemplates
            ..clear()
            ..addAll(map);
          // Preserve any newly-added types that don't have templates yet
          for (final t in extraTypes) {
            if (!_customTypeNames.contains(t)) _customTypeNames.add(t);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load templates: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  RunSheetInstructionTemplate? _getCustom(
          String componentType, InstructionType iType) =>
      _customTemplates['$componentType:${iType.dbValue}'];

  bool _hasAnyCustomForBuiltIn(String componentType) =>
      InstructionType.values
          .any((i) => _customTemplates.containsKey('$componentType:${i.dbValue}'));

  Future<void> _saveTemplate(
      String componentType, InstructionType iType, String text) async {
    final existing = _getCustom(componentType, iType);
    try {
      if (existing != null) {
        final updated = RunSheetInstructionTemplate(
          id:              existing.id,
          teamId:          existing.teamId,
          componentType:   existing.componentType,
          instructionType: existing.instructionType,
          templateText:    text,
          sortOrder:       existing.sortOrder,
        );
        await _repo!.update(updated);
        final key = '$componentType:${iType.dbValue}';
        if (mounted) setState(() => _customTemplates[key] = updated);
      } else {
        final created = await _repo!.create(
          teamId:          _teamId!,
          componentType:   componentType,
          instructionType: iType,
          templateText:    text,
        );
        final key = '$componentType:${iType.dbValue}';
        if (mounted) setState(() => _customTemplates[key] = created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteTemplate(
      String componentType, InstructionType iType) async {
    final existing = _getCustom(componentType, iType);
    if (existing == null) return;
    try {
      await _repo!.delete(existing.id);
      final key = '$componentType:${iType.dbValue}';
      if (mounted) setState(() => _customTemplates.remove(key));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteCustomType(String componentType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
        title: Text('Delete type?', style: AppTextStyles.heading3),
        content: Text(
          'This will remove all instructions saved for '
          '"${_typeDisplayLabel(componentType)}". This cannot be undone.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.statusBlockedText),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final iType in InstructionType.values) {
      await _deleteTemplate(componentType, iType);
    }
    if (mounted) {
      setState(() {
        _customTypeNames.remove(componentType);
        for (final i in InstructionType.values) {
          _customTemplates.remove('$componentType:${i.dbValue}');
        }
      });
    }
  }

  Future<void> _importDefaults(String componentType) async {
    final defaults = DefaultInstructionTemplates.buildFor(componentType);
    if (defaults == null) return;
    final pairs = [
      (InstructionType.operational, defaults.operational),
      (InstructionType.contingency,  defaults.contingency),
      (InstructionType.escalation,   defaults.escalation),
    ];
    for (final (iType, text) in pairs) {
      if (text.isNotEmpty && _getCustom(componentType, iType) == null) {
        await _saveTemplate(componentType, iType, text);
      }
    }
  }

  Future<void> _openEditDialog(
      String componentType, InstructionType iType, String currentText,
      {required String typeLabel}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditInstructionDialog(
        typeLabel:       typeLabel,
        instructionType: iType,
        initialText:     currentText,
      ),
    );
    if (result == null) return;
    if (result.trim().isEmpty) {
      await _deleteTemplate(componentType, iType);
    } else {
      await _saveTemplate(componentType, iType, result.trim());
    }
  }

  Future<void> _addCustomType() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddTypeDialog(),
    );
    if (name == null || name.isEmpty) return;
    final normalized = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
    if (_builtInDbValues.contains(normalized)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That type already exists as a built-in type.'),
        ));
      }
      return;
    }
    if (_customTypeNames.contains(normalized)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A type with that name already exists.'),
        ));
      }
      return;
    }
    if (mounted) setState(() => _customTypeNames.add(normalized));
  }

  // Converts a db key like "yacht_charter" → "Yacht Charter"
  static String _typeDisplayLabel(String dbValue) {
    return dbValue
        .split('_')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Run Sheet Instructions', style: AppTextStyles.heading3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                _HelpBanner(),
                const SizedBox(height: AppSpacing.base),

                // ── Built-in types ─────────────────────────────────────────
                ..._builtInTypes.map((type) {
                  final hasCustom = _hasAnyCustomForBuiltIn(type.dbValue);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.base),
                    child: _TypeSection(
                      componentType: type.dbValue,
                      typeLabel:     type.label,
                      typeColor:     type.color,
                      typeIcon:      type.icon,
                      isBuiltIn:     true,
                      getCustom:     (iType) => _getCustom(type.dbValue, iType),
                      hasAnyCustom:  hasCustom,
                      onEdit: (iType, text) => _openEditDialog(
                          type.dbValue, iType, text,
                          typeLabel: type.label),
                      onDelete:         (iType) => _deleteTemplate(type.dbValue, iType),
                      onImportDefaults: hasCustom ? null : () => _importDefaults(type.dbValue),
                      onDeleteType:     null,
                    ),
                  );
                }),

                // ── Custom types ───────────────────────────────────────────
                ..._customTypeNames.map((typeName) {
                  final label = _typeDisplayLabel(typeName);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.base),
                    child: _TypeSection(
                      componentType: typeName,
                      typeLabel:     label,
                      typeColor:     const Color(0xFF64748B),
                      typeIcon:      Icons.category_rounded,
                      isBuiltIn:     false,
                      getCustom:     (iType) => _getCustom(typeName, iType),
                      hasAnyCustom:  true,
                      onEdit: (iType, text) => _openEditDialog(
                          typeName, iType, text,
                          typeLabel: label),
                      onDelete:         (iType) => _deleteTemplate(typeName, iType),
                      onImportDefaults: null,
                      onDeleteType:     () => _deleteCustomType(typeName),
                    ),
                  );
                }),

                // ── Add type button ────────────────────────────────────────
                _AddTypeButton(onTap: _addCustomType),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

// ── Help banner ───────────────────────────────────────────────────────────────

class _HelpBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Templates pre-fill instruction text when a run sheet item has no '
              'instructions yet. Custom templates override the built-in defaults. '
              'Leave a field blank to revert to the default.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: const Color(0xFF0369A1), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Type button ───────────────────────────────────────────────────────────

class _AddTypeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTypeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border:       Border.all(
              color: AppColors.accent.withAlpha(80), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Add New Type',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

// ── Type section ──────────────────────────────────────────────────────────────

class _TypeSection extends StatelessWidget {
  final String    componentType;
  final String    typeLabel;
  final Color     typeColor;
  final IconData  typeIcon;
  final bool      isBuiltIn;
  final RunSheetInstructionTemplate? Function(InstructionType) getCustom;
  final bool      hasAnyCustom;
  final void Function(InstructionType, String) onEdit;
  final void Function(InstructionType) onDelete;
  final VoidCallback? onImportDefaults;
  final VoidCallback? onDeleteType;

  const _TypeSection({
    required this.componentType,
    required this.typeLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.isBuiltIn,
    required this.getCustom,
    required this.hasAnyCustom,
    required this.onEdit,
    required this.onDelete,
    this.onImportDefaults,
    this.onDeleteType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        typeColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 13, color: typeColor),
                      const SizedBox(width: 5),
                      Text(
                        typeLabel.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color:         typeColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isBuiltIn) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CUSTOM TYPE',
                      style: AppTextStyles.overline.copyWith(
                        color:         AppColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (onImportDefaults != null)
                  TextButton.icon(
                    onPressed: onImportDefaults,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Import defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      textStyle:       AppTextStyles.labelSmall,
                    ),
                  ),
                if (onDeleteType != null)
                  IconButton(
                    icon:    const Icon(Icons.delete_outline_rounded, size: 17),
                    color:   AppColors.statusBlockedText,
                    tooltip: 'Delete this type',
                    onPressed: onDeleteType,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Three instruction rows
          ...InstructionType.values.map((iType) {
            final custom      = getCustom(iType);
            final defaultText = DefaultInstructionTemplates.textFor(
                componentType, iType);
            final displayText = custom?.templateText ?? defaultText;
            final isCustomRow = custom != null;

            return _InstructionRow(
              iType:    iType,
              text:     displayText,
              isCustom: isCustomRow,
              onEdit:   () => onEdit(iType, displayText),
              onDelete: isCustomRow ? () => onDelete(iType) : null,
            );
          }),
        ],
      ),
    );
  }
}

// ── Instruction row ───────────────────────────────────────────────────────────

class _InstructionRow extends StatelessWidget {
  final InstructionType iType;
  final String          text;
  final bool            isCustom;
  final VoidCallback    onEdit;
  final VoidCallback?   onDelete;

  const _InstructionRow({
    required this.iType,
    required this.text,
    required this.isCustom,
    required this.onEdit,
    this.onDelete,
  });

  static const _config = {
    InstructionType.operational: (
      Color(0xFF1E40AF),
      Color(0xFFBFDBFE),
      Color(0xFFEFF6FF),
    ),
    InstructionType.contingency: (
      Color(0xFF92400E),
      Color(0xFFFDE68A),
      Color(0xFFFFFBEB),
    ),
    InstructionType.escalation: (
      Color(0xFF991B1B),
      Color(0xFFFECACA),
      Color(0xFFFEF2F2),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (textColor, borderColor, bgColor) = _config[iType]!;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        bgColor,
                        borderRadius: BorderRadius.circular(4),
                        border:       Border.all(color: borderColor),
                      ),
                      child: Text(
                        iType.label.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color:         textColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFD2F5E4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CUSTOM',
                          style: AppTextStyles.overline.copyWith(
                            color:         const Color(0xFF065F46),
                            letterSpacing: 0.6,
                          ),
                        ),
                      )
                    else
                      Text('default',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text.isEmpty ? '—' : text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: text.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon:      const Icon(Icons.edit_outlined, size: 16),
                color:     AppColors.textMuted,
                tooltip:   'Edit',
                onPressed: onEdit,
              ),
              if (onDelete != null)
                IconButton(
                  icon:      const Icon(Icons.delete_outline_rounded, size: 16),
                  color:     AppColors.statusBlockedText,
                  tooltip:   'Remove custom (reverts to default)',
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add Type dialog ───────────────────────────────────────────────────────────

class _AddTypeDialog extends StatefulWidget {
  const _AddTypeDialog();

  @override
  State<_AddTypeDialog> createState() => _AddTypeDialogState();
}

class _AddTypeDialogState extends State<_AddTypeDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate(String v) {
    setState(() {
      _error = v.trim().isEmpty
          ? null
          : RegExp(r'^[a-zA-Z][a-zA-Z0-9 _]*$').hasMatch(v.trim())
              ? null
              : 'Only letters, numbers, spaces and underscores allowed';
    });
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty || _error != null) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      title: Text('Add New Type', style: AppTextStyles.heading3),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a name for the new component type (e.g. "Yacht Charter", "Spa", "Museum").',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller:  _ctrl,
              autofocus:   true,
              style:       AppTextStyles.bodyMedium,
              textCapitalization: TextCapitalization.words,
              onChanged:   _validate,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText:  'e.g. Yacht Charter',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
                errorText: _error,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                filled:    true,
                fillColor: AppColors.background,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── Edit instruction dialog ───────────────────────────────────────────────────

class _EditInstructionDialog extends StatefulWidget {
  final String          typeLabel;
  final InstructionType instructionType;
  final String          initialText;

  const _EditInstructionDialog({
    required this.typeLabel,
    required this.instructionType,
    required this.initialText,
  });

  @override
  State<_EditInstructionDialog> createState() => _EditInstructionDialogState();
}

class _EditInstructionDialogState extends State<_EditInstructionDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iType = widget.instructionType;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${iType.label} Instructions', style: AppTextStyles.heading3),
          const SizedBox(height: 2),
          Text(widget.typeLabel,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Each line will appear as a bullet point. Leave blank to revert to the built-in default.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ctrl,
              maxLines:   10,
              minLines:   6,
              autofocus:  true,
              style:      AppTextStyles.bodySmall.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText:  'Enter instructions…',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
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
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                filled:    true,
                fillColor: AppColors.background,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
