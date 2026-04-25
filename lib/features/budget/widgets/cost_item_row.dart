import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../shared/widgets/approval_chip.dart';
import 'cost_status_chip.dart';

/// Column widths for the desktop budget table.
abstract class BudgetColumns {
  static const double name       = 200.0;
  static const double supplier   = 160.0;
  static const double category   = 120.0;
  static const double city       =  90.0;
  static const double net        = 100.0;
  static const double deposit    = 110.0;
  static const double remaining  = 120.0;
  static const double sell       = 100.0;
  static const double status     = 100.0;
  static const double dueDate    =  90.0;
  static const double actions    =  32.0;

  static const double totalWidth =
      name + supplier + category + city + net + deposit + remaining +
      sell + status + dueDate + actions +
      AppSpacing.pagePaddingH * 2;
}

/// Header row for desktop budget table.
class BudgetTableHeader extends StatelessWidget {
  const BudgetTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          _H('ITEM NAME',       BudgetColumns.name),
          _H('SUPPLIER',        BudgetColumns.supplier),
          _H('CATEGORY',        BudgetColumns.category),
          _H('CITY',            BudgetColumns.city),
          _H('NET COST',        BudgetColumns.net),
          _H('DEPOSIT PAID',    BudgetColumns.deposit),
          _H('REMAINING BAL.',  BudgetColumns.remaining),
          _H('SELL PRICE',      BudgetColumns.sell),
          _H('PAYMENT',         BudgetColumns.status),
          _H('DUE DATE',        BudgetColumns.dueDate),
          const SizedBox(width: BudgetColumns.actions),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String label;
  final double width;
  const _H(this.label, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: AppTextStyles.tableHeader,
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CostItemRow — auto-switches desktop/mobile via Responsive
// ─────────────────────────────────────────────────────────────────────────────

class CostItemRow extends StatelessWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const CostItemRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Responsive.isMobile(context)
        ? _MobileCard(item: item, onTap: onTap, onDelete: onDelete)
        : _DesktopRow(item: item, onTap: onTap, onDelete: onDelete);
  }
}

// ── Desktop row ───────────────────────────────────────────────────────────────

class _DesktopRow extends StatelessWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _DesktopRow({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(
            children: [
              // Item name + approval
              SizedBox(
                width: BudgetColumns.name,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.itemName,
                          style: AppTextStyles.tableCell
                              .copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ApprovalStatusChip(
                        status: item.approvalStatus, compact: true),
                  ],
                ),
              ),

                  // Supplier
              SizedBox(
                width: BudgetColumns.supplier,
                child: Text(item.supplierName ?? '—',
                    style: AppTextStyles.tableCell,
                    overflow: TextOverflow.ellipsis),
              ),

              // Category
              SizedBox(
                width: BudgetColumns.category,
                child: CostCategoryBadge(category: item.category),
              ),

              // City
              SizedBox(
                width: BudgetColumns.city,
                child: Text(item.city,
                    style: AppTextStyles.tableCell,
                    overflow: TextOverflow.ellipsis),
              ),

              // Net cost
              SizedBox(
                width: BudgetColumns.net,
                child: CurrencyAmount(
                    amount: item.netCost, currency: item.currency,
                    style: AppTextStyles.tableCell),
              ),

              // Deposit paid
              SizedBox(
                width: BudgetColumns.deposit,
                child: CurrencyAmount(
                    amount: item.depositPaid, currency: item.currency,
                    style: AppTextStyles.tableCell.copyWith(
                        color: item.depositPaid > 0
                            ? const Color(0xFF5A9E6F)
                            : AppColors.textMuted)),
              ),

              // Remaining balance
              SizedBox(
                width: BudgetColumns.remaining,
                child: CurrencyAmount(
                    amount: item.remainingBalance, currency: item.currency,
                    style: AppTextStyles.tableCell.copyWith(
                        fontWeight: FontWeight.w500,
                        color: item.remainingBalance > 0
                            ? const Color(0xFFD4845A)
                            : const Color(0xFF5A9E6F))),
              ),

              // Sell price
              SizedBox(
                width: BudgetColumns.sell,
                child: CurrencyAmount(
                    amount: item.sellPrice, currency: item.currency,
                    style: AppTextStyles.tableCell
                        .copyWith(fontWeight: FontWeight.w500)),
              ),

              // Payment status
              SizedBox(
                width: BudgetColumns.status,
                child: PaymentStatusChip(status: item.paymentStatus),
              ),

              // Due date
              SizedBox(
                width: BudgetColumns.dueDate,
                child: item.paymentDueDate != null
                    ? _DueDateLabel(date: item.paymentDueDate!)
                    : Text('—', style: AppTextStyles.tableCell
                        .copyWith(color: AppColors.textMuted)),
              ),

              // Delete action
              SizedBox(
                width: BudgetColumns.actions,
                child: GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile card ───────────────────────────────────────────────────────────────

class _MobileCard extends StatelessWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MobileCard({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingHMobile, vertical: AppSpacing.xs),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          hoverColor: AppColors.surfaceAlt,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CostCategoryIconTile(category: item.category, size: 32),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(item.itemName,
                          style: AppTextStyles.labelMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    CostCategoryBadge(category: item.category, iconOnly: true),
                    const SizedBox(width: AppSpacing.xs),
                    Text(item.city,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                    const Spacer(),
                    PaymentStatusChip(status: item.paymentStatus),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Net', style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                        CurrencyAmount(
                            amount: item.netCost, currency: item.currency,
                            style: AppTextStyles.tableCell),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deposit', style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                        CurrencyAmount(
                            amount: item.depositPaid, currency: item.currency,
                            style: AppTextStyles.tableCell.copyWith(
                                color: const Color(0xFF5A9E6F))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remaining', style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                        CurrencyAmount(
                            amount: item.remainingBalance, currency: item.currency,
                            style: AppTextStyles.tableCell.copyWith(
                                fontWeight: FontWeight.w600,
                                color: item.remainingBalance > 0
                                    ? const Color(0xFFD4845A)
                                    : const Color(0xFF5A9E6F))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sell', style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                        CurrencyAmount(
                            amount: item.sellPrice, currency: item.currency,
                            style: AppTextStyles.tableCell
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared screen widgets ─────────────────────────────────────────────────────

/// Returns the most frequent currency in [items], or 'USD' as fallback.
String dominantCurrency(List<CostItem> items) {
  if (items.isEmpty) return 'USD';
  final freq = <String, int>{};
  for (final item in items) {
    freq[item.currency] = (freq[item.currency] ?? 0) + 1;
  }
  return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

class BudgetAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const BudgetAddButton({super.key, required this.onTap});

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
            Text('Add Item',
                style: AppTextStyles.labelMedium
                    .copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class BudgetEmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onAdd;
  final String emptyDescription;

  const BudgetEmptyState({
    super.key,
    required this.hasFilters,
    required this.onClear,
    required this.onAdd,
    this.emptyDescription = 'Add your first cost item to get started.',
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
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.accent, size: 24),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilters ? 'No items match filters' : 'No budget items yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting filters or clearing them.'
                : emptyDescription,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Add Cost Item',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Due date label ────────────────────────────────────────────────────────────

class _DueDateLabel extends StatelessWidget {
  final DateTime date;
  const _DueDateLabel({required this.date});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date.isBefore(DateTime.now());
    return Text(
      DateFormat('d MMM').format(date),
      style: AppTextStyles.tableCell.copyWith(
        color: isOverdue ? const Color(0xFF991B1B) : AppColors.textPrimary,
        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
