import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_enrichment_model.dart';
import '../../../integrations/firecrawl/firecrawl_config.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/enrichment_provider.dart';
import '../widgets/missing_api_key_panel.dart';
import '../widgets/sheet_widgets.dart';
import 'enrichment_review_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showUrlEnrichmentSheet — entry point
// ─────────────────────────────────────────────────────────────────────────────

void showUrlEnrichmentSheet(
  BuildContext context, {
  required EnrichmentProvider provider,
  SupplierProvider? supplierProvider,
  String? prefillUrl,
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
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, ctrl) => _UrlEnrichmentContent(
          scrollController: ctrl,
          provider: provider,
          supplierProvider: supplierProvider,
          prefillUrl: prefillUrl,
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
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: _UrlEnrichmentContent(
            provider: provider,
            supplierProvider: supplierProvider,
            prefillUrl: prefillUrl,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UrlEnrichmentContent
// ─────────────────────────────────────────────────────────────────────────────

class _UrlEnrichmentContent extends StatefulWidget {
  final EnrichmentProvider provider;
  final SupplierProvider? supplierProvider;
  final String? prefillUrl;
  final ScrollController? scrollController;

  const _UrlEnrichmentContent({
    required this.provider,
    this.supplierProvider,
    this.prefillUrl,
    this.scrollController,
  });

  @override
  State<_UrlEnrichmentContent> createState() => _UrlEnrichmentContentState();
}

class _UrlEnrichmentContentState extends State<_UrlEnrichmentContent> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.prefillUrl ?? '');
    widget.provider.clearExtract();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _run() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    widget.provider.extractFromUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          title: 'Import from URL',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!FirecrawlConfig.isConfigured)
                  const MissingApiKeyPanel()
                else ...[
                  Text(
                    'Paste a hotel, villa, restaurant, or supplier website URL. '
                    'Firecrawl will extract structured data for you to review.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // URL input
                  EnrichmentUrlField(ctrl: _urlCtrl),
                  const SizedBox(height: AppSpacing.base),

                  // State-driven content
                  ListenableBuilder(
                    listenable: widget.provider,
                    builder: (context, _) {
                      final state = widget.provider.extractState;

                      if (state == EnrichmentState.loading) {
                        return const EnrichmentLoadingIndicator();
                      }

                      if (state == EnrichmentState.error) {
                        return EnrichmentErrorBanner(
                          message: widget.provider.extractError?.userMessage ??
                              'An error occurred.',
                          onRetry: _run,
                        );
                      }

                      if (state == EnrichmentState.result &&
                          widget.provider.extractResult != null) {
                        return _ResultReady(
                          enrichment: widget.provider.extractResult!,
                          provider: widget.provider,
                          supplierProvider: widget.supplierProvider,
                        );
                      }

                      return const _IdleHint();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        // Footer — only show Run button when idle/error
        ListenableBuilder(
          listenable: widget.provider,
          builder: (context, _) {
            final state = widget.provider.extractState;
            if (state == EnrichmentState.loading ||
                state == EnrichmentState.result) {
              return const SizedBox.shrink();
            }
            return EnrichmentSheetFooter(
              primaryLabel: 'Extract Data',
              onPrimary: _run,
              onCancel: () => Navigator.of(context).pop(),
            );
          },
        ),
      ],
    );
  }
}

// ── Inner state widgets ───────────────────────────────────────────────────────

class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Supported: hotels, villas, restaurants, guides,\ntransport providers, experience operators.',
            style: AppTextStyles.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultReady extends StatelessWidget {
  final SupplierEnrichment enrichment;
  final EnrichmentProvider provider;
  final SupplierProvider? supplierProvider;
  const _ResultReady({
    required this.enrichment,
    required this.provider,
    this.supplierProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.accentFaint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Extraction complete — ${enrichment.filledFieldCount} fields found',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.accentDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Review & Create Supplier',
                icon: Icons.add_business_outlined,
                primary: true,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EnrichmentReviewScreen(
                      enrichment: enrichment,
                      enrichmentProvider: provider,
                      supplierProvider: supplierProvider,
                    ),
                  ));
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(
              label: 'Discard',
              icon: Icons.close_rounded,
              primary: false,
              onTap: () {
                provider.clearExtract();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: primary ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color: primary ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                    color: primary ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet header (local — close button only, no subtitle)
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _SheetHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.heading3),
          const Spacer(),
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
