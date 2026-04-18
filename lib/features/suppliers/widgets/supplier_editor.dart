import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import 'supplier_badges.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the supplier editor in a dialog (desktop) or bottom sheet (mobile).
/// Pass [existing] to edit; omit to create a new supplier.
void showSupplierEditor(
  BuildContext context, {
  required SupplierProvider provider,
  Supplier? existing,
}) {
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
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, ctrl) => _SupplierEditorForm(
          scrollController: ctrl,
          provider: provider,
          existing: existing,
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
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          child: _SupplierEditorForm(provider: provider, existing: existing),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SupplierEditorForm
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierEditorForm extends StatefulWidget {
  final SupplierProvider provider;
  final Supplier? existing;
  final ScrollController? scrollController;

  const _SupplierEditorForm({
    required this.provider,
    this.existing,
    this.scrollController,
  });

  @override
  State<_SupplierEditorForm> createState() => _SupplierEditorFormState();
}

class _SupplierEditorFormState extends State<_SupplierEditorForm> {
  late SupplierCategory _category;
  late double _rating;
  late bool _preferred;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _tagsCtrl;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category  = e?.category       ?? SupplierCategory.hotel;
    _rating    = e?.internalRating  ?? 3.0;
    _preferred = e?.preferred       ?? false;

    _nameCtrl         = TextEditingController(text: e?.name          ?? '');
    _cityCtrl         = TextEditingController(text: e?.city          ?? '');
    _countryCtrl      = TextEditingController(text: e?.country       ?? '');
    _locationCtrl     = TextEditingController(text: e?.location      ?? '');
    _contactNameCtrl  = TextEditingController(text: e?.contactName   ?? '');
    _contactEmailCtrl = TextEditingController(text: e?.contactEmail  ?? '');
    _contactPhoneCtrl = TextEditingController(text: e?.contactPhone  ?? '');
    _websiteCtrl      = TextEditingController(text: e?.website       ?? '');
    _notesCtrl        = TextEditingController(text: e?.notes         ?? '');
    _tagsCtrl         = TextEditingController(text: e?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl, _cityCtrl, _countryCtrl, _locationCtrl,
      _contactNameCtrl, _contactEmailCtrl, _contactPhoneCtrl,
      _websiteCtrl, _notesCtrl, _tagsCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<String> _parseTags(String raw) =>
      raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final city    = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    if (city.isEmpty || country.isEmpty) return;

    String? nul(String v) => v.isEmpty ? null : v;

    if (_isEditing) {
      widget.provider.updateSupplier(widget.existing!.copyWith(
        name: name,
        category: _category,
        city: city,
        country: country,
        location: nul(_locationCtrl.text.trim()),
        clearLocation: _locationCtrl.text.trim().isEmpty,
        contactName: nul(_contactNameCtrl.text.trim()),
        clearContactName: _contactNameCtrl.text.trim().isEmpty,
        contactEmail: nul(_contactEmailCtrl.text.trim()),
        clearContactEmail: _contactEmailCtrl.text.trim().isEmpty,
        contactPhone: nul(_contactPhoneCtrl.text.trim()),
        clearContactPhone: _contactPhoneCtrl.text.trim().isEmpty,
        preferred: _preferred,
        internalRating: _rating,
        notes: nul(_notesCtrl.text.trim()),
        clearNotes: _notesCtrl.text.trim().isEmpty,
        website: nul(_websiteCtrl.text.trim()),
        clearWebsite: _websiteCtrl.text.trim().isEmpty,
        tags: _parseTags(_tagsCtrl.text),
      ));
    } else {
      widget.provider.addSupplier(Supplier(
        id: '',
        name: name,
        category: _category,
        city: city,
        country: country,
        location: nul(_locationCtrl.text.trim()),
        contactName: nul(_contactNameCtrl.text.trim()),
        contactEmail: nul(_contactEmailCtrl.text.trim()),
        contactPhone: nul(_contactPhoneCtrl.text.trim()),
        preferred: _preferred,
        internalRating: _rating,
        notes: nul(_notesCtrl.text.trim()),
        website: nul(_websiteCtrl.text.trim()),
        tags: _parseTags(_tagsCtrl.text),
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _FormHeader(isEditing: _isEditing),

        // Scrollable fields
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _Field(label: 'NAME *', child: _textField(_nameCtrl, 'e.g. Belmond Hotel Caruso')),
                const SizedBox(height: AppSpacing.base),

                // Category
                _Field(
                  label: 'CATEGORY',
                  child: _StyledDropdown<SupplierCategory>(
                    value: _category,
                    items: SupplierCategory.values,
                    labelOf: (c) => c.label,
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // City + Country
                Row(children: [
                  Expanded(child: _Field(label: 'CITY *', child: _textField(_cityCtrl, 'e.g. Ravello'))),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(label: 'COUNTRY *', child: _textField(_countryCtrl, 'e.g. Italy'))),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Location
                _Field(label: 'LOCATION / ADDRESS', child: _textField(_locationCtrl, 'Street address or area')),
                const SizedBox(height: AppSpacing.base),

                // Contact name + phone
                Row(children: [
                  Expanded(child: _Field(label: 'CONTACT NAME', child: _textField(_contactNameCtrl, 'Full name'))),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(label: 'PHONE', child: _textField(_contactPhoneCtrl, '+39 ...'))),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Contact email + website
                Row(children: [
                  Expanded(child: _Field(label: 'EMAIL', child: _textField(_contactEmailCtrl, 'email@supplier.com'))),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(label: 'WEBSITE', child: _textField(_websiteCtrl, 'https://'))),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Rating + Preferred
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'INTERNAL RATING',
                        child: RatingPicker(
                          rating: _rating.round(),
                          onChanged: (v) => setState(() => _rating = v.toDouble()),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.base),
                    _Field(
                      label: 'PREFERRED PARTNER',
                      child: Switch.adaptive(
                        value: _preferred,
                        onChanged: (v) => setState(() => _preferred = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // Tags
                _Field(
                  label: 'TAGS',
                  child: _textField(_tagsCtrl, 'Comma-separated: e.g. Amalfi, Pool, Fine Dining'),
                ),
                const SizedBox(height: AppSpacing.base),

                // Notes
                _Field(
                  label: 'INTERNAL NOTES',
                  child: _textField(_notesCtrl, 'Service quality, contact behaviour, special remarks…', maxLines: 4),
                ),
              ],
            ),
          ),
        ),

        // Footer
        _FormFooter(onSave: _save),
      ],
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      maxLines: maxLines,
      minLines: 1,
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
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared form sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final bool isEditing;
  const _FormHeader({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(isEditing ? 'Edit Supplier' : 'Add Supplier',
              style: AppTextStyles.heading3),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFooter extends StatelessWidget {
  final VoidCallback onSave;
  const _FormFooter({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
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
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

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
