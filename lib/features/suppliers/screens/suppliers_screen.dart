import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../supplier_enrichment/providers/enrichment_provider.dart';
import '../../supplier_enrichment/screens/supplier_search_sheet.dart';
import '../../supplier_enrichment/screens/url_enrichment_sheet.dart';
import '../providers/supplier_provider.dart';
import '../widgets/supplier_editor.dart';
import '../widgets/supplier_filter_bar.dart';
import '../widgets/supplier_list_item.dart';
import 'supplier_detail_screen.dart';

/// Entry point for the Supplier Database module.
/// Holds the SupplierProvider and top-level list UI.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _SuppliersHeader(
            provider: _provider,
            searchCtrl: _searchCtrl,
            onAddTap: () =>
                showSupplierEditor(context, provider: _provider),
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
                    onAdd: () => showSupplierEditor(context, provider: _provider),
                  );
                }

                return Column(
                  children: [
                    if (Responsive.showSidebar(context))
                      _TableHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: Responsive.isMobile(context)
                            ? const EdgeInsets.symmetric(vertical: AppSpacing.sm)
                            : EdgeInsets.zero,
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) => SupplierListItem(
                          supplier: suppliers[index],
                          onTap: () => _openDetail(context, suppliers[index]),
                          onDelete: () => _confirmDelete(context, suppliers[index]),
                        ),
                      ),
                    ),
                  ],
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
  final VoidCallback onAddTap;
  final VoidCallback onImportTap;
  final VoidCallback onDiscoverTap;

  const _SuppliersHeader({
    required this.provider,
    required this.searchCtrl,
    required this.onAddTap,
    required this.onImportTap,
    required this.onDiscoverTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical: AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suppliers', style: AppTextStyles.displayMedium),
                    ListenableBuilder(
                      listenable: provider,
                      builder: (context, _) => Text(
                        '${provider.totalCount} partners in database',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              _DiscoverButton(onTap: onDiscoverTap),
              const SizedBox(width: AppSpacing.sm),
              _ImportButton(onTap: onImportTap),
              const SizedBox(width: AppSpacing.sm),
              _AddButton(onTap: onAddTap),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _SearchField(ctrl: searchCtrl, provider: provider),
        ],
      ),
    );
  }
}

class _DiscoverButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DiscoverButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_rounded,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text('Discover',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ImportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, size: 15,
                color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text('Import URL',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text('Add Supplier',
                style: AppTextStyles.labelMedium
                    .copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final SupplierProvider provider;
  const _SearchField({required this.ctrl, required this.provider});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: provider.setSearch,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by name, city, contact, or tag…',
        hintStyle: AppTextStyles.bodySmall,
        prefixIcon: const Icon(Icons.search_rounded,
            size: 17, color: AppColors.textMuted),
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
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ── Table header (desktop) ────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          const SizedBox(width: 36 + AppSpacing.base), // icon space
          _Col(label: 'NAME', flex: 5),
          _Col(label: 'CATEGORY', flex: 3),
          _Col(label: 'PREFERRED / RATING', flex: 3),
          _Col(label: 'CONTACT', flex: 3),
          _Col(label: 'LAST USED', width: 80),
          const SizedBox(width: 16), // chevron space
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String label;
  final int? flex;
  final double? width;
  const _Col({required this.label, this.flex, this.width});

  @override
  Widget build(BuildContext context) {
    final child = Text(label, style: AppTextStyles.tableHeader,
        overflow: TextOverflow.ellipsis);
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
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
            hasFilters ? 'No suppliers match filters' : 'No suppliers yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting the category or clearing filters.'
                : 'Add your first trusted partner to the database.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasFilters)
            GestureDetector(
              onTap: onClear,
              child: Text('Clear filters',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.accent)),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
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
