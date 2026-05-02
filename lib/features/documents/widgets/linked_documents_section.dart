import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_document.dart';
import '../../../data/repositories/trip_document_repository.dart';
import '../providers/documents_provider.dart';
import 'document_upload_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LinkedDocumentsSection
//
// Compact self-contained widget that shows documents linked to a specific
// entity (component, cost item, or run sheet item). Fetches directly from
// the repository so it can be embedded anywhere without a shared provider.
// ─────────────────────────────────────────────────────────────────────────────

class LinkedDocumentsSection extends StatefulWidget {
  final String  tripId;
  final String? componentId;
  final String? costItemId;
  final String? runSheetItemId;
  /// When uploading from a component editor, also stamp this costItemId on
  /// new documents so they appear in the linked budget cost item editor too.
  final String? alsoLinkCostItemId;

  const LinkedDocumentsSection({
    super.key,
    required this.tripId,
    this.componentId,
    this.costItemId,
    this.runSheetItemId,
    this.alsoLinkCostItemId,
  });

  @override
  State<LinkedDocumentsSection> createState() => _LinkedDocumentsSectionState();
}

class _LinkedDocumentsSectionState extends State<LinkedDocumentsSection> {
  TripDocumentRepository? get _repo =>
      AppRepositories.instance?.documents;

  DocumentsProvider? _provider;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = DocumentsProvider(
      tripId:     widget.tripId,
      teamId:     repos?.currentTeamId,
      repository: repos?.documents,
      autoLoad:   false,
    );
    _loadForContext();
  }

  @override
  void dispose() {
    _provider?.dispose();
    super.dispose();
  }

  Future<void> _loadForContext() async {
    if (_repo == null) return;
    try {
      List<TripDocument> docs;
      if (widget.componentId != null) {
        docs = await _repo!.fetchForComponent(widget.componentId!);
      } else if (widget.costItemId != null) {
        // Also includes docs from the component that owns this cost item
        docs = await _repo!.fetchForCostItemOrLinkedComponent(widget.costItemId!);
      } else if (widget.runSheetItemId != null) {
        docs = await _repo!.fetchForRunSheetItem(widget.runSheetItemId!);
      } else {
        return;
      }
      if (mounted && _provider != null) {
        _provider!.seedDocuments(docs);
      }
    } catch (_) {}
  }

  void _openUploadSheet() async {
    if (_provider == null) return;
    await showDocumentUploadSheet(
      context,
      tripId:               widget.tripId,
      provider:             _provider!,
      presetComponentId:    widget.componentId,
      // When in component context, also stamp the linked cost item id so the
      // doc shows up in the budget editor without needing re-upload.
      presetCostItemId:     widget.costItemId ?? widget.alsoLinkCostItemId,
      presetRunSheetItemId: widget.runSheetItemId,
    );
    // Reload to pick up the newly saved document
    _loadForContext();
  }

  void _openEditSheet(TripDocument doc) async {
    if (_provider == null) return;
    await showDocumentUploadSheet(
      context,
      tripId:   widget.tripId,
      provider: _provider!,
      existing: doc,
    );
    _loadForContext();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _provider!,
      builder: (context, _) {
        final docs = _provider!.all;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'DOCUMENTS',
                    style: AppTextStyles.overline
                        .copyWith(letterSpacing: 1.2),
                  ),
                  if (docs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color:        AppColors.accentFaint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: AppTextStyles.overline
                            .copyWith(color: AppColors.accent),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: _openUploadSheet,
                    child: Text(
                      '+ Add',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size:  16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),

            if (_expanded) ...[
              const SizedBox(height: AppSpacing.sm),
              if (docs.isEmpty)
                Text(
                  'No documents attached.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                )
              else
                Column(
                  children: [
                    for (final doc in docs) ...[
                      _LinkedDocRow(
                        doc:       doc,
                        onEdit:    () => _openEditSheet(doc),
                        onArchive: () => _provider!.archive(doc.id),
                      ),
                      if (doc != docs.last)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
            ],
          ],
        );
      },
    );
  }
}

// ── Compact document row ──────────────────────────────────────────────────────

class _LinkedDocRow extends StatelessWidget {
  final TripDocument  doc;
  final VoidCallback  onEdit;
  final VoidCallback  onArchive;
  const _LinkedDocRow({
    required this.doc,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Type icon
          Container(
            width:  32,
            height: 32,
            decoration: BoxDecoration(
              color:        doc.documentType.bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(doc.documentType.icon,
                size: 15, color: doc.documentType.color),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    _StatusDot(status: doc.status),
                    const SizedBox(width: 4),
                    Text(
                      doc.status.label,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: doc.status.color),
                    ),
                    if (doc.expiryDate != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        doc.isExpired
                            ? Icons.error_outline_rounded
                            : Icons.event_outlined,
                        size:  10,
                        color: doc.isExpired
                            ? const Color(0xFFDC2626)
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        DateFormat('d MMM yy').format(doc.expiryDate!),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: doc.isExpired
                              ? const Color(0xFFDC2626)
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Open link
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(doc.fileUrl),
                mode: LaunchMode.externalApplication),
            child: const Icon(Icons.open_in_new_rounded,
                size: 14, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),

          // More menu
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit')    onEdit();
              if (v == 'archive') onArchive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit'),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
            child: const Icon(Icons.more_horiz_rounded,
                size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final DocumentStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        width:  6,
        height: 6,
        decoration: BoxDecoration(
          color:  status.color,
          shape:  BoxShape.circle,
        ),
      );
}
