import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_filter_bar.dart';
import '../widgets/budget_summary_cards.dart';
import '../widgets/cost_item_editor.dart';
import '../widgets/cost_item_row.dart';

/// Trip-scoped budget tab, shown inside TripBoardScreen.
/// Uses AutomaticKeepAliveClientMixin to preserve state across tab switches.
class TripBudgetScreen extends StatefulWidget {
  final Trip trip;
  const TripBudgetScreen({super.key, required this.trip});

  @override
  State<TripBudgetScreen> createState() => _TripBudgetScreenState();
}

class _TripBudgetScreenState extends State<TripBudgetScreen>
    with AutomaticKeepAliveClientMixin {
  late final BudgetProvider _provider;
  List<Supplier> _suppliers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    _provider = BudgetProvider.forTrip(
      widget.trip.id,
      repository: repos?.budget,
      teamId:     teamId,
    );
    _loadSuppliers(repos?.suppliers, teamId);
    _provider.addListener(_onProviderChange);
  }

  void _onProviderChange() {
    final err = _provider.error;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFB00020),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      _provider.clearError();
    }
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
    _provider.removeListener(_onProviderChange);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final items   = _provider.filteredItems;
        final summary = _provider.summary;
        final currency = dominantCurrency(items);

        return Column(
          children: [
            _TripBudgetHeader(
              trip: widget.trip,
              onAdd: () => showCostItemEditor(
                context,
                provider: _provider,
                defaultTripId: widget.trip.id,
                trips: [widget.trip],
                suppliers: _suppliers,
              ),
            ),
            BudgetSummaryCards(summary: summary, currency: currency),
            BudgetFilterBar(provider: _provider),
            Expanded(
              child: items.isEmpty
                  ? BudgetEmptyState(
                      hasFilters: _provider.hasActiveFilters,
                      onClear: _provider.clearFilters,
                      onAdd: () => showCostItemEditor(
                        context,
                        provider: _provider,
                        defaultTripId: widget.trip.id,
                        trips: [widget.trip],
                        suppliers: _suppliers,
                      ),
                      emptyDescription:
                          'Add your first cost item to start costing this trip.',
                    )
                  : Column(
                      children: [
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
                                trips: [widget.trip],
                                suppliers: _suppliers,
                              ),
                              onDelete: () =>
                                  _provider.deleteItem(items[i].id),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Trip budget header ────────────────────────────────────────────────────────

class _TripBudgetHeader extends StatelessWidget {
  final Trip trip;
  final VoidCallback onAdd;
  const _TripBudgetHeader({required this.trip, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget', style: AppTextStyles.heading2),
                Text(trip.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          BudgetAddButton(onTap: onAdd),
        ],
      ),
    );
  }
}
