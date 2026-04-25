import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../providers/budget_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the cost item editor as a dialog (desktop) or bottom sheet (mobile).
/// [defaultTripId] pre-selects a trip when opened from a trip-scoped context.
/// [trips] drives the trip dropdown — pass the team's real trips.
/// [suppliers] enables name auto-suggestion based on the selected category.
void showCostItemEditor(
  BuildContext context, {
  required BudgetProvider provider,
  CostItem? existing,
  String? defaultTripId,
  List<Trip> trips = const [],
  List<Supplier> suppliers = const [],
}) {
  final isMobile = MediaQuery.sizeOf(context).width < 600;

  if (isMobile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, ctrl) => _CostItemEditorForm(
          scrollController: ctrl,
          provider: provider,
          existing: existing,
          defaultTripId: defaultTripId,
          trips: trips,
          suppliers: suppliers,
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
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: _CostItemEditorForm(
            provider: provider,
            existing: existing,
            defaultTripId: defaultTripId,
            trips: trips,
            suppliers: suppliers,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CostItemEditorForm
// ─────────────────────────────────────────────────────────────────────────────

class _CostItemEditorForm extends StatefulWidget {
  final BudgetProvider provider;
  final CostItem? existing;
  final String? defaultTripId;
  final ScrollController? scrollController;
  final List<Trip> trips;
  final List<Supplier> suppliers;

  const _CostItemEditorForm({
    required this.provider,
    this.existing,
    this.defaultTripId,
    this.scrollController,
    this.trips = const [],
    this.suppliers = const [],
  });

  @override
  State<_CostItemEditorForm> createState() => _CostItemEditorFormState();
}

class _CostItemEditorFormState extends State<_CostItemEditorForm> {
  late String _tripId;
  late CostCategory _category;
  late MarkupType _markupType;
  late PaymentStatus _paymentStatus;
  Supplier? _selectedSupplier;
  DateTime? _date;
  DateTime? _paymentDueDate;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _netCtrl;
  late final TextEditingController _markupCtrl;
  late final TextEditingController _sellCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _notesCtrl;
  late final FocusNode _nameFocus;
  bool _nameFocused = false;

  // Derived sell price preview
  double get _derivedSell {
    final net    = double.tryParse(_netCtrl.text) ?? 0;
    final markup = double.tryParse(_markupCtrl.text) ?? 0;
    return CostItem.deriveSellPrice(net, _markupType, markup);
  }

  // Remaining balance = net cost − deposit paid
  double get _remainingBalance {
    final net     = double.tryParse(_netCtrl.text) ?? 0;
    final deposit = double.tryParse(_depositCtrl.text) ?? 0;
    return net - deposit;
  }

  bool get _isEditing => widget.existing != null;

  String _fallbackTripId() {
    final e = widget.existing;
    if (e != null) return e.tripId;
    if (widget.defaultTripId != null) return widget.defaultTripId!;
    return widget.trips.isNotEmpty ? widget.trips.first.id : '';
  }

  /// Suppliers that match the current category for name suggestions.
  List<Supplier> get _nameSuggestions {
    final cats = _supplierCategoriesFor(_category);
    if (cats.isEmpty || widget.suppliers.isEmpty) return [];
    final query = _nameCtrl.text.toLowerCase();
    return widget.suppliers
        .where((s) => cats.contains(s.category))
        .where((s) => query.isEmpty || s.name.toLowerCase().contains(query))
        .take(5)
        .toList();
  }

  Set<SupplierCategory> _supplierCategoriesFor(CostCategory cat) {
    return switch (cat) {
      CostCategory.accommodation => {SupplierCategory.hotel, SupplierCategory.villa},
      CostCategory.dining        => {SupplierCategory.restaurant},
      CostCategory.transport     => {SupplierCategory.transport},
      CostCategory.experience    => {SupplierCategory.experience},
      CostCategory.guide         => {SupplierCategory.guide},
      _                          => {},
    };
  }

  @override
  void initState() {
    super.initState();
    _tripId        = _fallbackTripId();
    _category      = widget.existing?.category      ?? CostCategory.accommodation;
    _markupType    = widget.existing?.markupType    ?? MarkupType.percentage;
    _paymentStatus = widget.existing?.paymentStatus ?? PaymentStatus.pending;
    _date          = widget.existing?.date;
    _paymentDueDate = widget.existing?.paymentDueDate;
    final existingSupplierId = widget.existing?.supplierId;
    if (existingSupplierId != null) {
      _selectedSupplier = widget.suppliers
          .where((s) => s.id == existingSupplierId)
          .firstOrNull;
    }

    _nameCtrl     = TextEditingController(text: widget.existing?.itemName ?? '');
    _cityCtrl     = TextEditingController(text: widget.existing?.city ?? '');
    _currencyCtrl = TextEditingController(text: widget.existing?.currency ?? 'USD');
    _netCtrl      = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.netCost.toStringAsFixed(2)
            : '');
    _markupCtrl   = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.markupValue.toStringAsFixed(
                widget.existing!.markupType == MarkupType.percentage ? 1 : 2)
            : '');
    _sellCtrl     = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.sellPrice.toStringAsFixed(2)
            : '');
    _depositCtrl  = TextEditingController(
        text: widget.existing != null && widget.existing!.depositPaid > 0
            ? widget.existing!.depositPaid.toStringAsFixed(2)
            : '');
    _notesCtrl    = TextEditingController(text: widget.existing?.notes ?? '');

    _nameFocus = FocusNode();
    _nameFocus.addListener(_onNameFocusChange);

    // When net/markup changes, re-derive sell price
    _netCtrl.addListener(_refreshSell);
    _markupCtrl.addListener(_refreshSell);
    // When deposit or net changes, rebuild to refresh remaining balance display
    _depositCtrl.addListener(() => setState(() {}));
    _netCtrl.addListener(() => setState(() {}));
    // When name changes, refresh suggestions
    _nameCtrl.addListener(() => setState(() {}));
  }

  void _onNameFocusChange() {
    if (_nameFocus.hasFocus) {
      setState(() => _nameFocused = true);
    } else {
      // Delay hiding so a tap on a suggestion row can fire before the panel
      // disappears (focus-loss always fires before onTap).
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _nameFocused = false);
      });
    }
  }

  void _refreshSell() {
    final derived = _derivedSell;
    final formatted = derived.toStringAsFixed(2);
    if (_sellCtrl.text != formatted) {
      _sellCtrl.text = formatted;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _cityCtrl, _currencyCtrl,
                     _netCtrl, _markupCtrl, _sellCtrl, _depositCtrl, _notesCtrl]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) return;

    final net     = double.tryParse(_netCtrl.text) ?? 0;
    final markup  = double.tryParse(_markupCtrl.text) ?? 0;
    final sell    = double.tryParse(_sellCtrl.text) ?? _derivedSell;
    final deposit = double.tryParse(_depositCtrl.text) ?? 0;
    final cur     = _currencyCtrl.text.trim().isEmpty ? 'USD' : _currencyCtrl.text.trim();

    if (_isEditing) {
      widget.provider.updateItem(widget.existing!.copyWith(
        tripId:      _tripId,
        supplierId:  _selectedSupplier?.id,
        clearSupplierId: _selectedSupplier == null,
        itemName:    name,
        category:    _category,
        city:        city,
        currency:    cur,
        netCost:     net,
        depositPaid: deposit,
        markupType:  _markupType,
        markupValue: markup,
        sellPrice:   sell,
        paymentStatus:  _paymentStatus,
        date:           _date,
        clearDate:      _date == null,
        paymentDueDate: _paymentDueDate,
        clearPaymentDueDate: _paymentDueDate == null,
        notes:     _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        clearNotes: _notesCtrl.text.trim().isEmpty,
      ));
    } else {
      widget.provider.addItem(CostItem(
        id:          '',
        tripId:      _tripId,
        supplierId:  _selectedSupplier?.id,
        itemName:    name,
        category:    _category,
        city:        city,
        currency:    cur,
        netCost:     net,
        depositPaid: deposit,
        markupType:  _markupType,
        markupValue: markup,
        sellPrice:   sell,
        paymentStatus:  _paymentStatus,
        date:           _date,
        paymentDueDate: _paymentDueDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _nameSuggestions;
    final showSuggestions = _nameFocused && suggestions.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(isEditing: _isEditing),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name with supplier suggestions
                _Field(
                  label: 'ITEM NAME *',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _text(_nameCtrl, 'e.g. Belmond Hotel Caruso — 2 nights',
                          focusNode: _nameFocus),
                      if (showSuggestions)
                        _SupplierSuggestionPanel(
                          suggestions: suggestions,
                          onSelect: (s) {
                            setState(() {
                              _nameCtrl.text = s.name;
                              _nameFocused = false;
                            });
                            _nameFocus.unfocus();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Supplier
                _Field(
                  label: 'SUPPLIER',
                  child: _SupplierPickerField(
                    selected:  _selectedSupplier,
                    suppliers: widget.suppliers,
                    category:  _category,
                    onChanged: (s) => setState(() => _selectedSupplier = s),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Trip + Category
                Row(children: [
                  Expanded(child: _Field(
                    label: 'TRIP',
                    child: _TripDropdown(
                      trips: widget.trips,
                      value: _tripId,
                      onChanged: (v) => setState(() => _tripId = v),
                    ),
                  )),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                    label: 'CATEGORY',
                    child: _EnumDropdown<CostCategory>(
                      value: _category,
                      items: CostCategory.values,
                      labelOf: (c) => c.label,
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  )),
                ]),
                const SizedBox(height: AppSpacing.base),

                // City + Currency
                Row(children: [
                  Expanded(child: _Field(
                      label: 'CITY *',
                      child: _text(_cityCtrl, 'e.g. Ravello'))),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                      label: 'CURRENCY',
                      child: _text(_currencyCtrl, 'USD'))),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Date + Payment due date
                Row(children: [
                  Expanded(child: _Field(
                    label: 'SERVICE DATE',
                    child: _DatePicker(
                      value: _date,
                      hint: 'Select date',
                      onChanged: (d) => setState(() => _date = d),
                    ),
                  )),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                    label: 'PAYMENT DUE',
                    child: _DatePicker(
                      value: _paymentDueDate,
                      hint: 'Optional',
                      onChanged: (d) => setState(() => _paymentDueDate = d),
                    ),
                  )),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Net + Markup type + Markup value
                Row(children: [
                  Expanded(child: _Field(
                      label: 'NET COST *',
                      child: _text(_netCtrl, '0.00',
                          keyboardType: TextInputType.number))),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                    label: 'MARKUP TYPE',
                    child: _EnumDropdown<MarkupType>(
                      value: _markupType,
                      items: MarkupType.values,
                      labelOf: (m) => m.label,
                      onChanged: (v) => setState(() {
                        _markupType = v;
                        _refreshSell();
                      }),
                    ),
                  )),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                      label: 'MARKUP VALUE',
                      child: _text(_markupCtrl,
                          _markupType == MarkupType.percentage ? '15.0' : '0.00',
                          keyboardType: TextInputType.number))),
                ]),
                const SizedBox(height: AppSpacing.sm),

                // Sell price (auto-derived, editable override)
                _Field(
                  label: 'SELL PRICE',
                  child: _text(_sellCtrl, '0.00',
                      keyboardType: TextInputType.number),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Auto-calculated from net + markup. Override by editing directly.',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Deposit paid + remaining balance
                Row(children: [
                  Expanded(child: _Field(
                    label: 'DEPOSIT PAID',
                    child: _text(_depositCtrl, '0.00',
                        keyboardType: TextInputType.number),
                  )),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(child: _Field(
                    label: 'REMAINING BALANCE',
                    child: _ReadOnlyAmount(
                      amount:   _remainingBalance,
                      currency: _currencyCtrl.text.trim().isEmpty
                          ? 'USD'
                          : _currencyCtrl.text.trim(),
                    ),
                  )),
                ]),
                const SizedBox(height: AppSpacing.base),

                // Payment status
                _Field(
                  label: 'PAYMENT STATUS',
                  child: _EnumDropdown<PaymentStatus>(
                    value: _paymentStatus,
                    items: PaymentStatus.values,
                    labelOf: (s) => s.label,
                    onChanged: (v) => setState(() => _paymentStatus = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Notes
                _Field(
                  label: 'INTERNAL NOTES',
                  child: _text(_notesCtrl,
                      'Booking reference, instructions, remarks…',
                      maxLines: 3),
                ),
              ],
            ),
          ),
        ),
        _EditorFooter(onSave: _save),
      ],
    );
  }

  Widget _text(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType? keyboardType, FocusNode? focusNode}) {
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: 1,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
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
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier suggestion panel
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierSuggestionPanel extends StatelessWidget {
  final List<Supplier> suggestions;
  final void Function(Supplier) onSelect;

  const _SupplierSuggestionPanel({
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: suggestions.map((s) {
          final isLast = s == suggestions.last;
          return InkWell(
            onTap: () => onSelect(s),
            borderRadius: isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8))
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 9),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: s.category.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(s.category.icon,
                        size: 12, color: s.category.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.name,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s.city.isNotEmpty)
                    Text(
                      s.city,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared editor sub-widgets
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
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(isEditing ? 'Edit Cost Item' : 'Add Cost Item',
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

class _EditorFooter extends StatelessWidget {
  final VoidCallback onSave;
  const _EditorFooter({required this.onSave});

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

class _TripDropdown extends StatelessWidget {
  final List<Trip> trips;
  final String value;
  final ValueChanged<String> onChanged;
  const _TripDropdown({
    required this.trips,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text('No trips', style: AppTextStyles.bodySmall),
      );
    }
    final selected = trips.firstWhere(
      (t) => t.id == value,
      orElse: () => trips.first,
    );
    return _StyledDropdown<Trip>(
      value: selected,
      items: trips,
      labelOf: (t) => t.name,
      onChanged: (t) => onChanged(t.id),
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _EnumDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StyledDropdown<T>(
        value: value, items: items, labelOf: labelOf, onChanged: onChanged);
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
                    child: Text(labelOf(item),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier picker
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierPickerField extends StatelessWidget {
  final Supplier? selected;
  final List<Supplier> suppliers;
  final CostCategory category;
  final ValueChanged<Supplier?> onChanged;

  const _SupplierPickerField({
    required this.selected,
    required this.suppliers,
    required this.category,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<Supplier?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => _SupplierSearchSheet(
            suppliers: suppliers,
            category:  category,
            selected:  selected,
          ),
        );
        // result == null means the sheet was dismissed without a selection.
        // result == Supplier means a supplier was picked.
        // The sheet returns a sentinel _kClearSupplier to signal "clear".
        if (result == _kClearSupplier) {
          onChanged(null);
        } else if (result != null) {
          onChanged(result);
        }
      },
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
            if (selected != null) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected!.category.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(selected!.category.icon,
                    size: 11, color: selected!.category.color),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                selected?.name ?? 'Select supplier (optional)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: selected != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              )
            else
              const Icon(Icons.search_rounded,
                  size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// Sentinel object used to signal "clear selection" from the search sheet.
final _kClearSupplier = Supplier(
  id: '__clear__', name: '', category: SupplierCategory.other,
  city: '', country: '',
);

class _SupplierSearchSheet extends StatefulWidget {
  final List<Supplier> suppliers;
  final CostCategory category;
  final Supplier? selected;

  const _SupplierSearchSheet({
    required this.suppliers,
    required this.category,
    required this.selected,
  });

  @override
  State<_SupplierSearchSheet> createState() => _SupplierSearchSheetState();
}

class _SupplierSearchSheetState extends State<_SupplierSearchSheet> {
  late final TextEditingController _searchCtrl;
  late List<Supplier> _filtered;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtered   = _buildFiltered('');
    _searchCtrl.addListener(() {
      setState(() => _filtered = _buildFiltered(_searchCtrl.text));
    });
  }

  List<Supplier> _buildFiltered(String query) {
    final q = query.toLowerCase().trim();
    return widget.suppliers
        .where((s) => q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) {
        // Preferred first, then alphabetical
        if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
        return a.name.compareTo(b.name);
      });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text('Select Supplier', style: AppTextStyles.heading3),
                const Spacer(),
                if (widget.selected != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _kClearSupplier),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:    'Search suppliers…',
                hintStyle:   AppTextStyles.bodySmall,
                prefixIcon:  const Icon(Icons.search_rounded,
                    size: 16, color: AppColors.textMuted),
                filled:      true,
                fillColor:   AppColors.surfaceAlt,
                isDense:     true,
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
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text('No suppliers found',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final s        = _filtered[i];
                      final isSelected = s.id == widget.selected?.id;
                      return InkWell(
                        onTap: () => Navigator.pop(context, s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.base,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentFaint
                                : Colors.transparent,
                            border: const Border(
                                bottom: BorderSide(color: AppColors.divider)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: s.category.color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(s.category.icon,
                                    size: 14, color: s.category.color),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        )),
                                    if (s.city.isNotEmpty)
                                      Text(s.city,
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                  color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              if (s.preferred)
                                const Icon(Icons.star_rounded,
                                    size: 13, color: Color(0xFFC9A96E)),
                              if (isSelected)
                                const Icon(Icons.check_rounded,
                                    size: 14, color: AppColors.accent),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}

class _ReadOnlyAmount extends StatelessWidget {
  final double amount;
  final String currency;
  const _ReadOnlyAmount({required this.amount, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isOwed  = amount > 0.005;
    final color   = isOwed ? const Color(0xFFD4845A) : const Color(0xFF5A9E6F);
    final display = NumberFormat('#,##0.00').format(amount.abs());
    return Container(
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
              '$currency $display',
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            isOwed ? 'owed' : 'settled',
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final ValueChanged<DateTime?> onChanged;
  const _DatePicker({required this.value, required this.hint, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
        : DateFormat('d MMM yyyy').format(value!);

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
              child: Text(label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: value == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  )),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              )
            else
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
