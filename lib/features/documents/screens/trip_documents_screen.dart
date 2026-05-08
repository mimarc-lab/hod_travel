import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_document.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/adaptive_table/adaptive_column.dart';
import '../../../shared/adaptive_table/adaptive_mobile_card.dart';
import '../../../shared/adaptive_table/adaptive_row.dart';
import '../../../shared/design_system/responsive_breakpoints.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../../../shared/design_system/typography_tokens.dart';
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
        title: const Text('Archive document?'),
        content: Text(
            '"${doc.title}" will be archived and hidden from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.textMuted),
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
        _DocumentsToolbar(
          provider:   _provider,
          searchCtrl: _searchCtrl,
          onSearch:   _provider.setSearchQuery,
          onAdd:      _openUpload,
          onRefresh:  _provider.reload,
        ),
        DocumentFilterBar(provider: _provider),
        Expanded(
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              if (_provider.loading) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2),
                );
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
                  hasFilter: _provider.filterType != null ||
                      _provider.filterStatus != null ||
                      _provider.searchQuery.isNotEmpty,
                  onAdd: _openUpload,
                );
              }

              final layout = AdaptiveBreakpoints.layoutOf(context);
              final isMobile = layout == Layout.mobile;
              final hPad = isMobile
                  ? AppSpacing.pagePaddingHMobile
                  : AppSpacing.pagePaddingH;
              final userId =
                  AppRepositories.instance?.currentUserId ?? '';

              return Column(
                children: [
                  _DocumentColumnHeader(hPad: hPad, layout: layout),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _provider.reload,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            hPad, 8, hPad, AppSpacing.massive),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AdaptiveSpacing.rowGap),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          return _DocumentRow(
                            key:            ValueKey(doc.id),
                            doc:            doc,
                            layout:         layout,
                            onEdit:         () => _openEdit(doc),
                            onArchive:      () => _archive(doc),
                            onMarkReviewed: () =>
                                _provider.markReviewed(doc, userId),
                            onMarkApproved: () =>
                                _provider.markApproved(doc, userId),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Column definitions ─────────────────────────────────────────────────────────

/// PRIMARY   → always visible   (Document title, Type, Status)
/// SECONDARY → tablet + desktop (Expiry, Link)
/// TERTIARY  → desktop only     (Size)
List<AdaptiveColumn<TripDocument>> _documentColumns() => [
      AdaptiveColumn<TripDocument>(
        key:      'document',
        label:    'Document',
        priority: ColumnPriority.primary,
        flex:     3,
        builder:  (doc) => _DocumentCell(doc: doc),
      ),
      AdaptiveColumn<TripDocument>(
        key:      'type',
        label:    'Type',
        priority: ColumnPriority.primary,
        width:    160,
        builder:  (doc) => _TypeBadge(type: doc.documentType),
      ),
      AdaptiveColumn<TripDocument>(
        key:      'status',
        label:    'Status',
        priority: ColumnPriority.primary,
        width:    110,
        builder:  (doc) => _DocStatusChip(status: doc.status),
      ),
      AdaptiveColumn<TripDocument>(
        key:      'expiry',
        label:    'Expiry',
        priority: ColumnPriority.secondary,
        width:    110,
        builder:  (doc) => _ExpiryCell(doc: doc),
      ),
      AdaptiveColumn<TripDocument>(
        key:      'link',
        label:    'Link',
        priority: ColumnPriority.secondary,
        width:    100,
        builder:  (doc) => _LinkCell(doc: doc),
      ),
      AdaptiveColumn<TripDocument>(
        key:      'size',
        label:    'Size',
        priority: ColumnPriority.tertiary,
        width:    70,
        builder:  (doc) => Text(
          doc.fileSizeLabel.isNotEmpty ? doc.fileSizeLabel : '—',
          style: AdaptiveTypography.tertiaryCell,
        ),
      ),
    ];

// ── Column header ─────────────────────────────────────────────────────────────

class _DocumentColumnHeader extends StatelessWidget {
  final double hPad;
  final Layout layout;
  const _DocumentColumnHeader({required this.hPad, required this.layout});

  @override
  Widget build(BuildContext context) {
    if (layout == Layout.mobile) return const SizedBox.shrink();

    final cols =
        _documentColumns().where((c) => c.visibleFor(layout)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad + 19, 6, hPad + 36, 4),
      child: Row(
        children: [
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0) const SizedBox(width: AdaptiveSpacing.columnGap),
            cols[i].sized(
              Text(cols[i].label, style: AdaptiveTypography.columnHeader),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Document row — adaptive entry point ───────────────────────────────────────

class _DocumentRow extends StatelessWidget {
  final TripDocument doc;
  final Layout layout;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onMarkApproved;

  const _DocumentRow({
    super.key,
    required this.doc,
    required this.layout,
    this.onEdit,
    this.onArchive,
    this.onMarkReviewed,
    this.onMarkApproved,
  });

  @override
  Widget build(BuildContext context) {
    final accentBar = doc.isExpired
        ? const Color(0xFFDC2626)
        : doc.isExpiringSoon
            ? const Color(0xFFD97706)
            : doc.documentType.color;

    final actionsWidget = _ActionMenu(
      doc:            doc,
      onEdit:         onEdit,
      onArchive:      onArchive,
      onMarkReviewed: onMarkReviewed,
      onMarkApproved: onMarkApproved,
    );

    if (layout == Layout.mobile) {
      return AdaptiveMobileCard(
        onTap:          onEdit,
        accentBar:      accentBar,
        primaryContent: _DocumentCell(doc: doc),
        trailingChip:   _DocStatusChip(status: doc.status),
        metaRow:        _MobileMetaRow(doc: doc),
        actions:        actionsWidget,
      );
    }

    return AdaptiveRow<TripDocument>(
      item:          doc,
      columns:       _documentColumns(),
      layout:        layout,
      onTap:         onEdit,
      accentBar:     accentBar,
      actionsWidget: actionsWidget,
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _DocumentsToolbar extends StatelessWidget {
  final DocumentsProvider provider;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  const _DocumentsToolbar({
    required this.provider,
    required this.searchCtrl,
    required this.onSearch,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveBreakpoints.layoutOf(context);
    final isMobile = layout == Layout.mobile;
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Desktop only: title + counter
          if (!isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip Documents', style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                ListenableBuilder(
                  listenable: provider,
                  builder: (_, _) => Text(
                    '${provider.all.length} '
                    'document${provider.all.length == 1 ? '' : 's'}'
                    '${provider.expiringCount > 0 ? '  ·  ${provider.expiringCount} expiring' : ''}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
          ],

          // Search box — primary on mobile, fills remaining space on desktop
          Expanded(
            child: _SearchBox(
              controller: searchCtrl,
              onChanged:  onSearch,
              isMobile:   isMobile,
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Refresh',
          ),

          const SizedBox(width: AppSpacing.xs),

          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: isMobile
                ? const Text('Add')
                : const Text('Add Document'),
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

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isMobile;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isMobile ? 14.0 : AppSpacing.inputRadius.toDouble();
    final height = isMobile ? 44.0 : 38.0;

    return SizedBox(
      height: height,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search documents…',
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textMuted),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled:     true,
          fillColor:  AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide:   const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide:   const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide:   const BorderSide(color: AppColors.accent),
          ),
        ),
        style:     AppTextStyles.bodyMedium,
        onChanged: onChanged,
      ),
    );
  }
}

// ── Cell widgets ──────────────────────────────────────────────────────────────

class _DocumentCell extends StatelessWidget {
  final TripDocument doc;
  const _DocumentCell({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        Text(
          doc.title,
          style: AdaptiveTypography.primaryCell.copyWith(
            fontWeight:  FontWeight.w600,
            letterSpacing: -0.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (doc.fileName?.isNotEmpty ?? false) ...[
          const SizedBox(height: 2),
          Text(
            doc.fileName!,
            style: AdaptiveTypography.primarySubCell,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final DocumentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        type.bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 11, color: type.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type.label,
              style: GoogleFonts.inter(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      type.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocStatusChip extends StatelessWidget {
  final DocumentStatus status;
  const _DocStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        status.bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      status.color,
        ),
      ),
    );
  }
}

class _ExpiryCell extends StatelessWidget {
  final TripDocument doc;
  const _ExpiryCell({required this.doc});

  @override
  Widget build(BuildContext context) {
    if (doc.expiryDate == null) {
      return Text('—', style: AdaptiveTypography.tertiaryCell);
    }
    final isExpired      = doc.isExpired;
    final isExpiringSoon = doc.isExpiringSoon;
    final color = isExpired
        ? const Color(0xFFDC2626)
        : isExpiringSoon
            ? const Color(0xFFD97706)
            : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isExpired
              ? Icons.error_outline_rounded
              : isExpiringSoon
                  ? Icons.warning_amber_rounded
                  : Icons.event_outlined,
          size:  12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          DateFormat('d MMM yyyy').format(doc.expiryDate!),
          style: AdaptiveTypography.tertiaryCell.copyWith(
            color:      color,
            fontWeight: (isExpired || isExpiringSoon)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _LinkCell extends StatelessWidget {
  final TripDocument doc;
  const _LinkCell({required this.doc});

  @override
  Widget build(BuildContext context) {
    if (doc.fileUrl.isEmpty) {
      return Text('—', style: AdaptiveTypography.tertiaryCell);
    }
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(doc.fileUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_new_rounded,
              size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            'Open file',
            style: AdaptiveTypography.secondaryCell.copyWith(
              color:      AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile meta row ───────────────────────────────────────────────────────────

class _MobileMetaRow extends StatelessWidget {
  final TripDocument doc;
  const _MobileMetaRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeBadge(type: doc.documentType),
        if (doc.expiryDate != null) ...[
          const SizedBox(width: 8),
          _ExpiryCell(doc: doc),
        ],
        if (doc.fileUrl.isNotEmpty) ...[
          const SizedBox(width: 8),
          _LinkCell(doc: doc),
        ],
      ],
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
        if (v == 'edit') onEdit?.call();
        if (v == 'archive') onArchive?.call();
        if (v == 'reviewed') onMarkReviewed?.call();
        if (v == 'approved') onMarkApproved?.call();
        if (v == 'open' && doc.fileUrl.isNotEmpty) {
          launchUrl(Uri.parse(doc.fileUrl),
              mode: LaunchMode.externalApplication);
        }
      },
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      color: Colors.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'open',
          height: 38,
          child: Row(children: [
            Icon(Icons.open_in_new_rounded,
                size: 14, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Open / Download'),
          ]),
        ),
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            height: 38,
            child: Row(children: [
              Icon(Icons.edit_outlined,
                  size: 14, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onMarkReviewed != null &&
            doc.status == DocumentStatus.uploaded)
          const PopupMenuItem(
            value: 'reviewed',
            height: 38,
            child: Row(children: [
              Icon(Icons.rate_review_outlined,
                  size: 14, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Mark Reviewed'),
            ]),
          ),
        if (onMarkApproved != null &&
            doc.status != DocumentStatus.approved)
          const PopupMenuItem(
            value: 'approved',
            height: 38,
            child: Row(children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 14, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Mark Approved',
                  style: TextStyle(color: Color(0xFF16A34A))),
            ]),
          ),
        const PopupMenuDivider(),
        if (onArchive != null)
          const PopupMenuItem(
            value: 'archive',
            height: 38,
            child: Row(children: [
              Icon(Icons.archive_outlined,
                  size: 14, color: AppColors.textMuted),
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
            width:  56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accentFaint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_outlined,
                size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilter
                ? 'No documents match your filters'
                : 'No documents yet',
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
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
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
            const Icon(Icons.error_outline_rounded,
                size: 36, color: Colors.red),
            const SizedBox(height: AppSpacing.sm),
            Text('Failed to load documents',
                style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(message,
                style:     AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
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
