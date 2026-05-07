import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_filter_bar.dart';
import '../widgets/budget_row.dart';
import '../widgets/budget_summary_cards.dart';
import '../widgets/cost_item_editor.dart';
import '../widgets/cost_item_row.dart';

/// Global Budget screen — all trips, accessible from the sidebar.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late final BudgetProvider _provider;
  List<Trip> _trips = [];
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    _provider = BudgetProvider(
      repository: repos?.budget,
      teamId:     teamId,
    );
    _loadTrips(repos?.trips, teamId);
    _loadSuppliers(repos?.suppliers, teamId);
  }

  Future<void> _loadTrips(TripRepository? repo, String teamId) async {
    if (repo == null || teamId.isEmpty) return;
    try {
      final trips = await repo.fetchAll(teamId);
      if (mounted) setState(() => _trips = trips);
    } catch (_) {}
  }

  Future<void> _loadSuppliers(SupplierRepository? repo, String teamId) async {
    if (repo == null || teamId.isEmpty) return;
    try {
      final suppliers = await repo.fetchAll(teamId);
      if (mounted) setState(() => _suppliers = suppliers);
    } catch (_) {}
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _openEditor(BuildContext context, {CostItem? existing}) {
    showCostItemEditor(
      context,
      provider:  _provider,
      existing:  existing,
      trips:     _trips,
      suppliers: _suppliers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Budget',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [
          BudgetAddButton(onTap: () => _openEditor(context)),
        ],
      ),
      body: Column(
        children: [
          // Trip filter chips
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) => _TripFilterSection(
              provider: _provider,
              trips:    _trips,
              isMobile: isMobile,
            ),
          ),
          // Category + status filters
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) =>
                BudgetFilterBar(provider: _provider),
          ),
          // Content
          Expanded(
            child: ListenableBuilder(
              listenable: _provider,
              builder: (context, _) {
                if (_provider.isLoading &&
                    _provider.filteredItems.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  );
                }

                final items    = _provider.filteredItems;
                final summary  = _provider.summary;
                final currency = dominantCurrency(items);

                if (items.isEmpty) {
                  return BudgetEmptyState(
                    hasFilters: _provider.hasActiveFilters,
                    onClear: _provider.clearFilters,
                    onAdd:   () => _openEditor(context),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final hPad = constraints.maxWidth > 600
                        ? AppSpacing.pagePaddingH
                        : AppSpacing.pagePaddingHMobile;

                    return Column(
                      children: [
                        BudgetSummaryCards(
                            summary: summary, currency: currency),
                        BudgetColumnHeader(hPad: hPad),
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                                hPad, 4, hPad, AppSpacing.massive),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AdaptiveSpacing.rowGap),
                            itemBuilder: (context, i) => BudgetRow(
                              key: ValueKey(items[i].id),
                              item: items[i],
                              onTap: () =>
                                  _openEditor(context, existing: items[i]),
                              onDelete: () =>
                                  _provider.deleteItem(items[i].id),
                            ),
                          ),
                        ),
                      ],
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

// ── Trip filter section ───────────────────────────────────────────────────────

class _TripFilterSection extends StatelessWidget {
  final BudgetProvider provider;
  final List<Trip> trips;
  final bool isMobile;

  const _TripFilterSection({
    required this.provider,
    required this.trips,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 10),
            child: Row(
              children: [
                _TripChip(
                  label: 'All Trips',
                  isSelected: provider.tripFilter == null,
                  onTap: () => provider.setTripFilter(null),
                ),
                const SizedBox(width: 6),
                ...trips.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TripChip(
                        label: t.name,
                        isSelected: provider.tripFilter == t.id,
                        onTap: () => provider.setTripFilter(
                            provider.tripFilter == t.id ? null : t.id),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

class _TripChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TripChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withAlpha(20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withAlpha(120)
                : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? AppColors.accent
                : AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
