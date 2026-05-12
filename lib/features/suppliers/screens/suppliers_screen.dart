import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/adaptive_control_row.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../supplier_enrichment/providers/enrichment_provider.dart';
import '../../supplier_enrichment/screens/supplier_search_sheet.dart';
import '../../supplier_enrichment/screens/url_enrichment_sheet.dart';
import '../providers/supplier_provider.dart';
import '../widgets/supplier_editor.dart';
import '../widgets/supplier_filter_bar.dart';
import '../widgets/supplier_list_item.dart';
import '../../../shared/widgets/app_header.dart';
import 'supplier_detail_screen.dart';

/// Entry point for the Supplier Database module.
/// Holds the SupplierProvider and curated supplier portfolio grid.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierProvider _provider;
  late final EnrichmentProvider _enrichmentProvider;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = SupplierProvider(
      repository: repos?.suppliers,
      teamId:     repos?.currentTeamId ?? '',
    );
    _enrichmentProvider = EnrichmentProvider(
      enrichmentRepository: repos?.enrichments,
      teamId:               repos?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    _enrichmentProvider.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, supplier) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SupplierDetailScreen(
        supplier: supplier,
        provider: _provider,
        enrichmentProvider: _enrichmentProvider,
      ),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete supplier?', style: AppTextStyles.heading3),
        content: Text(
          'This will permanently remove "${supplier.name}" from your database. '
          'This action cannot be undone.',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFB00020))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _provider.deleteSupplier(supplier.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Suppliers',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [
          if (!isMobile) ...[
            _GhostButton(
              icon: Icons.travel_explore_rounded,
              label: 'Discover',
              onTap: () => showSupplierSearchSheet(
                context,
                provider: _enrichmentProvider,
                supplierProvider: _provider,
              ),
            ),
            const SizedBox(width: 8),
            _GhostButton(
              icon: Icons.link_rounded,
              label: 'Import URL',
              onTap: () => showUrlEnrichmentSheet(
                context,
                provider: _enrichmentProvider,
                supplierProvider: _provider,
              ),
            ),
            const SizedBox(width: 10),
          ],
          _AddSupplierButton(
            onTap: () => showSupplierEditor(context, provider: _provider),
          ),
        ],
      ),
      body: Column(
        children: [
          _SuppliersHeader(
            provider: _provider,
            searchCtrl: _searchCtrl,
            isMobile: isMobile,
            onImportTap: () => showUrlEnrichmentSheet(
              context,
              provider: _enrichmentProvider,
              supplierProvider: _provider,
            ),
            onDiscoverTap: () => showSupplierSearchSheet(
              context,
              provider: _enrichmentProvider,
              supplierProvider: _provider,
            ),
          ),
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) =>
                SupplierFilterBar(provider: _provider),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _provider,
              builder: (context, _) {
                if (_provider.isLoading && _provider.totalCount == 0) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  );
                }

                if (_provider.error != null && _provider.totalCount == 0) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 40, color: AppColors.textMuted),
                        const SizedBox(height: AppSpacing.base),
                        Text(_provider.error!,
                            style: AppTextStyles.bodySmall),
                        const SizedBox(height: AppSpacing.base),
                        GestureDetector(
                          onTap: _provider.reload,
                          child: Text('Retry',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.accent)),
                        ),
                      ],
                    ),
                  );
                }

                final suppliers = _provider.filteredSuppliers;

                if (suppliers.isEmpty) {
                  return _EmptyState(
                    hasFilters: _provider.hasActiveFilters,
                    onClear: _provider.clearFilters,
                    onAdd: () =>
                        showSupplierEditor(context, provider: _provider),
                  );
                }

                // Responsive 2-col grid (desktop/tablet) → 1-col (mobile)
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 600 ? 2 : 1;
                    final hPad = cols == 1
                        ? AppSpacing.pagePaddingHMobile
                        : AppSpacing.pagePaddingH;
                    const gap = 18.0;
                    const cardHeight = 264.0;
                    final cardWidth = (constraints.maxWidth -
                            hPad * 2 -
                            (cols - 1) * gap) /
                        cols;

                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                          hPad, AppSpacing.base, hPad, AppSpacing.massive),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childAspectRatio: cardWidth / cardHeight,
                      ),
                      itemCount: suppliers.length,
                      itemBuilder: (context, index) {
                        final s = suppliers[index];
                        return SupplierCard(
                          key: ValueKey(s.id),
                          supplier: s,
                          onTap: () => _openDetail(context, s),
                          onDelete: () => _confirmDelete(context, s),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SuppliersHeader extends StatelessWidget {
  final SupplierProvider provider;
  final TextEditingController searchCtrl;
  final bool isMobile;
  final VoidCallback onImportTap;
  final VoidCallback onDiscoverTap;

  const _SuppliersHeader({
    required this.provider,
    required this.searchCtrl,
    required this.isMobile,
    required this.onImportTap,
    required this.onDiscoverTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad =
        isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // On mobile, secondary actions sit below the AppHeader
          if (isMobile) ...[
            AdaptiveControlRow(
              gap: 8,
              children: [
                _GhostButton(
                  icon: Icons.travel_explore_rounded,
                  label: 'Discover',
                  onTap: onDiscoverTap,
                  fullWidth: true,
                ),
                _GhostButton(
                  icon: Icons.link_rounded,
                  label: 'Import URL',
                  onTap: onImportTap,
                  fullWidth: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _SearchField(ctrl: searchCtrl, provider: provider),
        ],
      ),
    );
  }
}

// ── Ghost (secondary) button ──────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Supplier button ───────────────────────────────────────────────────────

class _AddSupplierButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSupplierButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'Add Supplier',
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final SupplierProvider provider;
  const _SearchField({required this.ctrl, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        onChanged: provider.setSearch,
        style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search suppliers, cities, specialties…',
          hintStyle: AppTextStyles.bodySmall,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textMuted),
          suffixIcon: ListenableBuilder(
            listenable: provider,
            builder: (context, _) => provider.searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      ctrl.clear();
                      provider.setSearch('');
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textMuted),
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.border, width: 0.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.border, width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.hasFilters,
    required this.onClear,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_outlined,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilters
                ? 'No suppliers match filters'
                : 'No suppliers yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting the category or clearing filters.'
                : 'Add your first trusted partner to the network.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasFilters)
            GestureDetector(
              onTap: onClear,
              child: Text('Clear filters',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.accent)),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Add Supplier',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
