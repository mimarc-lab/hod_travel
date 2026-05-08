import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
/// [initialSupplierType] pre-fills the type picker when creating a new supplier
/// (e.g. when called from a component form).
Future<void> showSupplierEditor(
  BuildContext context, {
  required SupplierProvider provider,
  Supplier? existing,
  SupplierType? initialSupplierType,
}) async {
  final isMobile = MediaQuery.sizeOf(context).width < 600;

  if (isMobile) {
    await showModalBottomSheet(
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
          initialSupplierType: initialSupplierType,
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          child: _SupplierEditorForm(
            provider: provider,
            existing: existing,
            initialSupplierType: initialSupplierType,
          ),
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
  final SupplierType? initialSupplierType;

  const _SupplierEditorForm({
    required this.provider,
    this.existing,
    this.scrollController,
    this.initialSupplierType,
  });

  @override
  State<_SupplierEditorForm> createState() => _SupplierEditorFormState();
}

class _SupplierEditorFormState extends State<_SupplierEditorForm> {
  late SupplierType _supplierType;
  String? _supplierSubtype;
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

  List<Supplier> _duplicates = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _supplierType    = e?.supplierType   ?? widget.initialSupplierType ?? SupplierType.accommodation;
    _supplierSubtype = e?.supplierSubtype;
    _rating          = e?.internalRating ?? 3.0;
    _preferred       = e?.preferred      ?? false;

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

    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    for (final ctrl in [
      _nameCtrl, _cityCtrl, _countryCtrl, _locationCtrl,
      _contactNameCtrl, _contactEmailCtrl, _contactPhoneCtrl,
      _websiteCtrl, _notesCtrl, _tagsCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onNameChanged() {
    final query = _nameCtrl.text.trim();
    final results = query.length >= 3 ? _findSimilar(query) : <Supplier>[];
    if (!_sameIds(results, _duplicates)) {
      setState(() => _duplicates = results);
    }
  }

  List<Supplier> _findSimilar(String query) {
    final q = query.toLowerCase();
    final excludeId = widget.existing?.id;
    return widget.provider.suppliers.where((s) {
      if (s.id == excludeId) return false;
      final name = s.name.toLowerCase();
      if (name.contains(q) || q.contains(name)) return true;
      // word-level overlap: any significant query word (≥3 chars) found in name
      return q.split(' ')
          .where((w) => w.length >= 3)
          .any((word) => name.contains(word));
    }).take(4).toList();
  }

  bool _sameIds(List<Supplier> a, List<Supplier> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<String> _parseTags(String raw) =>
      raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  // Derive a legacy SupplierCategory from the new supplier type + subtype so
  // older code that reads `category` still has a meaningful value.
  SupplierCategory _derivedCategory() {
    switch (_supplierType) {
      case SupplierType.accommodation:
        return _supplierSubtype == 'villa'
            ? SupplierCategory.villa
            : SupplierCategory.hotel;
      case SupplierType.dining:       return SupplierCategory.restaurant;
      case SupplierType.transport:    return SupplierCategory.transport;
      case SupplierType.guide:        return SupplierCategory.guide;
      case SupplierType.experienceProvider: return SupplierCategory.experience;
      case SupplierType.specialistServices: return SupplierCategory.concierge;
      default:                        return SupplierCategory.other;
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final city    = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    if (city.isEmpty || country.isEmpty) return;

    String? nul(String v) => v.isEmpty ? null : v;

    final derivedCat = _derivedCategory();

    if (_isEditing) {
      widget.provider.updateSupplier(widget.existing!.copyWith(
        name: name,
        category: derivedCat,
        supplierType: _supplierType,
        supplierSubtype: _supplierSubtype,
        clearSupplierSubtype: _supplierSubtype == null,
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
        category: derivedCat,
        supplierType: _supplierType,
        supplierSubtype: _supplierSubtype,
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
                if (_duplicates.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _DuplicateHint(duplicates: _duplicates),
                ],
                const SizedBox(height: AppSpacing.base),

                // Supplier Type
                _Field(
                  label: 'SUPPLIER TYPE',
                  child: _StyledDropdown<SupplierType>(
                    value: _supplierType,
                    items: SupplierType.values,
                    labelOf: (t) => t.label,
                    onChanged: (v) => setState(() {
                      _supplierType    = v;
                      _supplierSubtype = null; // reset subtype when type changes
                    }),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Supplier Subtype (dynamic per type)
                _Field(
                  label: 'SUPPLIER SUBTYPE',
                  child: _StyledDropdown<String>(
                    value: _supplierSubtype ?? '',
                    items: ['', ...kSupplierSubtypes[_supplierType] ?? []],
                    labelOf: (s) => s.isEmpty ? '— None —' : subtypeLabel(s),
                    onChanged: (v) => setState(() =>
                        _supplierSubtype = v.isEmpty ? null : v),
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

// ── Duplicate hint ─────────────────────────────────────────────────────────────

class _DuplicateHint extends StatelessWidget {
  final List<Supplier> duplicates;
  const _DuplicateHint({required this.duplicates});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: Color(0xFF92400E)),
              const SizedBox(width: 5),
              Text(
                'Possible duplicate${duplicates.length > 1 ? 's' : ''} already in your list',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...duplicates.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 7, top: 1),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF78350F),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.effectiveSupplierType.label} · ${s.city}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF92400E),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
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
