import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/supplier_model.dart';
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

// ── Details field definition ──────────────────────────────────────────────────

enum _FieldKind { text, textarea, number, boolean, dropdown }

class _DetailsFieldDef {
  final String key;
  final String label;
  final String? hint;
  final _FieldKind kind;
  final List<String>? options;

  const _DetailsFieldDef({
    required this.key,
    required this.label,
    this.hint,
    this.kind = _FieldKind.text,
    this.options,
  });
}

Map<ComponentType, List<_DetailsFieldDef>> _typeFields() => {
  ComponentType.accommodation: const [
    _DetailsFieldDef(key: 'room_type',            label: 'Room / Villa Type',       hint: 'e.g. Deluxe King, Ocean Villa'),
    _DetailsFieldDef(key: 'room_number',           label: 'Room Number',             hint: 'e.g. 412'),
    _DetailsFieldDef(key: 'bed_configuration',     label: 'Bed Configuration',       hint: 'e.g. 1 King + 1 Twin'),
    _DetailsFieldDef(key: 'breakfast_included',    label: 'Breakfast Included',      kind: _FieldKind.boolean),
    _DetailsFieldDef(key: 'check_in_instructions', label: 'Check-in Instructions',   kind: _FieldKind.textarea),
  ],
  ComponentType.dining: const [
    _DetailsFieldDef(key: 'meal_type',       label: 'Meal Type',       kind: _FieldKind.dropdown,
        options: ['Breakfast', 'Brunch', 'Lunch', 'Dinner', 'Tasting Menu', 'Private Dining']),
    _DetailsFieldDef(key: 'reservation_name', label: 'Reservation Under', hint: 'Name on reservation'),
    _DetailsFieldDef(key: 'dress_code',       label: 'Dress Code',        hint: 'e.g. Smart Casual'),
    _DetailsFieldDef(key: 'table_preference', label: 'Table Preference',  hint: 'e.g. Window table, private room'),
    _DetailsFieldDef(key: 'dietary_notes',    label: 'Dietary Notes',     kind: _FieldKind.textarea),
  ],
  ComponentType.transport: const [
    _DetailsFieldDef(key: 'transport_type', label: 'Transport Type', kind: _FieldKind.dropdown,
        options: ['Flight', 'Private Jet', 'Train', 'Car Transfer', 'Helicopter', 'Ferry', 'Yacht', 'Bus', 'Other']),
    _DetailsFieldDef(key: 'carrier',              label: 'Carrier / Company',    hint: 'e.g. Singapore Airlines, ABC Transfers'),
    _DetailsFieldDef(key: 'flight_number',         label: 'Flight / Train Number', hint: 'e.g. SQ321'),
    _DetailsFieldDef(key: 'class_of_service',      label: 'Class of Service',      hint: 'e.g. Business Class'),
    _DetailsFieldDef(key: 'departure_terminal',    label: 'Departure Terminal',    hint: 'e.g. Terminal 3'),
    _DetailsFieldDef(key: 'arrival_location',      label: 'Arrival Location',      hint: 'e.g. Ngurah Rai Airport'),
    _DetailsFieldDef(key: 'seat_number',           label: 'Seat / Cabin',          hint: 'e.g. 4A'),
    _DetailsFieldDef(key: 'driver_name',           label: 'Driver Name'),
    _DetailsFieldDef(key: 'driver_phone',          label: 'Driver Phone'),
    _DetailsFieldDef(key: 'vehicle_description',   label: 'Vehicle',               hint: 'e.g. Black Mercedes V-Class'),
  ],
  ComponentType.experience: const [
    _DetailsFieldDef(key: 'duration_hours',     label: 'Duration (hours)',   kind: _FieldKind.number),
    _DetailsFieldDef(key: 'group_size',         label: 'Group Size',         kind: _FieldKind.number),
    _DetailsFieldDef(key: 'difficulty_level',   label: 'Difficulty Level',   kind: _FieldKind.dropdown,
        options: ['Easy', 'Moderate', 'Challenging', 'Extreme']),
    _DetailsFieldDef(key: 'equipment_provided', label: 'Equipment Provided', hint: 'e.g. Snorkel gear, wetsuits'),
    _DetailsFieldDef(key: 'what_to_bring',      label: 'What to Bring',      kind: _FieldKind.textarea),
  ],
  ComponentType.guide: const [
    _DetailsFieldDef(key: 'guide_speciality', label: 'Speciality',         hint: 'e.g. Cultural, Wildlife, Culinary'),
    _DetailsFieldDef(key: 'languages',         label: 'Languages',          hint: 'e.g. English, Bahasa'),
    _DetailsFieldDef(key: 'experience_years',  label: 'Experience (years)', kind: _FieldKind.number),
    _DetailsFieldDef(key: 'guide_license',     label: 'License / Cert No.'),
    _DetailsFieldDef(key: 'vehicle_included',  label: 'Vehicle Included',   kind: _FieldKind.boolean),
  ],
  ComponentType.specialArrangement: const [
    _DetailsFieldDef(key: 'arrangement_type', label: 'Arrangement Type', hint: 'e.g. Surprise Proposal, VIP Meet & Greet'),
    _DetailsFieldDef(key: 'special_notes',    label: 'Special Notes',    kind: _FieldKind.textarea),
  ],
  ComponentType.other: const [],
};

