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
//
// Admin screen for managing per-component-type instruction templates.
// Displays sections for hotel, transport, flight, dining, experience.
// Each section shows three instruction type blocks (operational / contingency /
// escalation).  Templates can be edited or imported from built-in defaults.
// =============================================================================

class RunSheetInstructionTemplateScreen extends StatefulWidget {
  const RunSheetInstructionTemplateScreen({super.key});

  @override
  State<RunSheetInstructionTemplateScreen> createState() =>
      _RunSheetInstructionTemplateScreenState();
}

class _RunSheetInstructionTemplateScreenState
    extends State<RunSheetInstructionTemplateScreen> {
  // component types that support instruction templates
  static const _supportedTypes = [
    ItemType.hotel,
    ItemType.transport,
    ItemType.flight,
    ItemType.dining,
    ItemType.experience,
  ];

  RunSheetInstructionTemplateRepository? get _repo =>
      AppRepositories.instance?.runSheetInstructionTemplates;
  String? get _teamId => AppRepositories.instance?.currentTeamId;

  // Map keyed by "componentType:instructionType" → template (null = no custom)
  final Map<String, RunSheetInstructionTemplate> _customTemplates = {};
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
      for (final r in rows) {
        final key = '${r.componentType}:${r.instructionType.dbValue}';
        map[key] = r;
      }
      if (mounted) setState(() { _customTemplates
        ..clear()
        ..addAll(map);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load templates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  RunSheetInstructionTemplate? _getCustom(
      String componentType, InstructionType iType) {
    return _customTemplates['$componentType:${iType.dbValue}'];
  }

  bool _hasAnyCustom(String componentType) => _supportedTypes
      .where((t) => t.dbValue == componentType)
      .isNotEmpty &&
      InstructionType.values.any(
          (i) => _customTemplates.containsKey('$componentType:${i.dbValue}'));

  Future<void> _saveTemplate(
    String componentType,
    InstructionType iType,
    String text,
  ) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    String componentType,
    InstructionType iType,
    String currentText,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditInstructionDialog(
        componentType:   componentType,
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
                ..._supportedTypes.map((type) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.base),
                      child: _TypeSection(
                        itemType:      type,
                        getCustom:     (iType) =>
                            _getCustom(type.dbValue, iType),
                        hasAnyCustom:  _hasAnyCustom(type.dbValue),
                        onEdit:        (iType, text) =>
                            _openEditDialog(type.dbValue, iType, text),
                        onDelete:      (iType) =>
                            _deleteTemplate(type.dbValue, iType),
                        onImportDefaults: () =>
                            _importDefaults(type.dbValue),
                      ),
                    )),
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

// ── Type section ──────────────────────────────────────────────────────────────

class _TypeSection extends StatelessWidget {
  final ItemType itemType;
  final RunSheetInstructionTemplate? Function(InstructionType) getCustom;
  final bool hasAnyCustom;
  final void Function(InstructionType, String) onEdit;
  final void Function(InstructionType) onDelete;
  final VoidCallback onImportDefaults;

  const _TypeSection({
    required this.itemType,
    required this.getCustom,
    required this.hasAnyCustom,
    required this.onEdit,
    required this.onDelete,
    required this.onImportDefaults,
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        itemType.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(itemType.icon, size: 13, color: itemType.color),
                      const SizedBox(width: 5),
                      Text(
                        itemType.label.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color:         itemType.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!hasAnyCustom)
                  TextButton.icon(
                    onPressed: onImportDefaults,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Import defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      textStyle: AppTextStyles.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Instruction rows
          ...InstructionType.values.map((iType) {
            final custom = getCustom(iType);
            final defaultText = DefaultInstructionTemplates.textFor(
                itemType.dbValue, iType);
            final displayText = custom?.templateText ?? defaultText;
            final isCustom    = custom != null;

            return _InstructionRow(
              iType:       iType,
              text:        displayText,
              isCustom:    isCustom,
              onEdit:      () => onEdit(iType, displayText),
              onDelete:    isCustom ? () => onDelete(iType) : null,
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
          // Type label + content
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
                      Text(
                        'default',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text.isEmpty ? '—' : text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color:  text.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                    height: 1.5,
                  ),
                  maxLines:  4,
                  overflow:  TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon:    const Icon(Icons.edit_outlined, size: 16),
                color:   AppColors.textMuted,
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              if (onDelete != null)
                IconButton(
                  icon:    const Icon(Icons.delete_outline_rounded, size: 16),
                  color:   AppColors.statusBlockedText,
                  tooltip: 'Remove custom (reverts to default)',
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditInstructionDialog extends StatefulWidget {
  final String          componentType;
  final InstructionType instructionType;
  final String          initialText;

  const _EditInstructionDialog({
    required this.componentType,
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
          Text(
            '${iType.label} Instructions',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 2),
          Text(
            ItemType.values
                .firstWhere(
                    (t) => t.dbValue == widget.componentType,
                    orElse: () => ItemType.note)
                .label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textMuted),
          ),
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
              controller:   _ctrl,
              maxLines:     10,
              minLines:     6,
              autofocus:    true,
              style:        AppTextStyles.bodySmall.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText:  'Enter instructions…',
                hintStyle: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
                contentPadding:
                    const EdgeInsets.all(AppSpacing.md),
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
                  borderSide:   const BorderSide(
                      color: AppColors.accent, width: 1.5),
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
                borderRadius:
                    BorderRadius.circular(AppSpacing.buttonRadius)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
