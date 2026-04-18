import 'dart:html' as html;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../integrations/firecrawl/firecrawl_config.dart';
import '../../../integrations/firecrawl/firecrawl_models.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../providers/enrichment_provider.dart';
import '../widgets/missing_api_key_panel.dart';
import '../widgets/sheet_widgets.dart';
import 'url_enrichment_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// showSupplierSearchSheet — entry point
// ─────────────────────────────────────────────────────────────────────────────

void showSupplierSearchSheet(
  BuildContext context, {
  required EnrichmentProvider provider,
  SupplierProvider? supplierProvider,
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
        builder: (ctx, ctrl) => _SearchSheetContent(
          scrollController: ctrl,
          outerContext: context,
          provider: provider,
          supplierProvider: supplierProvider,
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
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          child: _SearchSheetContent(
            outerContext: context,
            provider: provider,
            supplierProvider: supplierProvider,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchSheetContent
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSheetContent extends StatefulWidget {
  final EnrichmentProvider provider;
  final SupplierProvider? supplierProvider;
  final ScrollController? scrollController;
  // The context that opened this dialog/sheet — still valid after pop().
  final BuildContext outerContext;

  const _SearchSheetContent({
    required this.provider,
    required this.outerContext,
    this.supplierProvider,
    this.scrollController,
  });

  @override
  State<_SearchSheetContent> createState() => _SearchSheetContentState();
}

class _SearchSheetContentState extends State<_SearchSheetContent> {
  late final TextEditingController _queryCtrl;

  static const _hints = [
    'luxury family resorts in Kyoto',
    '5-bedroom villas in Bali with pool',
    'private island resort Philippines',
    'boutique safari lodge Tanzania',
    'romantic overwater bungalows Maldives',
  ];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    widget.provider.clearSearch();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _search() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    widget.provider.searchSuppliers(q);
  }

  void _useHint(String hint) {
    _queryCtrl.text = hint;
    _queryCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: hint.length));
  }

  void _enrichUrl(BuildContext context, String url) {
    // Pop using the dialog's own context, then open the next sheet using
    // the outer context (which remains valid after this dialog is dismissed).
    Navigator.of(context).pop();
    showUrlEnrichmentSheet(
      widget.outerContext,
      provider: widget.provider,
      supplierProvider: widget.supplierProvider,
      prefillUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(onClose: () => Navigator.of(context).pop()),
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
                  // Query input
                  _QueryField(ctrl: _queryCtrl, onSubmit: _search),
                  const SizedBox(height: AppSpacing.sm),

                  // Hint chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _hints.map((h) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _HintChip(
                          label: h,
                          onTap: () => _useHint(h),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Results
                  ListenableBuilder(
                    listenable: widget.provider,
                    builder: (context, _) {
                      final state = widget.provider.searchState;

                      if (state == EnrichmentState.loading) {
                        return const EnrichmentLoadingIndicator(
                            message: 'Searching the web…');
                      }

                      if (state == EnrichmentState.error) {
                        return EnrichmentErrorBanner(
                          message: widget.provider.searchError?.userMessage
                              ?? 'Search failed.',
                          onRetry: _search,
                        );
                      }

                      if (state == EnrichmentState.result) {
                        final results = widget.provider.searchResults;
                        if (results.isEmpty) {
                          return const _EmptyResults();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${results.length} results',
                              style: AppTextStyles.labelSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...results.map((r) => _ResultCard(
                                  result: r,
                                  onEnrich: () => _enrichUrl(context, r.url),
                                )),
                          ],
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

        // Footer
        ListenableBuilder(
          listenable: widget.provider,
          builder: (context, _) {
            final state = widget.provider.searchState;
            if (state == EnrichmentState.loading) {
              return const SizedBox.shrink();
            }
            return _Footer(onSearch: _search, onCancel: () => Navigator.of(context).pop());
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result card
// ─────────────────────────────────────────────────────────────────────────────

// Known travel directory domains — shown with a "directory" badge so the
// user knows these link to listing pages rather than official property sites.
const _directoryDomains = {
  'booking.com', 'tripadvisor.com', 'hotels.com', 'expedia.com',
  'agoda.com', 'kayak.com', 'airbnb.com', 'vrbo.com',
  'lonelyplanet.com', 'yelp.com', 'trustpilot.com', 'google.com',
};

bool _isDirectory(String domain) =>
    _directoryDomains.any((d) => domain == d || domain.endsWith('.$d'));

class _ResultCard extends StatelessWidget {
  final FirecrawlSearchResult result;
  final VoidCallback onEnrich;

  const _ResultCard({required this.result, required this.onEnrich});

  @override
  Widget build(BuildContext context) {
    final domain = _parseDomain(result.url);
    final isDir = _isDirectory(domain);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Domain + badge row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      domain,
                      style: AppTextStyles.labelSmall.copyWith(
                          color: isDir ? AppColors.textMuted : AppColors.accent),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDir) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text('directory',
                            style: AppTextStyles.labelSmall
                                .copyWith(fontSize: 10,
                                    color: AppColors.textMuted)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Title
          if (result.title != null && result.title!.isNotEmpty)
            Text(
              result.title!,
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

          // Snippet
          if (result.snippet != null && result.snippet!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              result.snippet!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Actions
          Row(
            children: [
              _ActionButton(
                label: 'Extract & Enrich',
                icon: Icons.auto_awesome_outlined,
                primary: true,
                onTap: onEnrich,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ActionButton(
                label: 'Open',
                icon: Icons.open_in_new_rounded,
                primary: false,
                onTap: () => html.window.open(result.url, '_blank'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _parseDomain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return url;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small inner widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discover Suppliers', style: AppTextStyles.heading3),
                Text('Search the web for luxury accommodation & suppliers',
                    style: AppTextStyles.labelSmall),
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

class _QueryField extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSubmit;
  const _QueryField({required this.ctrl, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onSubmitted: (_) => onSubmit(),
      textInputAction: TextInputAction.search,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'e.g. luxury family resorts in Kyoto',
        hintStyle: AppTextStyles.bodySmall,
        prefixIcon:
            const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HintChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: primary ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: primary ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    color: primary ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          const Icon(Icons.travel_explore_rounded,
              size: 24, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter a search query to discover luxury hotels,\nvillas, lodges, and experience providers.',
            style: AppTextStyles.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'No results found. Try a different query\nor be more specific about the location.',
        style: AppTextStyles.labelSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onCancel;
  const _Footer({required this.onSearch, required this.onCancel});

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
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 15),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