// ── Form sheet ────────────────────────────────────────────────────────────────

class _ComponentFormSheet extends StatefulWidget {
  final Trip               trip;
  final ComponentsProvider provider;
  final TripComponent?     existing;

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
  int _step = 0; // 0 = type selector, 1 = form

  // Core
  late ComponentType   _type;
  late ComponentStatus _status;

  // General
  late TextEditingController _titleCtrl;

  // Supplier
  String? _supplierId;
  String? _supplierName;
  List<Supplier> _allSuppliers = [];
  bool _suppliersLoading = false;

  // Dates & times
  DateTime?  _startDate;
  DateTime?  _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Location
  late TextEditingController _locationCtrl;
  late TextEditingController _addressCtrl;

  // Booking
  late TextEditingController _bookingRefCtrl;
  late TextEditingController _confirmationNumCtrl;
  late TextEditingController _primaryContactNameCtrl;
  late TextEditingController _primaryContactPhoneCtrl;
  late TextEditingController _primaryContactEmailCtrl;

  // Commercial
  late TextEditingController _netCostCtrl;
  late TextEditingController _depositPaidCtrl;
  late TextEditingController _remainingBalanceCtrl;
  DateTime? _paymentDueDate;
  late TextEditingController _cancellationTermsCtrl;

  // Files
  late TextEditingController _confirmationFileCtrl;
  late TextEditingController _invoiceFileCtrl;
  late TextEditingController _voucherFileCtrl;

  // Supplier contact override
  late TextEditingController _overrideNameCtrl;
  late TextEditingController _overridePhoneCtrl;
  late TextEditingController _overrideEmailCtrl;

  // Notes
  late TextEditingController _notesInternalCtrl;
  late TextEditingController _notesClientCtrl;

  // Type-specific details_json
  final Map<String, TextEditingController> _detailTextCtrls = {};
  final Map<String, dynamic> _detailValues = {}; // booleans + dropdowns

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _type   = e?.componentType ?? ComponentType.accommodation;
    _status = e?.status        ?? ComponentStatus.proposed;

    _titleCtrl                = TextEditingController(text: e?.title ?? '');
    _supplierId               = e?.supplierId;
    _supplierName             = e?.supplierName;

    _startDate = e?.startDate;
    _endDate   = e?.endDate;
    _startTime = _parseTime(e?.startTime);
    _endTime   = _parseTime(e?.endTime);

    _locationCtrl = TextEditingController(text: e?.locationName ?? '');
    _addressCtrl  = TextEditingController(text: e?.address ?? '');

    _bookingRefCtrl           = TextEditingController(text: e?.supplierBookingReference ?? '');
    _confirmationNumCtrl      = TextEditingController(text: e?.confirmationNumber ?? '');
    _primaryContactNameCtrl   = TextEditingController(text: e?.primaryContactName ?? '');
    _primaryContactPhoneCtrl  = TextEditingController(text: e?.primaryContactPhone ?? '');
    _primaryContactEmailCtrl  = TextEditingController(text: e?.primaryContactEmail ?? '');

