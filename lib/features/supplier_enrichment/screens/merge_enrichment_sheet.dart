import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../integrations/firecrawl/firecrawl_config.dart';
import '../../suppliers/enrichment/supplier_merge_service.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/enrichment_provider.dart';
import '../widgets/enrichment_field_row.dart';
import '../widgets/enrichment_preview_card.dart';
import '../widgets/missing_api_key_panel.dart';
import '../widgets/sheet_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showMergeEnrichmentSheet — entry point
// ─────────────────────────────────────────────────────────────────────────────

void showMergeEnrichmentSheet(
  BuildContext context, {
  required Supplier supplier,
  required SupplierProvider supplierProvider,
  required EnrichmentProvider enrichmentProvider,
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
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (ctx, ctrl) => _MergeSheetContent(
          scrollController: ctrl,
          supplier: supplier,
          supplierProvider: supplierProvider,
          enrichmentProvider: enrichmentProvider,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: _MergeSheetContent(
            supplier: supplier,
            supplierProvider: supplierProvider,
            enrichmentProvider: enrichmentProvider,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MergeSheetContent
// ─────────────────────────────────────────────────────────────────────────────

class _MergeSheetContent extends StatefulWidget {
  final Supplier supplier;
  final SupplierProvider supplierProvider;
  final EnrichmentProvider enrichmentProvider;
  final ScrollController? scrollController;

  const _MergeSheetContent({
    required this.supplier,
    required this.supplierProvider,
    required this.enrichmentProvider,
    this.scrollController,
  });

  @override
  State<_MergeSheetContent> createState() => _MergeSheetContentState();
}

class _MergeSheetContentState extends State<_MergeSheetContent> {
  static const _mergeService = SupplierMergeService();

  late final TextEditingController _urlCtrl;

  /// Per-field apply toggles — true means "use the extracted value".
  final Map<MergeField, bool> _apply = {};

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.supplier.website ?? '');
    widget.enrichmentProvider.clearExtract();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _run() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    widget.enrichmentProvider.extractFromUrl(url);
  }

  void _initToggles(SupplierEnrichment enrichment) {
    final defaults =
        _mergeService.defaultToggles(widget.supplier, enrichment);
    for (final entry in defaults.entries) {
      _apply.putIfAbsent(entry.key, () => entry.value);
    }
  }

  void _applyMerge(SupplierEnrichment enrichment) {
    final fieldsToApply = _apply.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    final updated = _mergeService.apply(
      supplier: widget.supplier,
      enrichment: enrichment,
      fieldsToApply: fieldsToApply,
    );

    widget.supplierProvider.updateSupplier(updated);
    widget.enrichmentProvider.recordEvent(
      type: EnrichmentEventType.enrichedExisting,
      sourceUrl: enrichment.sourceUrl,
      sourceDomain: enrichment.sourceDomain,
      supplierName: updated.name,
      supplierId: updated.id,
    );
    widget.enrichmentProvider.clearExtract();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _MergeHeader(
          supplierName: widget.supplier.name,
          onClose: () => Navigator.of(context).pop(),
        ),

        Flexible(
          child: ListenableBuilder(
            listenable: widget.enrichmentProvider,
            builder: (context, _) {
              final state = widget.enrichmentProvider.extractState;
              final enrichment = widget.enrichmentProvider.extractResult;

              if (state == EnrichmentState.result && enrichment != null) {
                _initToggles(enrichment);
                return _MergeComparisonView(
                  supplier: widget.supplier,
                  enrichment: enrichment,
                  mergeService: _mergeService,
                  apply: _apply,
                  onToggle: (f, v) => setState(() => _apply[f] = v),
                  scrollController: widget.scrollController,
                );
              }

              // URL input + loading/error states
              return SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!FirecrawlConfig.isConfigured)
                      const MissingApiKeyPanel()
                    else ...[
                      Text(
                        'Paste the supplier\'s website URL to extract updated '
                        'data and selectively merge it into this record.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      EnrichmentUrlField(ctrl: _urlCtrl),
                      const SizedBox(height: AppSpacing.base),
                      if (state == EnrichmentState.loading)
                        const EnrichmentLoadingIndicator()
                      else if (state == EnrichmentState.error)
                        EnrichmentErrorBanner(
                          message: widget.enrichmentProvider.extractError
                                  ?.userMessage ??
                              'An error occurred.',
                          onRetry: _run,
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        // Footer
        ListenableBuilder(
          listenable: widget.enrichmentProvider,
          builder: (context, _) {
            final state = widget.enrichmentProvider.extractState;
            final enrichment = widget.enrichmentProvider.extractResult;

            if (state == EnrichmentState.result && enrichment != null) {
              return _MergeFooter(
                onApply: () => _applyMerge(enrichment),
                onCancel: () => Navigator.of(context).pop(),
              );
            }
            if (state == EnrichmentState.loading) {
              return const SizedBox.shrink();
            }
            return _ExtractFooter(
              onExtract: _run,
              onCancel: () => Navigator.of(context).pop(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Merge comparison view
// ─────────────────────────────────────────────────────────────────────────────

class _MergeComparisonView extends StatelessWidget {
  final Supplier supplier;
  final SupplierEnrichment enrichment;
  final SupplierMergeService mergeService;
  final Map<MergeField, bool> apply;
  final void Function(MergeField, bool) onToggle;
  final ScrollController? scrollController;

  const _MergeComparisonView({
    required this.supplier,
    required this.enrichment,
    required this.mergeService,
    required this.apply,
    required this.onToggle,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.base, AppSpacing.base, 0),
          child: ExtractionStatusBanner(enrichment: enrichment),
        ),
        const SizedBox(height: AppSpacing.sm),
        const MergeColumnHeader(),
        Expanded(
          child: ListView(
            controller: scrollController,
            children: MergeField.values.map((f) {
              return MergeFieldRow(
                label: f.label,
                currentValue: mergeService.currentValue(f, supplier),
                extractedValue: mergeService.extractedValue(f, enrichment),
                applyExtracted: apply[f] ?? false,
                onToggle: (v) => onToggle(f, v),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MergeHeader extends StatelessWidget {
  final String supplierName;
  final VoidCallback onClose;
  const _MergeHeader({required this.supplierName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enrich Supplier', style: AppTextStyles.heading3),
                const SizedBox(height: 2),
                Text(
                  supplierName,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
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

class _ExtractFooter extends StatelessWidget {
  final VoidCallback onExtract;
  final VoidCallback onCancel;
  const _ExtractFooter({required this.onExtract, required this.onCancel});

  @override
  Widget build(BuildContext context) => EnrichmentSheetFooter(
        primaryLabel: 'Extract Data',
        onPrimary: onExtract,
        onCancel: onCancel,
      );
}

class _MergeFooter extends StatelessWidget {
  final VoidCallback onApply;
  final VoidCallback onCancel;
  const _MergeFooter({required this.onApply, required this.onCancel});

  @override
  Widget build(BuildContext context) => EnrichmentSheetFooter(
        primaryLabel: 'Apply Changes',
        onPrimary: onApply,
        onCancel: onCancel,
      );
}
