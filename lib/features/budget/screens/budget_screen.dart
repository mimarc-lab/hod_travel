import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_filter_bar.dart';
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
    final repos   = AppRepositories.instance;
    final teamId  = repos?.currentTeamId ?? '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _BudgetHeader(
            provider: _provider,
            trips: _trips,
            onAdd: () => showCostItemEditor(
            context,
            provider: _provider,
            trips: _trips,
            suppliers: _suppliers,
          ),
          ),
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) => BudgetFilterBar(provider: _provider),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _provider,
              builder: (context, _) {
                final items   = _provider.filteredItems;
                final summary = _provider.summary;
                final currency = dominantCurrency(items);

                return Column(
                  children: [
                    BudgetSummaryCards(summary: summary, currency: currency),
                    if (items.isEmpty)
                      Expanded(
                        child: BudgetEmptyState(
                          hasFilters: _provider.hasActiveFilters,
                          onClear: _provider.clearFilters,
                          onAdd: () => showCostItemEditor(
                        context,
                        provider: _provider,
                        trips: _trips,
                        suppliers: _suppliers,
                      ),
                        ),
                      )
                    else ...[
                      if (Responsive.showSidebar(context))
                        const BudgetTableHeader(),
                      Expanded(
                        child: ListView.builder(
                          padding: Responsive.isMobile(context)
                              ? const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm)
                              : EdgeInsets.zero,
                          itemCount: items.length,
                          itemBuilder: (context, i) => CostItemRow(
                            item: items[i],
                            onTap: () => showCostItemEditor(
                              context,
                              provider: _provider,
                              existing: items[i],
                              trips: _trips,
                              suppliers: _suppliers,
                            ),
                            onDelete: () =>
                                _provider.deleteItem(items[i].id),
                          ),
                        ),
                      ),
                    ],
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

class _BudgetHeader extends StatelessWidget {
  final BudgetProvider provider;
  final List<Trip> trips;
  final VoidCallback onAdd;
  const _BudgetHeader({required this.provider, required this.trips, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget', style: AppTextStyles.displayMedium),
                    ListenableBuilder(
                      listenable: provider,
                      builder: (context, _) => Text(
                        '${provider.filteredItems.length} cost items across all trips',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              BudgetAddButton(onTap: onAdd),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _TripFilterRow(provider: provider, trips: trips),
        ],
      ),
    );
  }
}

/// Horizontal trip selector chips in the header.
class _TripFilterRow extends StatelessWidget {
  final BudgetProvider provider;
  final List<Trip> trips;
  const _TripFilterRow({required this.provider, required this.trips});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TripChip(
            label: 'All Trips',
            isSelected: provider.tripFilter == null,
            onTap: () => provider.setTripFilter(null),
          ),
          const SizedBox(width: AppSpacing.xs),
          ...trips.map((t) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _TripChip(
              label: t.name,
              isSelected: provider.tripFilter == t.id,
              onTap: () => provider.setTripFilter(
                  provider.tripFilter == t.id ? null : t.id),
            ),
          )),
        ],
      ),
    );
  }
}

class _TripChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TripChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