    _netCostCtrl          = TextEditingController(text: e?.netCost?.toStringAsFixed(2) ?? '');
    _depositPaidCtrl      = TextEditingController(text: e?.depositPaid?.toStringAsFixed(2) ?? '');
    _remainingBalanceCtrl = TextEditingController(text: e?.remainingBalance?.toStringAsFixed(2) ?? '');
    _paymentDueDate       = e?.paymentDueDate;
    _cancellationTermsCtrl = TextEditingController(text: e?.cancellationTerms ?? '');

    _confirmationFileCtrl = TextEditingController(text: e?.confirmationFileUrl ?? '');
    _invoiceFileCtrl      = TextEditingController(text: e?.invoiceFileUrl ?? '');
    _voucherFileCtrl      = TextEditingController(text: e?.voucherFileUrl ?? '');

    _overrideNameCtrl  = TextEditingController(text: e?.supplierContactOverrideName ?? '');
    _overridePhoneCtrl = TextEditingController(text: e?.supplierContactOverridePhone ?? '');
    _overrideEmailCtrl = TextEditingController(text: e?.supplierContactOverrideEmail ?? '');

    _notesInternalCtrl = TextEditingController(text: e?.notesInternal ?? '');
    _notesClientCtrl   = TextEditingController(text: e?.notesClient ?? '');

    _initDetailControllers(e?.detailsJson ?? {});

    // Skip type selector when editing
    if (_isEditing) _step = 1;

