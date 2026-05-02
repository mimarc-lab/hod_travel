import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_document.dart';
import '../../../data/models/trip_model.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_filter_bar.dart';
import '../widgets/document_upload_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripDocumentsScreen
// ─────────────────────────────────────────────────────────────────────────────

class TripDocumentsScreen extends StatefulWidget {
  final Trip trip;
  const TripDocumentsScreen({super.key, required this.trip});

  @override
  State<TripDocumentsScreen> createState() => _TripDocumentsScreenState();
}

class _TripDocumentsScreenState extends State<TripDocumentsScreen>
    with AutomaticKeepAliveClientMixin {
  late final DocumentsProvider _provider;
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = DocumentsProvider(
      tripId:     widget.trip.id,
      teamId:     repos?.currentTeamId,
      repository: repos?.documents,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openUpload() => showDocumentUploadSheet(
        context,
        tripId:   widget.trip.id,
        provider: _provider,
      );

  void _openEdit(TripDocument doc) => showDocumentUploadSheet(
        context,
        tripId:   widget.trip.id,
        provider: _provider,
        existing: doc,
      );

  Future<void> _archive(TripDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Archive document?'),
        content: Text('"${doc.title}" will be archived and hidden from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _provider.archive(doc.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar — title + counter + search + add
        _Toolbar(
          onAdd:      _openUpload,
          onRefresh:  _provider.reload,
          provider:   _provider,
          searchCtrl: _searchCtrl,
          onSearch:   (v) {
            setState(() {});
            _provider.setSearchQuery(v);
          },
        ),

        // Filter chips only (search moved to toolbar)
        DocumentFilterBar(provider: _provider),

        const Divider(height: 1, color: AppColors.divider),

        // Content
        Expanded(
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              if (_provider.loading) {
                return const Center(child: CircularProgressIndicator(
                    color: AppColors.accent, strokeWidth: 2));
              }

              if (_provider.error != null) {
                return _ErrorState(
                  message: _provider.error!,
                  onRetry: () {
                    _provider.clearError();
                    _provider.reload();
                  },
                );
              }

              final docs = _provider.filtered;

              if (docs.isEmpty) {
                return _EmptyState(
                  hasFilter: _provider.filterType   != null ||
                             _provider.filterStatus != null ||
                             _provider.searchQuery.isNotEmpty,
                  onAdd: _openUpload,
                );
              }

              final userId = AppRepositories.instance?.currentUserId ?? '';

              return RefreshIndicator(
                onRefresh: _provider.reload,
                child: Column(
                  children: [
                    const _TableHeader(),
                    const Divider(height: 1, color: AppColors.divider),
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, i) => _DocumentTableRow(
                          key:            ValueKey(docs[i].id),
                          doc:            docs[i],
                          onEdit:         () => _openEdit(docs[i]),
                          onArchive:      () => _archive(docs[i]),
                          onMarkReviewed: () =>
                              _provider.markReviewed(docs[i], userId),
                          onMarkApproved: () =>
                              _provider.markApproved(docs[i], userId),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Toolbar (inline search) ───────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback              onAdd;
  final Future<void> Function()   onRefresh;
  final DocumentsProvider         provider;
  final TextEditingController     searchCtrl;
  final ValueChanged<String>      onSearch;

  const _Toolbar({
    required this.onAdd,
    required this.onRefresh,
    required this.provider,
    required this.searchCtrl,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical:   AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Title + counter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip Documents', style: AppTextStyles.heading2),
              const SizedBox(height: 2),
              ListenableBuilder(
                listenable: provider,
                builder: (_, _) => Text(
                  '${provider.all.length} document'
                  '${provider.all.length == 1 ? '' : 's'}'
                  '${provider.expiringCount > 0 ? '  ·  ${provider.expiringCount} expiring' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),

          const SizedBox(width: AppSpacing.lg),

          // Search box — grows to fill space
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextFormField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText:  'Search documents…',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: AppColors.textMuted),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 14, color: AppColors.textMuted),
                          onPressed: () {
                            searchCtrl.clear();
                            onSearch('');
                          },
                        )
                      : null,
                  filled:        true,
                  fillColor:     AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 0),
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
                ),
                style:     AppTextStyles.bodyMedium,
                onChanged: onSearch,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          IconButton(
            onPressed: onRefresh,
            icon:    const Icon(Icons.refresh_rounded, size: 18),
            color:   AppColors.textSecondary,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton.icon(
            onPressed: onAdd,
            icon:  const Icon(Icons.add, size: 16),
            label: const Text('Add Document'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical:   10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Text('DOCUMENT', style: _headerStyle),
          ),
          SizedBox(
            width: 140,
            child: Text('TYPE', style: _headerStyle),
          ),
          SizedBox(
            width: 100,
            child: Text('STATUS', style: _headerStyle),
          ),
          SizedBox(
            width: 130,
            child: Text('EXPIRY', style: _headerStyle),
          ),
          SizedBox(
            width: 70,
            child: Text('SIZE', style: _headerStyle),
          ),
          const SizedBox(width: 32), // client visible icon
          const SizedBox(width: 32), // action menu
        ],
      ),
    );
  }

  static final _headerStyle = AppTextStyles.overline.copyWith(
    color:         AppColors.textMuted,
    letterSpacing: 0.8,
  );
}

// ── Table row ─────────────────────────────────────────────────────────────────

class _DocumentTableRow extends StatelessWidget {
  final TripDocument  doc;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onMarkApproved;

  const _DocumentTableRow({
    super.key,
    required this.doc,
    this.onEdit,
    this.onArchive,
    this.onMarkReviewed,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired      = doc.isExpired;
    final isExpiringSoon = doc.isExpiringSoon;
    final typeColor      = doc.documentType.color;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: const BorderSide(color: AppColors.divider),
          left: BorderSide(
            color: isExpired
                ? const Color(0xFFDC2626)
                : isExpiringSoon
                    ? const Color(0xFFD97706)
                    : typeColor,
            width: 3,
          ),
        ),
        color: isExpired
            ? const Color(0xFFFEF2F2)
            : isExpiringSoon
                ? const Color(0xFFFFFBEB)
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          hoverColor:     AppColors.surfaceAlt,
          highlightColor: Colors.transparent,
          splashColor:    Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH,
              vertical:   AppSpacing.md,
            ),
            child: Row(
              children: [
                // Title + file name
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (doc.fileName?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          doc.fileName!,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Type badge
                SizedBox(
                  width: 140,
                  child: _TypeBadge(type: doc.documentType),
                ),

                // Status chip
                SizedBox(
                  width: 100,
                  child: _StatusChip(status: doc.status),
                ),

                // Expiry date
                SizedBox(
                  width: 130,
                  child: doc.expiryDate != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpired
                                  ? Icons.error_outline_rounded
                                  : isExpiringSoon
                                      ? Icons.warning_amber_rounded
                                      : Icons.event_outlined,
                              size: 12,
                              color: isExpired
                                  ? const Color(0xFFDC2626)
                                  : isExpiringSoon
                                      ? const Color(0xFFD97706)
                                      : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('d MMM yyyy')
                                  .format(doc.expiryDate!),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: isExpired
                                    ? const Color(0xFFDC2626)
                                    : isExpiringSoon
                                        ? const Color(0xFFD97706)
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : Text('—',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted)),
                ),

                // File size
                SizedBox(
                  width: 70,
                  child: Text(
                    doc.fileSizeLabel.isNotEmpty ? doc.fileSizeLabel : '—',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted),
                  ),
                ),

                // Client visible indicator
                SizedBox(
                  width: 32,
                  child: doc.isClientVisible
                      ? const Tooltip(
                          message: 'Client visible',
                          child: Icon(Icons.visibility_outlined,
                              size: 14, color: AppColors.accent),
                        )
                      : const SizedBox.shrink(),
                ),

                // Action menu
                SizedBox(
                  width: 32,
                  child: _ActionMenu(
                    doc:            doc,
                    onEdit:         onEdit,
                    onArchive:      onArchive,
                    onMarkReviewed: onMarkReviewed,
                    onMarkApproved: onMarkApproved,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared badge/chip widgets ─────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final DocumentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(type.icon, size: 12, color: type.color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            type.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: type.color,
              fontWeight: FontWeight.w500,
            ),
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DocumentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        status.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color:      status.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Action menu ───────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final TripDocument  doc;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onMarkApproved;

  const _ActionMenu({
    required this.doc,
    this.onEdit,
    this.onArchive,
    this.onMarkReviewed,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit')     onEdit?.call();
        if (v == 'archive')  onArchive?.call();
        if (v == 'reviewed') onMarkReviewed?.call();
        if (v == 'approved') onMarkApproved?.call();
        if (v == 'open')     debugPrint('[Doc] open: ${doc.fileUrl}');
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'open',
          child: Row(children: [
            Icon(Icons.open_in_new_rounded,
                size: 15, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Open / Download'),
          ]),
        ),
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined,
                  size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onMarkReviewed != null &&
            doc.status == DocumentStatus.uploaded)
          const PopupMenuItem(
            value: 'reviewed',
            child: Row(children: [
              Icon(Icons.rate_review_outlined,
                  size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Mark Reviewed'),
            ]),
          ),
        if (onMarkApproved != null &&
            doc.status != DocumentStatus.approved)
          const PopupMenuItem(
            value: 'approved',
            child: Row(children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 15, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Mark Approved',
                  style: TextStyle(color: Color(0xFF16A34A))),
            ]),
          ),
        const PopupMenuDivider(),
        if (onArchive != null)
          const PopupMenuItem(
            value: 'archive',
            child: Row(children: [
              Icon(Icons.archive_outlined,
                  size: 15, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text('Archive',
                  style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
      ],
      child: const Icon(Icons.more_horiz_rounded,
          size: 16, color: AppColors.textMuted),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onAdd;
  const _EmptyState({required this.hasFilter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accentFaint, shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_outlined,
                size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilter ? 'No documents match your filters' : 'No documents yet',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasFilter
                ? 'Try clearing your filters.'
                : 'Upload booking confirmations, invoices, vouchers and more.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (!hasFilter) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon:  const Icon(Icons.add, size: 16),
              label: const Text('Add Document'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: Colors.red),
            const SizedBox(height: AppSpacing.sm),
            Text('Failed to load documents', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.base),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
