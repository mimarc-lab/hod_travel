import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_document.dart';
import '../providers/documents_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showDocumentUploadSheet
// ─────────────────────────────────────────────────────────────────────────────

Future<TripDocument?> showDocumentUploadSheet(
  BuildContext context, {
  required String           tripId,
  required DocumentsProvider provider,
  TripDocument?             existing,
  DocumentType?             presetType,
  String?                   presetComponentId,
  String?                   presetCostItemId,
  String?                   presetRunSheetItemId,
}) {
  return showModalBottomSheet<TripDocument>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => _DocumentUploadSheet(
      tripId:               tripId,
      provider:             provider,
      existing:             existing,
      presetType:           presetType,
      presetComponentId:    presetComponentId,
      presetCostItemId:     presetCostItemId,
      presetRunSheetItemId: presetRunSheetItemId,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _DocumentUploadSheet extends StatefulWidget {
  final String            tripId;
  final DocumentsProvider provider;
  final TripDocument?     existing;
  final DocumentType?     presetType;
  final String?           presetComponentId;
  final String?           presetCostItemId;
  final String?           presetRunSheetItemId;

  const _DocumentUploadSheet({
    required this.tripId,
    required this.provider,
    this.existing,
    this.presetType,
    this.presetComponentId,
    this.presetCostItemId,
    this.presetRunSheetItemId,
  });

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _fileUrlCtrl;
  late TextEditingController _fileNameCtrl;
  late TextEditingController _notesInternalCtrl;
  late TextEditingController _notesClientCtrl;

  late DocumentType   _docType;
  late DocumentStatus _status;
  bool                _isClientVisible = false;
  DateTime?           _issueDate;
  DateTime?           _expiryDate;
  bool                _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _docType  = e?.documentType ?? widget.presetType ?? DocumentType.bookingConfirmation;
    _status   = e?.status       ?? DocumentStatus.uploaded;
    _isClientVisible = e?.isClientVisible ?? false;
    _issueDate  = e?.issueDate;
    _expiryDate = e?.expiryDate;

    _titleCtrl         = TextEditingController(text: e?.title           ?? '');
    _fileUrlCtrl       = TextEditingController(text: e?.fileUrl         ?? '');
    _fileNameCtrl      = TextEditingController(text: e?.fileName        ?? '');
    _notesInternalCtrl = TextEditingController(text: e?.notesInternal   ?? '');
    _notesClientCtrl   = TextEditingController(text: e?.notesClient     ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _fileUrlCtrl.dispose();
    _fileNameCtrl.dispose();
    _notesInternalCtrl.dispose();
    _notesClientCtrl.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final userId = AppRepositories.instance?.currentUserId ?? '';

    final doc = TripDocument(
      id:              widget.existing?.id ?? '',
      teamId:          widget.existing?.teamId ?? '',
      tripId:          widget.tripId,
      componentId:     widget.presetComponentId    ?? widget.existing?.componentId,
      costItemId:      widget.presetCostItemId     ?? widget.existing?.costItemId,
      runSheetItemId:  widget.presetRunSheetItemId ?? widget.existing?.runSheetItemId,
      supplierId:      widget.existing?.supplierId,
      itineraryItemId: widget.existing?.itineraryItemId,
      documentType:    _docType,
      title:           _titleCtrl.text.trim(),
      fileUrl:         _fileUrlCtrl.text.trim(),
      fileName:        _nullIfEmpty(_fileNameCtrl.text),
      mimeType:        _guessMime(_fileUrlCtrl.text.trim()),
      status:          _status,
      isClientVisible: _isClientVisible,
      issueDate:       _issueDate,
      expiryDate:      _expiryDate,
      uploadedAt:      widget.existing?.uploadedAt ?? DateTime.now(),
      uploadedBy:      widget.existing?.uploadedBy ?? userId,
      notesInternal:   _nullIfEmpty(_notesInternalCtrl.text),
      notesClient:     _nullIfEmpty(_notesClientCtrl.text),
    );

    TripDocument? saved;
    if (_isEditing) {
      saved = await widget.provider.updateDoc(doc);
    } else {
      saved = await widget.provider.create(doc);
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  String? _guessMime(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf'))  return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png'))  return 'image/png';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin:     const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width:      36,
              height:     4,
              decoration: BoxDecoration(
                color:        AppColors.border,
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
                  _isEditing ? 'Edit Document' : 'Add Document',
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
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  child: _saving
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingH,
                  vertical:   AppSpacing.base,
                ),
                children: [
                  // ── Document type ──────────────────────────────────────────
                  _sectionLabel('Document Type'),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeSelector(
                    selected:  _docType,
                    onChanged: (t) => setState(() => _docType = t),
                  ),
                  _divider(),

                  // ── Details ────────────────────────────────────────────────
                  _sectionLabel('Details'),
                  _gap(),
                  _labeled(
                    'Title *',
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: _deco('e.g. Hotel Mulia – Booking Confirmation'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  _rowGap(),
                  _labeled(
                    'File URL *',
                    TextFormField(
                      controller:  _fileUrlCtrl,
                      decoration:  _deco('https://... or storage path'),
                      keyboardType: TextInputType.url,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'URL is required' : null,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  _rowGap(),
                  _labeled(
                    'File Name',
                    TextFormField(
                      controller: _fileNameCtrl,
                      decoration: _deco('e.g. booking-confirmation.pdf'),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  _divider(),

                  // ── Status ─────────────────────────────────────────────────
                  _sectionLabel('Status'),
                  _gap(),
                  _StatusSelector(
                    selected:  _status,
                    onChanged: (s) => setState(() => _status = s),
                  ),
                  _divider(),

                  // ── Dates ──────────────────────────────────────────────────
                  _sectionLabel('Dates'),
                  _gap(),
                  Row(children: [
                    Expanded(child: _labeled(
                      'Issue Date',
                      _DateField(
                        value:    _issueDate,
                        onPicked: (d) => setState(() => _issueDate = d),
                      ),
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _labeled(
                      'Expiry Date',
                      _DateField(
                        value:    _expiryDate,
                        onPicked: (d) => setState(() => _expiryDate = d),
                      ),
                    )),
                  ]),
                  _divider(),

                  // ── Visibility ─────────────────────────────────────────────
                  _sectionLabel('Visibility'),
                  _gap(),
                  GestureDetector(
                    onTap: () => setState(() => _isClientVisible = !_isClientVisible),
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
                          Switch.adaptive(
                            value:            _isClientVisible,
                            onChanged:        (v) => setState(() => _isClientVisible = v),
                            activeThumbColor: AppColors.accent,
                            activeTrackColor: AppColors.accentLight,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visible to Client',
                                    style: AppTextStyles.bodyMedium),
                                Text(
                                  'Show this document in client-facing views',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _divider(),

                  // ── Notes ──────────────────────────────────────────────────
                  _sectionLabel('Notes'),
                  _gap(),
                  _labeled(
                    'Internal Notes',
                    TextFormField(
                      controller: _notesInternalCtrl,
                      decoration: _deco('Visible to team only'),
                      maxLines:   3,
                      style:      AppTextStyles.bodyMedium,
                    ),
                  ),
                  _rowGap(),
                  _labeled(
                    'Client Notes',
                    TextFormField(
                      controller: _notesClientCtrl,
                      decoration: _deco('Visible on client documents'),
                      maxLines:   2,
                      style:      AppTextStyles.bodyMedium,
                    ),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(t, style: AppTextStyles.overline),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Divider(height: 1, color: AppColors.divider),
      );

  Widget _gap()    => const SizedBox(height: AppSpacing.sm);
  Widget _rowGap() => const SizedBox(height: AppSpacing.sm);

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText:  hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        filled:    true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical:   AppSpacing.md,
        ),
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
          borderSide:   const BorderSide(color: AppColors.accent),
        ),
      );
}

// ── Type selector ─────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final DocumentType                selected;
  final ValueChanged<DocumentType>  onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: DocumentType.values.map((t) {
        final isSelected = t == selected;
        return GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color:        isSelected ? t.bgColor : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? t.color.withAlpha(120) : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.icon, size: 12,
                    color: isSelected ? t.color : AppColors.textMuted),
                const SizedBox(width: 5),
                Text(
                  t.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      isSelected ? t.color : AppColors.textMuted,
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
  final DocumentStatus               selected;
  final ValueChanged<DocumentStatus> onChanged;
  const _StatusSelector({required this.selected, required this.onChanged});

  static const _shown = [
    DocumentStatus.uploaded,
    DocumentStatus.reviewed,
    DocumentStatus.approved,
    DocumentStatus.missing,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: _shown.map((s) {
        final isSelected = s == selected;
        return GestureDetector(
          onTap: () => onChanged(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:        isSelected ? s.bgColor : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? s.color.withAlpha(120) : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: isSelected ? s.color : AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  s.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color:      isSelected ? s.color : AppColors.textMuted,
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

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime?              value;
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
          lastDate:    DateTime(2040),
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
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value != null
                    ? DateFormat('d MMM yyyy').format(value!)
                    : 'Select date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