    _loadSuppliers();
  }

  void _initDetailControllers(Map<String, dynamic> existing) {
    for (final ctrl in _detailTextCtrls.values) { ctrl.dispose(); }
    _detailTextCtrls.clear();
    _detailValues.clear();

    final fields = _typeFields()[_type] ?? [];
    for (final f in fields) {
      switch (f.kind) {
        case _FieldKind.text:
        case _FieldKind.textarea:
        case _FieldKind.number:
          _detailTextCtrls[f.key] = TextEditingController(
            text: existing[f.key]?.toString() ?? '',
          );
        case _FieldKind.boolean:
          _detailValues[f.key] = existing[f.key] as bool? ?? false;
        case _FieldKind.dropdown:
          _detailValues[f.key] = existing[f.key] as String?;
      }
    }
  }

  Future<void> _loadSuppliers() async {
    final repos = AppRepositories.instance;
    final teamId = widget.provider.teamId;
    if (repos == null || teamId == null) return;
    setState(() => _suppliersLoading = true);
    try {
      _allSuppliers = await repos.suppliers.fetchAll(teamId);
    } catch (_) {}
    if (mounted) setState(() => _suppliersLoading = false);
  }

  List<Supplier> get _filteredSuppliers {
    final cats = _type.relevantSupplierCategories;
    return _allSuppliers
        .where((s) => cats.contains(s.category))
        .toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _bookingRefCtrl.dispose();
    _confirmationNumCtrl.dispose();
    _primaryContactNameCtrl.dispose();
    _primaryContactPhoneCtrl.dispose();
    _primaryContactEmailCtrl.dispose();
    _netCostCtrl.dispose();
    _depositPaidCtrl.dispose();
    _remainingBalanceCtrl.dispose();
    _cancellationTermsCtrl.dispose();
    _confirmationFileCtrl.dispose();
    _invoiceFileCtrl.dispose();
    _voucherFileCtrl.dispose();
    _overrideNameCtrl.dispose();
    _overridePhoneCtrl.dispose();
    _overrideEmailCtrl.dispose();
    _notesInternalCtrl.dispose();
    _notesClientCtrl.dispose();
    for (final c in _detailTextCtrls.values) { c.dispose(); }
    super.dispose();
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  Map<String, dynamic> _buildDetailsJson() {
    final result = <String, dynamic>{};
    _detailTextCtrls.forEach((key, ctrl) {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) result[key] = v;
    });
    _detailValues.forEach((key, val) {
      if (val != null && val != false) result[key] = val;
    });
    return result;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final prevStatus    = widget.existing?.status;
    final statusChanged = prevStatus != _status;
    // Only prompt for linking when no links exist yet — prevents duplicate
    // budget/itinerary records when editing an already-linked component.
    final alreadyLinked = widget.existing?.costItemId != null ||
                          widget.existing?.itineraryItemId != null ||
                          widget.existing?.runSheetItemId  != null;
    final needsLinking  = !alreadyLinked &&
                          statusChanged &&
                          _status.requiresLinkingPrompt;

    final component = TripComponent(
      id:            widget.existing?.id ?? '',
      tripId:        widget.trip.id,
      teamId:        widget.provider.teamId ?? '',
      componentType: _type,
      status:        _status,
      title:         _titleCtrl.text.trim(),
      supplierId:    _supplierId,
      supplierName:  _supplierName,
      supplierContactOverrideName:  _nullIfEmpty(_overrideNameCtrl.text),
      supplierContactOverridePhone: _nullIfEmpty(_overridePhoneCtrl.text),
      supplierContactOverrideEmail: _nullIfEmpty(_overrideEmailCtrl.text),
      startDate:  _startDate,
      endDate:    _endDate,
      startTime:  _startTime != null ? _fmtTime(_startTime!) : null,
      endTime:    _endTime   != null ? _fmtTime(_endTime!)   : null,
      locationName: _nullIfEmpty(_locationCtrl.text),
      address:      _nullIfEmpty(_addressCtrl.text),
      supplierBookingReference: _nullIfEmpty(_bookingRefCtrl.text),
      confirmationNumber:       _nullIfEmpty(_confirmationNumCtrl.text),
      primaryContactName:       _nullIfEmpty(_primaryContactNameCtrl.text),
      primaryContactPhone:      _nullIfEmpty(_primaryContactPhoneCtrl.text),
      primaryContactEmail:      _nullIfEmpty(_primaryContactEmailCtrl.text),
      netCost:          double.tryParse(_netCostCtrl.text),
      depositPaid:      double.tryParse(_depositPaidCtrl.text),
      remainingBalance: double.tryParse(_remainingBalanceCtrl.text),
      paymentDueDate:   _paymentDueDate,
      cancellationTerms: _nullIfEmpty(_cancellationTermsCtrl.text),
      confirmationFileUrl: _nullIfEmpty(_confirmationFileCtrl.text),
      invoiceFileUrl:      _nullIfEmpty(_invoiceFileCtrl.text),
      voucherFileUrl:      _nullIfEmpty(_voucherFileCtrl.text),
      detailsJson:   _buildDetailsJson(),
      notesInternal: _nullIfEmpty(_notesInternalCtrl.text),
      notesClient:   _nullIfEmpty(_notesClientCtrl.text),
      costItemId:      widget.existing?.costItemId,
      itineraryItemId: widget.existing?.itineraryItemId,
      runSheetItemId:  widget.existing?.runSheetItemId,
      createdBy:  widget.existing?.createdBy,
      createdAt:  widget.existing?.createdAt ?? DateTime.now(),
      updatedAt:  DateTime.now(),
    );

    TripComponent? saved;
    if (_isEditing) {
      saved = await widget.provider.updateComponent(component);
    } else {
      saved = await widget.provider.addComponent(component);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    if (saved != null && needsLinking) {
      final choice = await showComponentLinkingDialog(context, component: saved);
      if (choice != null && choice.anySelected) {
        await widget.provider.linkComponent(saved, choice);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height:     screenH * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _step == 0 ? _buildTypeSelector() : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin:     const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          width:      36,
          height:     4,
          decoration: BoxDecoration(
            color:        AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (_step == 1 && !_isEditing)
              IconButton(
                onPressed: () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (_step == 1 && !_isEditing) const SizedBox(width: AppSpacing.sm),
            Text(
              _isEditing
                  ? 'Edit Component'
                  : _step == 0
                      ? 'Select Type'
                      : 'Add ${_type.label}',
              style: AppTextStyles.heading2,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (_step == 1) ...[
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEditing ? 'Save' : 'Add'),
              ),
            ],
          ],
        ),
      );

  // ── Step 1: type selector ────────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return GridView.count(
      crossAxisCount: 2,
      padding:        const EdgeInsets.all(AppSpacing.pagePaddingH),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing:  AppSpacing.sm,
      childAspectRatio: 2.2,
      children: ComponentType.values.map((t) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _type = t;
              _initDetailControllers({});
              _step = 1;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color:        t.bgColor,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border:       Border.all(color: t.color.withAlpha(60)),
            ),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.base),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: t.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(t.icon, size: 18, color: t.color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    t.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color:      t.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Step 2: main form ────────────────────────────────────────────────────────

  Widget _buildForm() {
    final labels = _type.fieldLabels;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical:   AppSpacing.base,
        ),
        children: [
          // ── General ──────────────────────────────────────────────────────────
          _sectionHeader('General'),
          _fieldGap(),
          _labeledField(
            label: 'Title *',
            child: TextFormField(
              controller: _titleCtrl,
              decoration: _inputDeco('e.g. Mulia Resort – Deluxe Ocean Villa'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          _labeledField(
            label: 'Status',
            child: _StatusSelector(
              selected:  _status,
              onChanged: (s) => setState(() => _status = s),
            ),
          ),
          _sectionDivider(),

          // ── Supplier ─────────────────────────────────────────────────────────
          _sectionHeader('Supplier'),
          _fieldGap(),
          _labeledField(
            label: 'Supplier',
            child: _SupplierPickerField(
              selectedId:   _supplierId,
              selectedName: _supplierName,
              suppliers:    _filteredSuppliers,
              loading:      _suppliersLoading,
              onSelected:   (id, name) => setState(() {
                _supplierId   = id;
                _supplierName = name;
              }),
              onCleared:    () => setState(() {
                _supplierId   = null;
                _supplierName = null;
              }),
            ),
          ),
          _sectionDivider(),

          // ── Dates & Times ────────────────────────────────────────────────────
          _sectionHeader('Dates & Times'),
          _fieldGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: labels.startDate,
              child: _DateField(
                value:    _startDate,
                onPicked: (d) => setState(() { _startDate = d; _endDate ??= d; }),
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: labels.endDate,
              child: _DateField(
                value:    _endDate,
                onPicked: (d) => setState(() => _endDate = d),
              ),
            )),
          ]),
          _rowGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: labels.startTime,
              child: _TimeField(
                value:    _startTime,
                onPicked: (t) => setState(() => _startTime = t),
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: labels.endTime,
              child: _TimeField(
                value:    _endTime,
                onPicked: (t) => setState(() => _endTime = t),
              ),
            )),
          ]),
          _sectionDivider(),

          // ── Location ─────────────────────────────────────────────────────────
          _sectionHeader('Location'),
          _fieldGap(),
          _labeledField(
            label: labels.locationName,
            child: TextFormField(
              controller: _locationCtrl,
              decoration: _inputDeco(''),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          _labeledField(
            label: labels.address,
            child: TextFormField(
              controller: _addressCtrl,
              decoration: _inputDeco(''),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _sectionDivider(),

          // ── Booking ──────────────────────────────────────────────────────────
          _sectionHeader('Booking'),
          _fieldGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: 'Booking Reference',
              child: TextFormField(
                controller: _bookingRefCtrl,
                decoration: _inputDeco('Supplier ref'),
                style: AppTextStyles.bodyMedium,
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: 'Confirmation Number',
              child: TextFormField(
                controller: _confirmationNumCtrl,
                decoration: _inputDeco(''),
                style: AppTextStyles.bodyMedium,
              ),
            )),
          ]),
          _rowGap(),
          _labeledField(
            label: 'Primary Contact Name',
            child: TextFormField(
              controller: _primaryContactNameCtrl,
              decoration: _inputDeco('On-site contact'),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: 'Contact Phone',
              child: TextFormField(
                controller: _primaryContactPhoneCtrl,
                decoration: _inputDeco(''),
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium,
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: 'Contact Email',
              child: TextFormField(
                controller: _primaryContactEmailCtrl,
                decoration: _inputDeco(''),
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
              ),
            )),
          ]),
          _sectionDivider(),

          // ── Type-specific Details ────────────────────────────────────────────
          ...(_typeFields()[_type] ?? []).isEmpty ? [] : [
            _sectionHeader('${_type.label} Details'),
            _fieldGap(),
            ..._buildDetailFields(),
            _sectionDivider(),
          ],

          // ── Commercial ───────────────────────────────────────────────────────
          _sectionHeader('Commercial'),
          _fieldGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: 'Net Cost',
              child: TextFormField(
                controller: _netCostCtrl,
                decoration: _inputDeco('0.00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: AppTextStyles.bodyMedium,
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: 'Deposit Paid',
              child: TextFormField(
                controller: _depositPaidCtrl,
                decoration: _inputDeco('0.00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: AppTextStyles.bodyMedium,
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: 'Remaining Balance',
              child: TextFormField(
                controller: _remainingBalanceCtrl,
                decoration: _inputDeco('0.00'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: AppTextStyles.bodyMedium,
              ),
            )),
          ]),
          _rowGap(),
          _labeledField(
            label: 'Payment Due Date',
            child: _DateField(
              value:    _paymentDueDate,
              onPicked: (d) => setState(() => _paymentDueDate = d),
            ),
          ),
          _rowGap(),
          _labeledField(
            label: 'Cancellation Terms',
            child: TextFormField(
              controller: _cancellationTermsCtrl,
              decoration: _inputDeco('e.g. Non-refundable, 48hr policy'),
              maxLines: 2,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _sectionDivider(),

          // ── Notes ────────────────────────────────────────────────────────────
          _sectionHeader('Notes'),
          _fieldGap(),
          _labeledField(
            label: 'Internal Notes',
            child: TextFormField(
              controller: _notesInternalCtrl,
              decoration: _inputDeco('Visible to team only'),
              maxLines: 3,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          _labeledField(
            label: 'Client Notes',
            child: TextFormField(
              controller: _notesClientCtrl,
              decoration: _inputDeco('Visible on client itinerary'),
              maxLines: 3,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _sectionDivider(),

          // ── Supplier Override Contact ─────────────────────────────────────────
          _sectionHeader('Supplier Contact Override'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Leave blank to use supplier's default contact.",
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          _fieldGap(),
          _labeledField(
            label: 'Override Name',
            child: TextFormField(
              controller: _overrideNameCtrl,
              decoration: _inputDeco(''),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          Row(children: [
            Expanded(child: _labeledField(
              label: 'Override Phone',
              child: TextFormField(
                controller: _overridePhoneCtrl,
                decoration: _inputDeco(''),
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium,
              ),
            )),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _labeledField(
              label: 'Override Email',
              child: TextFormField(
                controller: _overrideEmailCtrl,
                decoration: _inputDeco(''),
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium,
              ),
            )),
          ]),
          _sectionDivider(),

          // ── Files ────────────────────────────────────────────────────────────
          _sectionHeader('File URLs'),
          _fieldGap(),
          _labeledField(
            label: 'Confirmation',
            child: TextFormField(
              controller: _confirmationFileCtrl,
              decoration: _inputDeco('https://...'),
              keyboardType: TextInputType.url,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          _labeledField(
            label: 'Invoice',
            child: TextFormField(
              controller: _invoiceFileCtrl,
              decoration: _inputDeco('https://...'),
              keyboardType: TextInputType.url,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          _rowGap(),
          _labeledField(
            label: 'Voucher',
            child: TextFormField(
              controller: _voucherFileCtrl,
              decoration: _inputDeco('https://...'),
              keyboardType: TextInputType.url,
              style: AppTextStyles.bodyMedium,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  List<Widget> _buildDetailFields() {
    final fields = _typeFields()[_type] ?? [];
    final widgets = <Widget>[];

    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (i > 0) widgets.add(_rowGap());

      switch (f.kind) {
        case _FieldKind.text:
          widgets.add(_labeledField(
            label: f.label,
            child: TextFormField(
              controller: _detailTextCtrls[f.key],
              decoration: _inputDeco(f.hint ?? ''),
              style: AppTextStyles.bodyMedium,
            ),
          ));
        case _FieldKind.textarea:
          widgets.add(_labeledField(
            label: f.label,
            child: TextFormField(
              controller: _detailTextCtrls[f.key],
              decoration: _inputDeco(f.hint ?? ''),
              maxLines: 3,
              style: AppTextStyles.bodyMedium,
            ),
          ));
        case _FieldKind.number:
          widgets.add(_labeledField(
            label: f.label,
            child: TextFormField(
              controller: _detailTextCtrls[f.key],
              decoration: _inputDeco(f.hint ?? '0'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: AppTextStyles.bodyMedium,
            ),
          ));
        case _FieldKind.boolean:
          widgets.add(_labeledField(
            label: f.label,
            child: GestureDetector(
              onTap: () => setState(() {
                _detailValues[f.key] = !(_detailValues[f.key] as bool? ?? false);
              }),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Switch.adaptive(
                      value:            _detailValues[f.key] as bool? ?? false,
                      onChanged:        (v) => setState(() => _detailValues[f.key] = v),
                      activeThumbColor: AppColors.accent,
                      activeTrackColor: AppColors.accentLight,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      (_detailValues[f.key] as bool? ?? false) ? 'Yes' : 'No',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ));
        case _FieldKind.dropdown:
          final options = f.options ?? [];
          final selected = _detailValues[f.key] as String?;
          widgets.add(_labeledField(
            label: f.label,
            child: DropdownButtonFormField<String>(
              initialValue: options.contains(selected) ? selected : null,
              decoration:   _inputDeco(f.hint ?? 'Select...'),
              style:       AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              dropdownColor: AppColors.surface,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _detailValues[f.key] = v),
            ),
          ));
      }
    }
    return widgets;
  }

  // ── Layout helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(title, style: AppTextStyles.overline),
      );

  Widget _sectionDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Divider(height: 1, color: AppColors.divider),
      );

  Widget _fieldGap() => const SizedBox(height: AppSpacing.sm);
  Widget _rowGap()   => const SizedBox(height: AppSpacing.sm);

  Widget _labeledField({required String label, required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      );
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
              margin: EdgeInsets.only(
                right: s != ComponentStatus.values.last ? AppSpacing.xs : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? s.bgColor : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                border: Border.all(
                  color: isSelected ? s.color.withAlpha(120) : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      isSelected ? s.color : AppColors.textMuted,
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

// ── Supplier picker field ─────────────────────────────────────────────────────

class _SupplierPickerField extends StatelessWidget {
  final String?          selectedId;
  final String?          selectedName;
  final List<Supplier>   suppliers;
  final bool             loading;
  final void Function(String id, String name) onSelected;
  final VoidCallback     onCleared;

  const _SupplierPickerField({
    required this.selectedId,
    required this.selectedName,
    required this.suppliers,
    required this.loading,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_outlined, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                selectedName ?? (loading ? 'Loading…' : 'Search suppliers…'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selectedName != null ? AppColors.textPrimary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selectedId != null)
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              )
            else
              const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierSearchSheet(suppliers: suppliers),
    );
    if (result != null) onSelected(result.id, result.name);
  }
}

// ── Supplier search sheet ─────────────────────────────────────────────────────

class _SupplierSearchSheet extends StatefulWidget {
  final List<Supplier> suppliers;
  const _SupplierSearchSheet({required this.suppliers});

  @override
  State<_SupplierSearchSheet> createState() => _SupplierSearchSheetState();
}

class _SupplierSearchSheetState extends State<_SupplierSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Supplier> get _results {
    if (_query.isEmpty) return widget.suppliers;
    final q = _query.toLowerCase();
    return widget.suppliers
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin:     const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width:      36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH,
              vertical:   AppSpacing.sm,
            ),
            child: TextFormField(
              controller:  _searchCtrl,
              autofocus:   true,
              decoration:  _inputDeco('Search by name or city…'),
              style:       AppTextStyles.bodyMedium,
              onChanged:   (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No suppliers found',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final s = _results[i];
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accentFaint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                        ),
                        title: Text(s.name, style: AppTextStyles.bodyMedium),
                        subtitle: Text(
                          '${s.city}${s.country.isNotEmpty ? ', ${s.country}' : ''}',
                          style: AppTextStyles.bodySmall,
                        ),
                        onTap: () => Navigator.of(context).pop((id: s.id, name: s.name)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;
  const _DateField({required this.value, required this.onPicked});

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null ? DateFormat('d MMM yyyy').format(value!) : 'Select date',
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
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onPicked;
  const _TimeField({required this.value, required this.onPicked});

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null ? value!.format(context) : 'Select time',
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

// ── Input decoration ──────────────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText:     hint,
      hintStyle:    AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      filled:       true,
      fillColor:    AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical:   AppSpacing.md,
      ),
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
