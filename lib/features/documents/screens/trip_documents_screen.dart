import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_document.dart';
import '../../../data/models/trip_model.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_card.dart';
import '../widgets/document_filter_bar.dart';
import '../widgets/document_upload_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripDocumentsScreen
//
// Full-page document library for a trip — searchable, filterable list with
// upload, edit, archive, and status-transition actions.
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
        // Toolbar
        _Toolbar(
          onAdd:     _openUpload,
          onRefresh: _provider.reload,
          provider:  _provider,
        ),

        // Filter bar
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
                  message:   _provider.error!,
                  onRetry:   () {
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
                  onAdd:    _openUpload,
                );
              }

              final userId = AppRepositories.instance?.currentUserId ?? '';

              return RefreshIndicator(
                onRefresh: _provider.reload,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => DocumentCard(
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
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback         onAdd;
  final Future<void> Function() onRefresh;
  final DocumentsProvider    provider;
  const _Toolbar({
    required this.onAdd,
    required this.onRefresh,
    required this.provider,
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
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon:  const Icon(Icons.refresh_rounded, size: 18),
            color: AppColors.textSecondary,
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
