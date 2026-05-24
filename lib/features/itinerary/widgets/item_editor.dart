import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/supplier_media.dart';
import '../../../data/models/supplier_model.dart';
import '../../../features/ai_suggestions/services/suggestion_apply_service.dart';
import '../../../features/signature_experiences/widgets/signature_experience_picker_modal.dart';
import '../../../features/suppliers/providers/supplier_provider.dart';
import '../../../features/suppliers/widgets/supplier_editor.dart';
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
        initialChildSize: 0.9,
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
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820),
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
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _notesCtrl;

  // Supplier picker state
  String? _supplierId;
  String? _supplierName;
  List<Supplier> _allSuppliers = [];
  bool _suppliersLoading = false;

  // Gallery state
  List<SupplierMedia> _supplierMedia = [];
  bool _mediaLoading = false;
  List<String> _selectedMediaIds = [];

  bool get _isEditing => widget.existing != null;
  bool _saving = false;
  bool _titleError = false;

  SupplierType? get _supplierTypeFilter => switch (_type) {
        ItemType.hotel      => SupplierType.accommodation,
        ItemType.dining     => SupplierType.dining,
        ItemType.transport  => SupplierType.transport,
        ItemType.flight     => SupplierType.transport,
        ItemType.experience => SupplierType.experienceProvider,
        ItemType.note       => null,
      };

  List<Supplier> get _filteredSuppliers {
    final target = _supplierTypeFilter;
    if (target == null) return _allSuppliers;
    return _allSuppliers
        .where((s) => s.effectiveSupplierType == target)
        .toList();
  }

  Future<void> _loadSuppliers() async {
    final repos = AppRepositories.instance;
    if (repos == null) return;
    setState(() => _suppliersLoading = true);
    try {
      final list = await repos.suppliers.fetchAll(repos.currentTeamId ?? '');
      if (mounted) setState(() => _allSuppliers = list);
    } catch (_) {}
    if (mounted) setState(() => _suppliersLoading = false);
  }

  Future<void> _loadSupplierMedia(String supplierId) async {
    final repos = AppRepositories.instance;
    if (repos == null) return;
    setState(() => _mediaLoading = true);
    try {
      final media = await repos.supplierMedia.fetchForSupplier(supplierId);
      if (mounted) {
        setState(() => _supplierMedia =
            media.where((m) => m.isActive && m.mediaType == SupplierMediaType.image).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _mediaLoading = false);
  }

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
    final p = widget.prefill;

    _type      = e?.type      ?? _itemTypeFromPrefill(p) ?? ItemType.experience;
    _status    = e?.status    ?? ItemStatus.draft;
    _timeBlock = e?.timeBlock ?? _timeBlockFromPrefill(p) ?? TimeBlock.morning;
    _startTime = e?.startTime;
    _endTime   = e?.endTime;

    _titleCtrl       = TextEditingController(text: e?.title       ?? p?.title       ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? p?.description ?? '');
    _locationCtrl    = TextEditingController(text: e?.location    ?? p?.location    ?? '');
    _latCtrl  = TextEditingController(
        text: e?.latitude  != null ? e!.latitude!.toString()  : '');
    _lngCtrl  = TextEditingController(
        text: e?.longitude != null ? e!.longitude!.toString() : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');

    _supplierId   = e?.supplierId;
    _supplierName = e?.supplierName;

    final galleryList = e?.detailsJson['gallery_ids'];
    _selectedMediaIds = galleryList is List
        ? List<String>.from(galleryList.whereType<String>())
        : [];

    _loadSuppliers();
    if (_supplierId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadSupplierMedia(_supplierId!));
    }
  }

  ItemType? _itemTypeFromPrefill(ItemPrefill? p) => p?.type;
  TimeBlock? _timeBlockFromPrefill(ItemPrefill? p) => p?.timeBlock;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parseCoord(String raw) {
    final v = double.tryParse(raw.trim());
    return (v == null || v == 0) ? null : v;
  }

  Future<void> _save() async {
    debugPrint('[ItemEditor._save] called, isEditing=$_isEditing dayId=${widget.dayId}');
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() { _saving = true; _titleError = false; });

    try {
      final lat = _parseCoord(_latCtrl.text);
      final lng = _parseCoord(_lngCtrl.text);
      final gallery = _selectedMediaIds.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'gallery_ids': _selectedMediaIds};

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          type:        _type,
          title:       title,
          description: _descriptionCtrl.text.trim(),
          clearDescription: _descriptionCtrl.text.trim().isEmpty,
          startTime:   _startTime,
          clearStartTime: _startTime == null,
          endTime:     _endTime,
          clearEndTime: _endTime == null,
          timeBlock:   _timeBlock,
          location:    _locationCtrl.text.trim(),
          clearLocation: _locationCtrl.text.trim().isEmpty,
          supplierId:  _supplierId,
          clearSupplierId: _supplierId == null,
          supplierName: _supplierName,
          clearSupplierName: _supplierName == null,
          status:      _status,
          notes:       _notesCtrl.text.trim(),
          clearNotes:  _notesCtrl.text.trim().isEmpty,
          latitude:    lat,
          clearLatitude: lat == null,
          longitude:   lng,
          clearLongitude: lng == null,
          detailsJson: gallery,
        );
        await widget.provider.updateItem(updated);
      } else {
        final desc     = _descriptionCtrl.text.trim();
        final location = _locationCtrl.text.trim();
        final notes    = _notesCtrl.text.trim();

        final item = ItineraryItem(
          id:          widget.provider.generateItemId(),
          tripDayId:   widget.dayId,
          type:        _type,
          title:       title,
          description: desc.isEmpty ? null : desc,
          startTime:   _startTime,
          endTime:     _endTime,
          timeBlock:   _timeBlock,
          location:    location.isEmpty ? null : location,
          supplierId:  _supplierId,
          supplierName: _supplierName,
          status:      _status,
          notes:       notes.isEmpty ? null : notes,
          latitude:    lat,
          longitude:   lng,
          detailsJson: gallery,
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

  void _onSupplierSelected(String id, String name) {
    final changed = _supplierId != id;
    setState(() {
      _supplierId   = id;
      _supplierName = name;
      if (changed) {
        _supplierMedia    = [];
        _selectedMediaIds = [];
      }
    });
    if (changed) _loadSupplierMedia(id);
  }

  void _onSupplierCleared() {
    setState(() {
      _supplierId       = null;
      _supplierName     = null;
      _supplierMedia    = [];
      _selectedMediaIds = [];
    });
  }

  Future<void> _onAddNewSupplier() async {
    final repos = AppRepositories.instance;
    if (repos == null || !context.mounted) return;
    final tempProvider = SupplierProvider(
      repository: repos.suppliers,
      teamId:     repos.currentTeamId ?? '',
    );
    final existingIds = _allSuppliers.map((s) => s.id).toSet();
    await showSupplierEditor(
      context,
      provider:            tempProvider,
      initialSupplierType: _supplierTypeFilter,
    );
    if (!context.mounted) return;
    setState(() => _suppliersLoading = true);
    final fresh = await repos.suppliers.fetchAll(repos.currentTeamId ?? '');
    if (!context.mounted) return;
    final newSupplier =
        fresh.where((s) => !existingIds.contains(s.id)).firstOrNull;
    setState(() {
      _allSuppliers     = fresh;
      _suppliersLoading = false;
      if (newSupplier != null) {
        _supplierId       = newSupplier.id;
        _supplierName     = newSupplier.name;
        _supplierMedia    = [];
        _selectedMediaIds = [];
      }
    });
    if (newSupplier != null) _loadSupplierMedia(newSupplier.id);
    tempProvider.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorHeader(isEditing: _isEditing),

        // Experience library shortcut
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
                  color:        AppColors.accentFaint,
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                  border:       Border.all(color: AppColors.accentLight),
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
                    child: Text('Title is required',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.red.shade400)),
                  ),
                const SizedBox(height: AppSpacing.base),

                // Type + Status
                Row(children: [
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
                ]),
                const SizedBox(height: AppSpacing.base),

                // Time block
                _EditorField(
                  label: 'TIME BLOCK',
                  child: _TimeBlockDropdown(
                    value: _timeBlock,
                    onChanged: (v) => setState(() => _timeBlock = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Start / end time
                Row(children: [
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
                ]),
                const SizedBox(height: AppSpacing.base),

                // Location + coordinates
                _EditorField(
                  label: 'LOCATION',
                  child: _textField(_locationCtrl, 'Address or venue name'),
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(children: [
                  Expanded(
                    child: _EditorField(
                      label: 'LATITUDE',
                      child: _textField(_latCtrl, 'e.g. 35.6762',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: _EditorField(
                      label: 'LONGITUDE',
                      child: _textField(_lngCtrl, 'e.g. 139.6503',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true)),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.base),

                // ── Supplier picker ─────────────────────────────────────────
                _EditorField(
                  label: 'SUPPLIER',
                  child: _suppliersLoading
                      ? _loadingField()
                      : _ItemSupplierPickerField(
                          selectedId:   _supplierId,
                          selectedName: _supplierName,
                          suppliers:    _filteredSuppliers,
                          allSuppliers: _allSuppliers,
                          onSelected:   _onSupplierSelected,
                          onCleared:    _onSupplierCleared,
                          onAddNew:     _onAddNewSupplier,
                        ),
                ),

                // ── Gallery ─────────────────────────────────────────────────
                if (_supplierId != null) ...[
                  const SizedBox(height: AppSpacing.base),
                  _EditorField(
                    label: 'GALLERY IMAGES',
                    child: _mediaLoading
                        ? _loadingField()
                        : _GallerySection(
                            media:       _supplierMedia,
                            selectedIds: _selectedMediaIds,
                            onToggle: (id) => setState(() {
                              if (_selectedMediaIds.contains(id)) {
                                _selectedMediaIds.remove(id);
                              } else {
                                _selectedMediaIds.add(id);
                              }
                            }),
                          ),
                  ),
                ],
                const SizedBox(height: AppSpacing.base),

                // Description
                _EditorField(
                  label: 'DESCRIPTION',
                  child: _textField(
                      _descriptionCtrl, 'Additional details…', maxLines: 3),
                ),
                const SizedBox(height: AppSpacing.base),

                // Internal notes
                _EditorField(
                  label: 'INTERNAL NOTES',
                  child: _textField(
                      _notesCtrl, 'Notes for the ops team…', maxLines: 2),
                ),
              ],
            ),
          ),
        ),

        _EditorFooter(onSave: _saving ? null : _save, saving: _saving),
      ],
    );
  }

  Widget _loadingField() => Container(
        height: 42,
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool hasError = false,
    TextInputType? keyboardType,
  }) {
    final errorColor = Colors.red.shade400;
    return TextField(
      controller:  ctrl,
      style:       AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      maxLines:    maxLines,
      minLines:    1,
      keyboardType: keyboardType,
      onChanged:   hasError ? (_) => setState(() => _titleError = false) : null,
      decoration: InputDecoration(
        hintText:       hint,
        hintStyle:      AppTextStyles.bodySmall,
        filled:         true,
        fillColor:      AppColors.surfaceAlt,
        isDense:        true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: hasError ? errorColor : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: hasError ? errorColor : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(
              color: hasError ? errorColor : AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier picker field + search sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ItemSupplierPickerField extends StatelessWidget {
  final String?          selectedId;
  final String?          selectedName;
  final List<Supplier>   suppliers;
  final List<Supplier>   allSuppliers;
  final void Function(String id, String name) onSelected;
  final VoidCallback     onCleared;
  final VoidCallback?    onAddNew;

  const _ItemSupplierPickerField({
    required this.selectedId,
    required this.selectedName,
    required this.suppliers,
    required this.allSuppliers,
    required this.onSelected,
    required this.onCleared,
    this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_outlined,
                size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedName ?? 'Search suppliers…',
                style: AppTextStyles.bodySmall.copyWith(
                  color: selectedName != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selectedId != null)
              GestureDetector(
                onTap: onCleared,
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

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSupplierSearchSheet(
        suppliers:    suppliers,
        allSuppliers: allSuppliers,
        onAddNew:     onAddNew,
      ),
    );
    if (result == null) return;
    onSelected(result.id, result.name);
  }
}

class _ItemSupplierSearchSheet extends StatefulWidget {
  final List<Supplier>  suppliers;
  final List<Supplier>  allSuppliers;
  final VoidCallback?   onAddNew;

  const _ItemSupplierSearchSheet({
    required this.suppliers,
    required this.allSuppliers,
    this.onAddNew,
  });

  @override
  State<_ItemSupplierSearchSheet> createState() =>
      _ItemSupplierSearchSheetState();
}

class _ItemSupplierSearchSheetState extends State<_ItemSupplierSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query   = '';
  bool   _showAll = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Supplier> get _source =>
      _showAll ? widget.allSuppliers : widget.suppliers;

  List<Supplier> get _results {
    if (_query.isEmpty) return _source;
    final q = _query.toLowerCase();
    return _source
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              child: TextField(
                controller:   _searchCtrl,
                autofocus:    true,
                style:        AppTextStyles.bodySmall,
                decoration: InputDecoration(
                  hintText:  'Search by name or city…',
                  hintStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: AppColors.textMuted),
                  filled:    true,
                  fillColor: AppColors.surfaceAlt,
                  isDense:   true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),

            // "Show all types" toggle
            if (!_showAll && widget.suppliers.length < widget.allSuppliers.length)
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.base,
                    right: AppSpacing.base,
                    bottom: AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => setState(() => _showAll = true),
                  child: Text('Show all supplier types',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accent)),
                ),
              ),

            // Results
            Expanded(
              child: results.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final s = results[i];
                        return ListTile(
                          leading: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color:
                                  s.effectiveSupplierType.color.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(s.effectiveSupplierType.icon,
                                size: 16,
                                color: s.effectiveSupplierType.color),
                          ),
                          title: Text(s.name,
                              style: AppTextStyles.bodyMedium),
                          subtitle: Text(
                            '${s.effectiveSupplierType.label}'
                            '${s.city.isNotEmpty ? ' · ${s.city}' : ''}',
                            style: AppTextStyles.bodySmall,
                          ),
                          onTap: () => Navigator.of(context)
                              .pop((id: s.id, name: s.name)),
                        );
                      },
                    ),
            ),

            // Add new supplier button
            const Divider(height: 1, color: AppColors.divider),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon:  const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add New Supplier'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onAddNew?.call();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No suppliers found',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted)),
          if (!_showAll &&
              widget.suppliers.length < widget.allSuppliers.length) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _showAll = true),
              child: Text('Show all supplier types',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.accent)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery section
