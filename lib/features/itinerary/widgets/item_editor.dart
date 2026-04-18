import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../features/ai_suggestions/services/suggestion_apply_service.dart';
import '../../../features/signature_experiences/widgets/signature_experience_picker_modal.dart';
import '../providers/itinerary_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a dialog (desktop) or bottom sheet (mobile) for adding/editing an item.
/// Pass [existing] to edit; pass [dayId] to add a new item.
/// Pass [prefill] to pre-populate a new item's fields (e.g. from an AI suggestion).
void showItemEditor(
  BuildContext context, {
  required ItineraryProvider provider,
  ItineraryItem? existing,
  String? dayId,
  ItemPrefill? prefill,
}) {
  assert(existing != null || dayId != null,
      'Provide either an existing item or a dayId for a new item.');

  final isMobile = MediaQuery.sizeOf(context).width < 600;

  if (isMobile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => _ItemEditorForm(
          scrollController: scrollCtrl,
          provider: provider,
          existing: existing,
          dayId: dayId ?? existing!.tripDayId,
          prefill: prefill,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: _ItemEditorForm(
            provider: provider,
            existing: existing,
            dayId: dayId ?? existing!.tripDayId,
            prefill: prefill,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ItemEditorForm
// ─────────────────────────────────────────────────────────────────────────────

class _ItemEditorForm extends StatefulWidget {
  final ItineraryProvider provider;
  final ItineraryItem? existing;
  final String dayId;
  final ScrollController? scrollController;
  /// Pre-populated values for a new item (ignored when [existing] is set).
  final ItemPrefill? prefill;

  const _ItemEditorForm({
    required this.provider,
    required this.existing,
    required this.dayId,
    this.scrollController,
    this.prefill,
  });

  @override
  State<_ItemEditorForm> createState() => _ItemEditorFormState();
}

class _ItemEditorFormState extends State<_ItemEditorForm> {
  late ItemType _type;
  late ItemStatus _status;
  late TimeBlock _timeBlock;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _notesCtrl;

  bool get _isEditing => widget.existing != null;
  bool _saving = false;
  bool _titleError = false;

  Future<void> _pickFromLibrary() async {
    final experience = await showSignatureExperiencePicker(context);
    if (experience == null || !mounted) return;
    _titleCtrl.text = experience.title;
    if (experience.shortDescriptionClient != null &&
        experience.shortDescriptionClient!.isNotEmpty) {
      _descriptionCtrl.text = experience.shortDescriptionClient!;
    }
    setState(() {
      _type = ItemType.experience;
      _titleError = false;
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.prefill; // AI suggestion prefill (only used for new items)

    _type      = e?.type      ?? _itemTypeFromPrefill(p) ?? ItemType.experience;
    _status    = e?.status    ?? ItemStatus.draft;
    _timeBlock = e?.timeBlock ?? _timeBlockFromPrefill(p) ?? TimeBlock.morning;
    _startTime = e?.startTime;
    _endTime   = e?.endTime;

    _titleCtrl       = TextEditingController(text: e?.title        ?? p?.title        ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description  ?? p?.description  ?? '');
    _locationCtrl    = TextEditingController(text: e?.location     ?? p?.location     ?? '');
    _supplierCtrl    = TextEditingController(text: e?.supplierName ?? '');
    _notesCtrl       = TextEditingController(text: e?.notes        ?? '');
  }

  ItemType? _itemTypeFromPrefill(ItemPrefill? p) => p?.type;

  TimeBlock? _timeBlockFromPrefill(ItemPrefill? p) => p?.timeBlock;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    debugPrint('[ItemEditor._save] called, isEditing=$_isEditing dayId=${widget.dayId}');
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      debugPrint('[ItemEditor._save] BAIL: title is empty');
      setState(() => _titleError = true);
      return;
    }
    setState(() { _saving = true; _titleError = false; });
    debugPrint('[ItemEditor._save] calling provider, title=$title');

    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          type: _type,
          title: title,
          description: _descriptionCtrl.text.trim(),
          clearDescription: _descriptionCtrl.text.trim().isEmpty,
          startTime: _startTime,
          clearStartTime: _startTime == null,
          endTime: _endTime,
          clearEndTime: _endTime == null,
          timeBlock: _timeBlock,
          location: _locationCtrl.text.trim(),
          clearLocation: _locationCtrl.text.trim().isEmpty,
          supplierName: _supplierCtrl.text.trim(),
          clearSupplierName: _supplierCtrl.text.trim().isEmpty,
          status: _status,
          notes: _notesCtrl.text.trim(),
          clearNotes: _notesCtrl.text.trim().isEmpty,
        );
        await widget.provider.updateItem(updated);
      } else {
        final desc     = _descriptionCtrl.text.trim();
        final location = _locationCtrl.text.trim();
        final supplier = _supplierCtrl.text.trim();
        final notes    = _notesCtrl.text.trim();

        final item = ItineraryItem(
          id: widget.provider.generateItemId(),
          tripDayId: widget.dayId,
          type: _type,
          title: title,
          description: desc.isEmpty ? null : desc,
          startTime: _startTime,
          endTime: _endTime,
          timeBlock: _timeBlock,
          location: location.isEmpty ? null : location,
          supplierName: supplier.isEmpty ? null : supplier,
          status: _status,
          notes: notes.isEmpty ? null : notes,
        );
        await widget.provider.addItem(item);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.provider.error ?? e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(isEditing: _isEditing),
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
            child: GestureDetector(
              onTap: _pickFromLibrary,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentFaint,
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                  border: Border.all(color: AppColors.accentLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('Pick from Experience Library',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.accentDark)),
                  ],
                ),
              ),
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                _EditorField(
                  label: 'TITLE',
                  child: _textField(
                    _titleCtrl,
                    'e.g. Private boat transfer',
                    maxLines: 1,
                    hasError: _titleError,
                  ),
                ),
                if (_titleError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Title is required',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade400),
                    ),
                  ),
                const SizedBox(height: AppSpacing.base),

                // Type + Status row
                Row(
                  children: [
                    Expanded(
                      child: _EditorField(
                        label: 'TYPE',
                        child: _TypeDropdown(
                          value: _type,
                          onChanged: (v) => setState(() => _type = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: _EditorField(
                        label: 'STATUS',
                        child: _StatusDropdown(
                          value: _status,
                          onChanged: (v) => setState(() => _status = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // Time block + start/end
                _EditorField(
                  label: 'TIME BLOCK',
                  child: _TimeBlockDropdown(
                    value: _timeBlock,
                    onChanged: (v) => setState(() => _timeBlock = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                Row(
                  children: [
                    Expanded(
                      child: _EditorField(
                        label: 'START TIME',
                        child: _TimePicker(
                          value: _startTime,
                          hint: 'Select',
                          onChanged: (t) => setState(() => _startTime = t),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    Expanded(
                      child: _EditorField(
                        label: 'END TIME',
                        child: _TimePicker(
                          value: _endTime,
                          hint: 'Optional',
                          onChanged: (t) => setState(() => _endTime = t),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // Location + Supplier
                _EditorField(
                  label: 'LOCATION',
                  child: _textField(_locationCtrl, 'Address or venue name'),
                ),
                const SizedBox(height: AppSpacing.base),

                _EditorField(
                  label: 'SUPPLIER',
                  child: _textField(_supplierCtrl, 'Supplier or operator name'),
                ),
                const SizedBox(height: AppSpacing.base),

                // Description
                _EditorField(
                  label: 'DESCRIPTION',
                  child: _textField(_descriptionCtrl, 'Additional details…', maxLines: 3),
                ),
                const SizedBox(height: AppSpacing.base),

                // Notes
                _EditorField(
                  label: 'INTERNAL NOTES',
                  child: _textField(_notesCtrl, 'Notes for the ops team…', maxLines: 2),
                ),
              ],
            ),
          ),
        ),

        // Action buttons
        _EditorFooter(onSave: _saving ? null : _save, saving: _saving),
      ],
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool hasError = false,
  }) {
    final errorColor = Colors.red.shade400;
    return TextField(
      controller: ctrl,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      maxLines: maxLines,
      minLines: 1,
      onChanged: hasError ? (_) => setState(() => _titleError = false) : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? errorColor : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hasError ? errorColor : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: hasError ? errorColor : AppColors.accent,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EditorHeader extends StatelessWidget {
  final bool isEditing;
  const _EditorHeader({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            isEditing ? 'Edit Item' : 'Add Itinerary Item',
            style: AppTextStyles.heading3,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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

class _EditorFooter extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;
  const _EditorFooter({required this.onSave, this.saving = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  final String label;
  final Widget child;
  const _EditorField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

// ── Dropdowns ─────────────────────────────────────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  final ItemType value;
  final ValueChanged<ItemType> onChanged;
  const _TypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StyledDropdown<ItemType>(
      value: value,
      items: ItemType.values,
      labelOf: (t) => t.label,
      onChanged: onChanged,
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final ItemStatus value;
  final ValueChanged<ItemStatus> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StyledDropdown<ItemStatus>(
      value: value,
      items: ItemStatus.values,
      labelOf: (s) => s.label,
      onChanged: onChanged,
    );
  }
}

class _TimeBlockDropdown extends StatelessWidget {
  final TimeBlock value;
  final ValueChanged<TimeBlock> onChanged;
  const _TimeBlockDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StyledDropdown<TimeBlock>(
      value: value,
      items: TimeBlock.values,
      labelOf: (b) => b.label,
      onChanged: onChanged,
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          dropdownColor: AppColors.surface,
          icon: const Icon(Icons.expand_more_rounded,
              size: 16, color: AppColors.textSecondary),
          onChanged: (v) { if (v != null) onChanged(v); },
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelOf(item)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Time picker ───────────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  final TimeOfDay? value;
  final String hint;
  final ValueChanged<TimeOfDay?> onChanged;

  const _TimePicker({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? hint
        : value!.format(context);

    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: value == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              )
            else
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
