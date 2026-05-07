import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../../shared/design_system/spacing_tokens.dart';
import '../widgets/budget_filter_bar.dart';
import '../widgets/budget_row.dart';
import '../widgets/budget_summary_cards.dart';
import '../widgets/cost_item_editor.dart';
import '../widgets/cost_item_row.dart';
import '../widgets/cost_status_chip.dart';

/// Trip-scoped budget tab, shown inside TripBoardScreen.
/// Uses AutomaticKeepAliveClientMixin to preserve state across tab switches.
class TripBudgetScreen extends StatefulWidget {
  final Trip trip;
  final BudgetProvider? budgetProvider;
  const TripBudgetScreen(
      {super.key, required this.trip, this.budgetProvider});

  @override
  State<TripBudgetScreen> createState() => _TripBudgetScreenState();
}

class _TripBudgetScreenState extends State<TripBudgetScreen>
    with AutomaticKeepAliveClientMixin {
  late final BudgetProvider _provider;
  List<Supplier> _suppliers = [];

  @override
  bool get wantKeepAlive => true;

  bool _ownsProvider = false;

  @override
  void initState() {
    super.initState();
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    if (widget.budgetProvider != null) {
      _provider = widget.budgetProvider!;
    } else {
      _provider = BudgetProvider.forTrip(
        widget.trip.id,
        repository: repos?.budget,
        teamId:     teamId,
      );
      _ownsProvider = true;
    }
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

  Future<void> _loadSuppliers(
      SupplierRepository? repo, String teamId) async {
    if (repo == null || teamId.isEmpty) return;
    try {
      final suppliers = await repo.fetchAll(teamId);
      if (mounted) setState(() => _suppliers = suppliers);
    } catch (_) {}
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChange);
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  void _openEditor(BuildContext context, {CostItem? existing}) {
    showCostItemEditor(
      context,
      provider:       _provider,
      existing:       existing,
      defaultTripId:  widget.trip.id,
      trips:          [widget.trip],
      suppliers:      _suppliers,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final items    = _provider.filteredItems;
        final summary  = _provider.summary;
        final currency = dominantCurrency(items);
        final isMobile = Responsive.isMobile(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact stats header (desktop) / add button only (mobile)
            _TripBudgetHeader(
              summary:  summary,
              currency: currency,
              onAdd:    () => _openEditor(context),
            ),
            // 2×2 summary grid on mobile (desktop shows inline stats above)
            if (isMobile)
              BudgetSummaryCards(summary: summary, currency: currency),
            BudgetFilterBar(provider: _provider),
            Expanded(
              child: items.isEmpty
                  ? BudgetEmptyState(
                      hasFilters: _provider.hasActiveFilters,
                      onClear:   _provider.clearFilters,
                      onAdd:     () => _openEditor(context),
                      emptyDescription:
                          'Add your first cost item to start costing this trip.',
                    )
                  : _BudgetItemList(
                      items:    items,
                      isMobile: isMobile,
                      onTap:    (item) => _openEditor(context, existing: item),
                      onDelete: (item) => _provider.deleteItem(item.id),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Budget item list ──────────────────────────────────────────────────────────

class _BudgetItemList extends StatelessWidget {
  final List<CostItem> items;
  final bool isMobile;
  final void Function(CostItem) onTap;
  final void Function(CostItem) onDelete;

  const _BudgetItemList({
    required this.items,
    required this.isMobile,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Column(
      children: [
        BudgetColumnHeader(hPad: hPad),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                hPad, 4, hPad, AppSpacing.massive),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AdaptiveSpacing.rowGap),
            itemBuilder: (context, i) => BudgetRow(
              key:      ValueKey(items[i].id),
              item:     items[i],
              onTap:    () => onTap(items[i]),
              onDelete: () => onDelete(items[i]),
            ),
          ),
        ),
      ],
    );
  }
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
    final hPad =
        isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

    if (isMobile) {
      return Container(
        color: AppColors.background,
        padding: EdgeInsets.symmetric(
            horizontal: hPad, vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [BudgetAddButton(onTap: onAdd)],
        ),
      );
    }

    // Desktop: compact inline stats row + Add Item button
    final marginPct = summary.totalSellPrice > 0
        ? '${(summary.totalMargin / summary.totalSellPrice * 100).toStringAsFixed(1)}%'
        : null;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 14),
      child: Row(
        children: [
          Expanded(
            child: _CompactStat(
              label: 'Operational Cost',
              accentColor: const Color(0xFF4A90A4),
              amount: summary.totalNetCost,
              currency: currency,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Trip Revenue',
              accentColor: const Color(0xFFC9A96E),
              amount: summary.totalSellPrice,
              currency: currency,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Projected Margin',
              accentColor: const Color(0xFF5A9E6F),
              amount: summary.totalMargin,
              currency: currency,
              subLabel: marginPct,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Outstanding',
              accentColor: const Color(0xFFD4845A),
              amount: summary.outstandingAmount,
              currency: currency,
              subLabel: '${summary.itemCount} items',
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Deposit Paid',
              accentColor: const Color(0xFF5A9E6F),
              amount: summary.totalDepositPaid,
              currency: currency,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _CompactStat(
              label: 'Remaining Bal.',
              accentColor: const Color(0xFF7C6FAB),
              amount: summary.totalRemainingBalance,
              currency: currency,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          BudgetAddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

// ── Compact stat block ────────────────────────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final String label;
  final Color accentColor;
  final double amount;
  final String currency;
  final String? subLabel;

  const _CompactStat({
    required this.label,
    required this.accentColor,
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
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          CurrencyAmount(
            amount:   amount,
            currency: currency,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: const Color(0xFF111111),
            ),
          ),
          if (subLabel != null)
            Text(
              subLabel!,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted, fontSize: 10),
            ),
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
