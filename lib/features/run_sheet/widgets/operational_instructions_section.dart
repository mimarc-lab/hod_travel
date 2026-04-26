import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/models/run_sheet_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OperationalInstructionsSection
//
// Displays the three instruction slots (operational / contingency / escalation)
// for a RunSheetItem. Handles four states:
//   1. suggestAvailable — suggestions ready but not yet reviewed
//   2. editing          — text fields open for manual or pre-filled edit
//   3. saving           — async save in progress
//   4. idle             — read mode (instructions present or empty)
// ─────────────────────────────────────────────────────────────────────────────

enum _InstructionPhase { idle, suggestAvailable, editing, saving }

class OperationalInstructionsSection extends StatefulWidget {
  final RunSheetItem          item;
  final SuggestedInstructions? suggestions;

  /// Called with (operational, contingency, escalation, source) when user saves.
  final Future<void> Function(
    String? operational,
    String? contingency,
    String? escalation,
    InstructionsSource source,
  ) onSave;

  const OperationalInstructionsSection({
    super.key,
    required this.item,
    required this.suggestions,
    required this.onSave,
  });

  @override
  State<OperationalInstructionsSection> createState() =>
      _OperationalInstructionsSectionState();
}

class _OperationalInstructionsSectionState
    extends State<OperationalInstructionsSection> {
  late _InstructionPhase _phase;
  late final TextEditingController _opCtrl;
  late final TextEditingController _conCtrl;
  late final TextEditingController _escCtrl;

  @override
  void initState() {
    super.initState();
    _opCtrl  = TextEditingController(text: widget.item.operationalInstructions ?? '');
    _conCtrl = TextEditingController(text: widget.item.contingencyInstructions ?? '');
    _escCtrl = TextEditingController(text: widget.item.escalationInstructions  ?? '');

    _phase = (!widget.item.hasInstructions && widget.suggestions != null)
        ? _InstructionPhase.suggestAvailable
        : _InstructionPhase.idle;
  }

  @override
  void dispose() {
    _opCtrl.dispose();
    _conCtrl.dispose();
    _escCtrl.dispose();
    super.dispose();
  }

  void _startEditWithSuggestions() {
    _opCtrl.text  = widget.suggestions?.operational ?? '';
    _conCtrl.text = widget.suggestions?.contingency  ?? '';
    _escCtrl.text = widget.suggestions?.escalation   ?? '';
    setState(() => _phase = _InstructionPhase.editing);
  }

  void _startEditManual() {
    _opCtrl.text  = widget.item.operationalInstructions ?? '';
    _conCtrl.text = widget.item.contingencyInstructions ?? '';
    _escCtrl.text = widget.item.escalationInstructions  ?? '';
    setState(() => _phase = _InstructionPhase.editing);
  }

  Future<void> _approve() async {
    setState(() => _phase = _InstructionPhase.saving);
    try {
      await widget.onSave(
        widget.suggestions!.operational,
        widget.suggestions!.contingency,
        widget.suggestions!.escalation,
        InstructionsSource.suggested,
      );
      setState(() => _phase = _InstructionPhase.idle);
    } catch (_) {
      setState(() => _phase = _InstructionPhase.suggestAvailable);
    }
  }

  Future<void> _saveEdited() async {
    final op  = _opCtrl.text.trim();
    final con = _conCtrl.text.trim();
    final esc = _escCtrl.text.trim();
    setState(() => _phase = _InstructionPhase.saving);
    final hadSuggestion = widget.suggestions != null;
    try {
      await widget.onSave(
        op.isEmpty  ? null : op,
        con.isEmpty ? null : con,
        esc.isEmpty ? null : esc,
        hadSuggestion
            ? InstructionsSource.editedAfterSuggestion
            : InstructionsSource.manual,
      );
      setState(() => _phase = _InstructionPhase.idle);
    } catch (_) {
      setState(() => _phase = _InstructionPhase.editing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          hasInstructions: widget.item.hasInstructions,
          phase:           _phase,
          onEdit:          _startEditManual,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_phase == _InstructionPhase.suggestAvailable)
          _SuggestionBanner(
            suggestions: widget.suggestions!,
            onApprove:   _approve,
            onEditFirst: _startEditWithSuggestions,
            onDismiss:   () => setState(() => _phase = _InstructionPhase.idle),
          )
        else if (_phase == _InstructionPhase.editing ||
                 _phase == _InstructionPhase.saving)
          _EditForm(
            opCtrl:   _opCtrl,
            conCtrl:  _conCtrl,
            escCtrl:  _escCtrl,
            saving:   _phase == _InstructionPhase.saving,
            onSave:   _saveEdited,
            onCancel: () => setState(() => _phase = _InstructionPhase.idle),
          )
        else
          _ReadView(item: widget.item, onEdit: _startEditManual),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final bool               hasInstructions;
  final _InstructionPhase  phase;
  final VoidCallback        onEdit;
  const _SectionHeader({
    required this.hasInstructions,
    required this.phase,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.checklist_rounded, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('INSTRUCTIONS',
            style: AppTextStyles.overline.copyWith(letterSpacing: 1.2)),
        const Spacer(),
        if (phase == _InstructionPhase.idle && hasInstructions)
          GestureDetector(
            onTap: onEdit,
            child: Text(
              'Edit',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (phase == _InstructionPhase.idle && !hasInstructions)
          GestureDetector(
            onTap: onEdit,
            child: Text(
              '+ Add manually',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Suggestion banner ──────────────────────────────────────────────────────

class _SuggestionBanner extends StatelessWidget {
  final SuggestedInstructions suggestions;
  final VoidCallback onApprove;
  final VoidCallback onEditFirst;
  final VoidCallback onDismiss;

  const _SuggestionBanner({
    required this.suggestions,
    required this.onApprove,
    required this.onEditFirst,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: const Color(0xFF0F766E).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 13, color: Color(0xFF0F766E)),
              const SizedBox(width: 6),
              Text(
                'Suggested Instructions Available',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFF0F766E)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PreviewRow(label: 'Operational', text: suggestions.operational),
          if (suggestions.contingency.isNotEmpty) ...[
            const SizedBox(height: 6),
            _PreviewRow(label: 'Contingency', text: suggestions.contingency),
          ],
          if (suggestions.escalation.isNotEmpty) ...[
            const SizedBox(height: 6),
            _PreviewRow(label: 'Escalation', text: suggestions.escalation),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEditFirst,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  child: const Text('Edit First'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: AppTextStyles.labelMedium,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String text;
  const _PreviewRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color:         const Color(0xFF0F766E),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: AppTextStyles.bodySmall
              .copyWith(color: const Color(0xFF134E4A), height: 1.5),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Edit form ──────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final TextEditingController opCtrl;
  final TextEditingController conCtrl;
  final TextEditingController escCtrl;
  final bool         saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditForm({
    required this.opCtrl,
    required this.conCtrl,
    required this.escCtrl,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InstructionField(
          label:      'Operational Instructions',
          hint:       'e.g. Driver arrive 15 mins early',
          controller: opCtrl,
          enabled:    !saving,
        ),
        const SizedBox(height: AppSpacing.sm),
        _InstructionField(
          label:      'Contingency Instructions',
          hint:       'e.g. If delay exceeds 20 mins notify Trip Director',
          controller: conCtrl,
          enabled:    !saving,
        ),
        const SizedBox(height: AppSpacing.sm),
        _InstructionField(
          label:      'Escalation Instructions',
          hint:       'e.g. Escalate to Trip Director immediately',
          controller: escCtrl,
          enabled:    !saving,
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: saving ? null : onCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: 10),
              ),
              child: saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Instructions'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InstructionField extends StatelessWidget {
  final String                label;
  final String                hint;
  final TextEditingController controller;
  final bool                  enabled;
  const _InstructionField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller:  controller,
          enabled:     enabled,
          maxLines:    4,
          minLines:    2,
          style:       AppTextStyles.bodySmall.copyWith(height: 1.5),
          decoration:  InputDecoration(
            hintText:        hint,
            hintStyle:       AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted),
            contentPadding:  const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:   const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:   const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:   BorderSide(color: AppColors.accent, width: 1.5),
            ),
            filled:      true,
            fillColor:   AppColors.surface,
          ),
        ),
      ],
    );
  }
}

// ── Read view ──────────────────────────────────────────────────────────────

class _ReadView extends StatelessWidget {
  final RunSheetItem item;
  final VoidCallback onEdit;
  const _ReadView({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (!item.hasInstructions) {
      return Text(
        'No instructions added.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.operationalInstructions?.isNotEmpty ?? false)
          _PlainInstructionBlock(
            label: 'Operational',
            text:  item.operationalInstructions!,
          ),
        if (item.contingencyInstructions?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          _PlainInstructionBlock(
            label: 'Contingency',
            text:  item.contingencyInstructions!,
          ),
        ],
        if (item.escalationInstructions?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          _PlainInstructionBlock(
            label: 'Escalation',
            text:  item.escalationInstructions!,
          ),
        ],
        if (item.instructionsSource != null) ...[
          const SizedBox(height: 6),
          _SourceBadge(source: item.instructionsSource!),
        ],
      ],
    );
  }
}

class _PlainInstructionBlock extends StatelessWidget {
  final String label;
  final String text;
  const _PlainInstructionBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color:         AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final InstructionsSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      InstructionsSource.manual                => 'Manually entered',
      InstructionsSource.suggested             => 'Template approved',
      InstructionsSource.editedAfterSuggestion => 'Template — edited',
    };
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 10, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: AppTextStyles.overline
                .copyWith(color: AppColors.textMuted, fontSize: 9)),
      ],
    );
  }
}