// ─────────────────────────────────────────────────────────────────────────────

class _GallerySection extends StatelessWidget {
  final List<SupplierMedia> media;
  final List<String>        selectedIds;
  final void Function(String id) onToggle;

  const _GallerySection({
    required this.media,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border),
        ),
        child: Text(
          'No images found in this supplier\'s media library.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select images to include in this itinerary item',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:       media.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final m          = media[i];
              final isSelected = selectedIds.contains(m.id);
              return GestureDetector(
                onTap: () => onToggle(m.id),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        m.thumbnailUrl ?? m.fileUrl,
                        width: 90, height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 90, height: 90,
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.broken_image_outlined,
                              color: AppColors.textMuted, size: 22),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accent, width: 2.5),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 22),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${selectedIds.length} image${selectedIds.length == 1 ? '' : 's'} selected',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
      ],
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
          Text(isEditing ? 'Edit Item' : 'Add Itinerary Item',
              style: AppTextStyles.heading3),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color:        AppColors.surfaceAlt,
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
                side:  const BorderSide(color: AppColors.border),
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
                          strokeWidth: 2, color: Colors.white))
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

// ── Dropdowns ──────────────────────────────────────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  final ItemType value;
  final ValueChanged<ItemType> onChanged;
  const _TypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _StyledDropdown<ItemType>(
        value: value,
        items: ItemType.values,
        labelOf: (t) => t.label,
        onChanged: onChanged,
      );
}

class _StatusDropdown extends StatelessWidget {
  final ItemStatus value;
  final ValueChanged<ItemStatus> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _StyledDropdown<ItemStatus>(
        value: value,
        items: ItemStatus.values,
        labelOf: (s) => s.label,
        onChanged: onChanged,
      );
}

class _TimeBlockDropdown extends StatelessWidget {
  final TimeBlock value;
  final ValueChanged<TimeBlock> onChanged;
  const _TimeBlockDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _StyledDropdown<TimeBlock>(
        value: value,
        items: TimeBlock.values,
        labelOf: (b) => b.label,
        onChanged: onChanged,
      );
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
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:       value,
          isDense:     true,
          isExpanded:  true,
          style:       AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
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
  final String     hint;
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
            primary:   AppColors.accent,
            onPrimary: Colors.white,
            surface:   AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value == null ? hint : value!.format(context);
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppColors.border),
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
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
