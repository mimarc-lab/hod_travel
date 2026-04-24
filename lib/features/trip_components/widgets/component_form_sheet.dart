import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../providers/components_provider.dart';
import 'component_linking_dialog.dart';

Future<void> showComponentFormSheet(
  BuildContext context, {
  required Trip trip,
  required ComponentsProvider provider,
  TripComponent? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComponentFormSheet(
      trip:     trip,
      provider: provider,
      existing: existing,
    ),
  );
}

class _ComponentFormSheet extends StatefulWidget {
  final Trip                 trip;
  final ComponentsProvider   provider;
  final TripComponent?       existing;

  const _ComponentFormSheet({
    required this.trip,
    required this.provider,
    this.existing,
  });

  @override
  State<_ComponentFormSheet> createState() => _ComponentFormSheetState();
}

class _ComponentFormSheetState extends State<_ComponentFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late ComponentType   _type;
  late ComponentStatus _status;
  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesInternalCtrl;
  late TextEditingController _notesClientCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type              = e?.componentType ?? ComponentType.accommodation;
    _status            = e?.status        ?? ComponentStatus.proposed;
    _titleCtrl         = TextEditingController(text: e?.title ?? '');
    _locationCtrl      = TextEditingController(text: e?.locationName ?? '');
    _addressCtrl       = TextEditingController(text: e?.address ?? '');
    _notesInternalCtrl = TextEditingController(text: e?.notesInternal ?? '');
    _notesClientCtrl   = TextEditingController(text: e?.notesClient ?? '');
    _startDate         = e?.startDate;
    _endDate           = e?.endDate;
    _startTime         = _parseTime(e?.startTime);
    _endTime           = _parseTime(e?.endTime);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _notesInternalCtrl.dispose();
    _notesClientCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final prevStatus = widget.existing?.status;
    final statusChanged = prevStatus != _status;
    final needsLinkingPrompt = statusChanged && _status.requiresLinkingPrompt;

    final component = TripComponent(
      id:              widget.existing?.id ?? '',
      tripId:          widget.trip.id,
      teamId:          provider.teamId ?? '',
      componentType:   _type,
      status:          _status,
      title:           _titleCtrl.text.trim(),
      supplierId:      widget.existing?.supplierId,
      supplierName:    widget.existing?.supplierName,
      startDate:       _startDate,
      endDate:         _endDate,
      startTime:       _startTime != null ? _formatTimeOfDay(_startTime!) : null,
      endTime:         _endTime   != null ? _formatTimeOfDay(_endTime!)   : null,
      locationName:    _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      address:         _addressCtrl.text.trim().isEmpty  ? null : _addressCtrl.text.trim(),
      notesInternal:   _notesInternalCtrl.text.trim().isEmpty ? null : _notesInternalCtrl.text.trim(),
      notesClient:     _notesClientCtrl.text.trim().isEmpty   ? null : _notesClientCtrl.text.trim(),
      costItemId:      widget.existing?.costItemId,
      itineraryItemId: widget.existing?.itineraryItemId,
      runSheetItemId:  widget.existing?.runSheetItemId,
      createdBy:       widget.existing?.createdBy,
      createdAt:       widget.existing?.createdAt ?? DateTime.now(),
      updatedAt:       DateTime.now(),
    );

    TripComponent? saved;
    if (_isEditing) {
      saved = await provider.updateComponent(component);
    } else {
      saved = await provider.addComponent(component);
    }

    setState(() => _saving = false);

    if (!mounted) return;

    // Show linking dialog while still in context, then close the sheet
    if (saved != null && needsLinkingPrompt) {
      await showComponentLinkingDialog(context, component: saved!);
      // Linking dialog result is informational only — actual linking not yet automated
    }

    if (mounted) Navigator.of(context).pop();
  }

  ComponentsProvider get provider => widget.provider;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH,
              vertical:   AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  _isEditing ? 'Edit Component' : 'Add Component',
                  style: AppTextStyles.heading2,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Form body
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingH,
                  vertical:   AppSpacing.base,
                ),
                children: [
                  // Type selector
                  _SectionLabel('Type'),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeSelector(selected: _type, onChanged: (t) => setState(() => _type = t)),
                  const SizedBox(height: AppSpacing.base),

                  // Status
                  _SectionLabel('Status'),
                  const SizedBox(height: AppSpacing.sm),
                  _StatusSelector(selected: _status, onChanged: (s) => setState(() => _status = s)),
                  const SizedBox(height: AppSpacing.base),

                  // Title
                  _SectionLabel('Title *'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('e.g. Mulia Resort – Deluxe Villa'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Dates row
                  _SectionLabel('Dates'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label:    'Start Date',
                          value:    _startDate,
                          onPicked: (d) => setState(() { _startDate = d; if (_endDate == null) _endDate = d; }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DateField(
                          label:    'End Date',
                          value:    _endDate,
                          onPicked: (d) => setState(() => _endDate = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Times row
                  _SectionLabel('Times'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label:    'Start Time',
                          value:    _startTime,
                          onPicked: (t) => setState(() => _startTime = t),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TimeField(
                          label:    'End Time',
                          value:    _endTime,
                          onPicked: (t) => setState(() => _endTime = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Location
                  _SectionLabel('Location'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration: _inputDecoration('Venue / property name'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: _inputDecoration('Full address'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Internal notes
                  _SectionLabel('Internal Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _notesInternalCtrl,
                    decoration: _inputDecoration('Notes visible to team only'),
                    maxLines: 3,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Client notes
                  _SectionLabel('Client Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _notesClientCtrl,
                    decoration: _inputDecoration('Notes visible to client'),
                    maxLines: 3,
                    style: AppTextStyles.bodyMedium,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.overline,
      );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );

// ── Type selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final ComponentType selected;
  final ValueChanged<ComponentType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: ComponentType.values.map((t) {
        final isSelected = t == selected;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:  isSelected ? t.bgColor : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              border: Border.all(
                color: isSelected ? t.color.withAlpha(120) : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.icon, size: 13, color: isSelected ? t.color : AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  t.label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? t.color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Status selector ───────────────────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final ComponentStatus selected;
  final ValueChanged<ComponentStatus> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ComponentStatus.values.map((s) {
        final isSelected = s == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: EdgeInsets.only(right: s != ComponentStatus.values.last ? AppSpacing.xs : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color:  isSelected ? s.bgColor : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                border: Border.all(
                  color: isSelected ? s.color.withAlpha(120) : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? s.color : AppColors.textMuted,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _DateField({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context:     context,
          initialDate: value ?? DateTime.now(),
          firstDate:   DateTime(2020),
          lastDate:    DateTime(2035),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null ? DateFormat('d MMM yyyy').format(value!) : label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time field ────────────────────────────────────────────────────────────────

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPicked;

  const _TimeField({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context:     context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null ? value!.format(context) : label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: value != null ? AppColors.textPrimary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
