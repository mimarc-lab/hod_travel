import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_filter_bar.dart';
import '../widgets/budget_summary_cards.dart';
import '../widgets/cost_item_editor.dart';
import '../widgets/cost_item_row.dart';
import '../widgets/cost_status_chip.dart';

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

        final isMobile = Responsive.isMobile(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TripBudgetHeader(
              summary:  summary,
              currency: currency,
              onAdd: () => showCostItemEditor(
                context,
                provider: _provider,
                defaultTripId: widget.trip.id,
                trips: [widget.trip],
                suppliers: _suppliers,
              ),
            ),
            // On mobile keep the 2×2 summary grid; desktop shows it inline above.
            if (isMobile) BudgetSummaryCards(summary: summary, currency: currency),
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
                  : _BudgetTable(
                      items: items,
                      isMobile: isMobile,
                      onTap: (item) => showCostItemEditor(
                        context,
                        provider: _provider,
                        existing: item,
                        trips: [widget.trip],
                        suppliers: _suppliers,
                      ),
                      onDelete: (item) => _provider.deleteItem(item.id),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Budget table with horizontal scroll ──────────────────────────────────────

class _BudgetTable extends StatelessWidget {
  final List<CostItem> items;
  final bool isMobile;
  final void Function(CostItem) onTap;
  final void Function(CostItem) onDelete;

  const _BudgetTable({
    required this.items,
    required this.isMobile,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: items.length,
        itemBuilder: (context, i) => CostItemRow(
          item:     items[i],
          onTap:    () => onTap(items[i]),
          onDelete: () => onDelete(items[i]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = BudgetColumns.totalWidth > constraints.maxWidth
            ? BudgetColumns.totalWidth
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TableHeaderDelegate(),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => CostItemRow(
                      item:     items[i],
                      onTap:    () => onTap(items[i]),
                      onDelete: () => onDelete(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TableHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 36;
  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const BudgetTableHeader();

  @override
  bool shouldRebuild(covariant _TableHeaderDelegate oldDelegate) => false;
}

// ── Trip budget header ────────────────────────────────────────────────────────

class _TripBudgetHeader extends StatelessWidget {
  final BudgetSummary summary;
  final String currency;
  final VoidCallback onAdd;
  const _TripBudgetHeader({
    required this.summary,
    required this.currency,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

    if (isMobile) {
      return Container(
        color: AppColors.surface,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [BudgetAddButton(onTap: onAdd)],
        ),
      );
    }

    // Desktop: 4 compact stats + Add Item in one row, no title.
    final marginPct = summary.totalSellPrice > 0
        ? '${(summary.totalMargin / summary.totalSellPrice * 100).toStringAsFixed(1)}%'
        : null;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: _CompactStat(
            label: 'Net Cost',
            icon: Icons.receipt_outlined,
            iconColor: const Color(0xFF4A90A4),
            amount: summary.totalNetCost,
            currency: currency,
          )),
          const _StatDivider(),
          Expanded(child: _CompactStat(
            label: 'Sell Price',
            icon: Icons.sell_outlined,
            iconColor: AppColors.accent,
            amount: summary.totalSellPrice,
            currency: currency,
          )),
          const _StatDivider(),
          Expanded(child: _CompactStat(
            label: 'Margin',
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF5A9E6F),
            amount: summary.totalMargin,
            currency: currency,
            subLabel: marginPct,
          )),
          const _StatDivider(),
          Expanded(child: _CompactStat(
            label: 'Outstanding',
            icon: Icons.pending_outlined,
            iconColor: const Color(0xFFD4845A),
            amount: summary.outstandingAmount,
            currency: currency,
            subLabel: '${summary.itemCount} items',
          )),
          const _StatDivider(),
          Expanded(child: _CompactStat(
            label: 'Deposit Paid',
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF5A9E6F),
            amount: summary.totalDepositPaid,
            currency: currency,
          )),
          const _StatDivider(),
          Expanded(child: _CompactStat(
            label: 'Remaining Bal.',
            icon: Icons.account_balance_outlined,
            iconColor: const Color(0xFF7C6FAB),
            amount: summary.totalRemainingBalance,
            currency: currency,
          )),
          const SizedBox(width: AppSpacing.base),
          BudgetAddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

// ── Compact stat block (desktop header) ───────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final double amount;
  final String currency;
  final String? subLabel;

  const _CompactStat({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.amount,
    required this.currency,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: iconColor),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          CurrencyAmount(
            amount:   amount,
            currency: currency,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize:   15,
            ),
          ),
          if (subLabel != null)
            Text(subLabel!,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.border);
}
