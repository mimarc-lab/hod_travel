import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../suppliers/enrichment/duplicate_detection_service.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/enrichment_provider.dart';
import '../widgets/duplicate_warning_panel.dart';
import '../widgets/enrichment_preview_card.dart';
import 'merge_enrichment_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentReviewScreen — full-page review before creating a new supplier.
//
// Shows duplicate matches at the top if any are found. The user can choose to:
//   • Enrich an existing matched supplier (→ opens merge sheet)
//   • Create a new supplier anyway (→ proceeds to create)
//   • Discard (→ back)
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentReviewScreen extends StatefulWidget {
  final SupplierEnrichment enrichment;
  final EnrichmentProvider enrichmentProvider;
  final SupplierProvider? supplierProvider;

  const EnrichmentReviewScreen({
    super.key,
    required this.enrichment,
    required this.enrichmentProvider,
    this.supplierProvider,
  });

  @override
  State<EnrichmentReviewScreen> createState() => _EnrichmentReviewScreenState();
}

class _EnrichmentReviewScreenState extends State<EnrichmentReviewScreen> {
  List<Supplier> _duplicateMatches = [];
  bool _duplicatesDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkDuplicates();
  }

  void _checkDuplicates() {
    final sp = widget.supplierProvider;
    if (sp == null) return;
    final matches = const DuplicateDetectionService().findMatches(
      widget.enrichment,
      sp.suppliers,
    );
    if (matches.isNotEmpty) {
      setState(() => _duplicateMatches = matches);
    }
  }

  void _enrichExisting(BuildContext context, Supplier matched) {
    // Navigate back first, then open the merge sheet for the matched supplier
    Navigator.of(context).pop();
    final sp = widget.supplierProvider;
    if (sp == null) return;
    showMergeEnrichmentSheet(
      context,
      supplier: matched,
      supplierProvider: sp,
      enrichmentProvider: widget.enrichmentProvider,
    );
  }

  void _createSupplier(BuildContext context) {
    final sp = widget.supplierProvider;
    if (sp == null) return;

    final supplier = widget.enrichment.toSupplierDraft('');
    if (supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create supplier: name is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    sp.addSupplier(supplier);
    widget.enrichmentProvider.recordEvent(
      type: EnrichmentEventType.importedFromUrl,
      sourceUrl: widget.enrichment.sourceUrl,
      sourceDomain: widget.enrichment.sourceDomain,
      supplierName: supplier.name,
      supplierId: supplier.id,
    );
    widget.enrichmentProvider.clearExtract();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    final showDuplicatePanel =
        _duplicateMatches.isNotEmpty && !_duplicatesDismissed;

    final canCreate = widget.supplierProvider != null &&
        (widget.enrichment.name?.isNotEmpty == true);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.base,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Back', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Review Extraction', style: AppTextStyles.displayMedium),
                const SizedBox(height: 2),
                Text(
                  'Confirm extracted fields before creating the supplier.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          // ── Scrollable content ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: AppSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Duplicate warning — shown until dismissed
                      if (showDuplicatePanel) ...[
                        DuplicateWarningPanel(
                          matches: _duplicateMatches,
                          onEnrichExisting: (s) =>
                              _enrichExisting(context, s),
                          onCreateAnyway: () =>
                              setState(() => _duplicatesDismissed = true),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      EnrichmentPreviewCard(enrichment: widget.enrichment),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
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
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                        canCreate ? () => _createSupplier(context) : null,
                    icon: const Icon(Icons.add_business_outlined, size: 16),
                    label: const Text('Create Supplier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
