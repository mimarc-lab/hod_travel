import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../shared/widgets/approval_chip.dart';
import 'cost_status_chip.dart';

// ── Legacy table column widths (kept for backward compatibility) ───────────────
// BudgetColumns and BudgetTableHeader are no longer used in the primary
// budget screens but are retained here for any downstream references.

abstract class BudgetColumns {
  static const double name      = 200.0;
  static const double supplier  = 160.0;
  static const double category  = 120.0;
  static const double city      =  90.0;
  static const double net       = 100.0;
  static const double deposit   = 110.0;
  static const double remaining = 120.0;
  static const double sell      = 100.0;
  static const double status    = 100.0;
  static const double dueDate   =  90.0;
  static const double actions   =  32.0;

  static const double totalWidth =
      name + supplier + category + city + net + deposit + remaining +
      sell + status + dueDate + actions +
      AppSpacing.pagePaddingH * 2;
}

/// Legacy table header — no longer rendered in the redesigned screens.
class BudgetTableHeader extends StatelessWidget {
  const BudgetTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          _H('ITEM NAME',      BudgetColumns.name),
          _H('SUPPLIER',       BudgetColumns.supplier),
          _H('FINANCE NOTES',  BudgetColumns.category),
          _H('CITY',           BudgetColumns.city),
          _H('NET COST',       BudgetColumns.net),
          _H('DEPOSIT PAID',   BudgetColumns.deposit),
          _H('REMAINING BAL.', BudgetColumns.remaining),
          _H('SELL PRICE',     BudgetColumns.sell),
          _H('PAYMENT',        BudgetColumns.status),
          _H('DUE DATE',       BudgetColumns.dueDate),
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
// BudgetItemCard — premium operational finance card
// ─────────────────────────────────────────────────────────────────────────────

class BudgetItemCard extends StatefulWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BudgetItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<BudgetItemCard> createState() => _BudgetItemCardState();
}

// Backward-compatible alias for any importer still referencing CostItemRow.
typedef CostItemRow = BudgetItemCard;

class _BudgetItemCardState extends State<BudgetItemCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(_hovered ? 0x0F000000 : 0x06000000),
                blurRadius: _hovered ? 20 : 8,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
              BoxShadow(
                color: Color(_hovered ? 0x05000000 : 0x00000000),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  CostCategoryIconTile(
                      category: widget.item.category, size: 38),
                  const SizedBox(width: 12),
                  // Card content
                  Expanded(child: _CardContent(item: widget.item)),
                  // Action menu
                  _BudgetActionMenu(onDelete: widget.onDelete),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card content ──────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final CostItem item;
  const _CardContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasDeposit = item.depositPaid > 0;
    final hasDue = item.paymentDueDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name + approval chip + payment status
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.itemName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111111),
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PaymentStatusChip(status: item.paymentStatus),
                const SizedBox(height: 3),
                ApprovalStatusChip(
                    status: item.approvalStatus, compact: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Supplier + city meta line
        _MetaLine(item: item),
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 3),
          _NotesLine(notes: item.notes!),
        ],
        const SizedBox(height: 9),

        // Hairline divider
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 9),

        // Financial summary row
        _FinancialRow(item: item),

        // Deposit / remaining row
        if (hasDeposit) ...[
          const SizedBox(height: 5),
          _DepositRow(item: item),
        ],

        // Due date
        if (hasDue) ...[
          const SizedBox(height: 5),
          _DueDateRow(date: item.paymentDueDate!),
        ],
      ],
    );
  }
}

// ── Meta line: supplier · city ────────────────────────────────────────────────

class _MetaLine extends StatelessWidget {
  final CostItem item;
  const _MetaLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (item.supplierName != null && item.supplierName!.isNotEmpty) {
      parts.add(item.supplierName!);
    }
    if (item.city.isNotEmpty) parts.add(item.city);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.storefront_outlined,
            size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(' · '),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Notes line ────────────────────────────────────────────────────────────────

class _NotesLine extends StatelessWidget {
  final String notes;
  const _NotesLine({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: notes,
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0x30000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 12,
        color: Colors.white,
        height: 1.5,
      ),
      child: Row(
        children: [
          const Icon(Icons.notes_rounded, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              notes,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Financial summary row ─────────────────────────────────────────────────────

class _FinancialRow extends StatelessWidget {
  final CostItem item;
  const _FinancialRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Net cost
        _FinanceFigure(
          label: 'Net',
          amount: item.netCost,
          currency: item.currency,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded,
              size: 11, color: AppColors.textMuted),
        ),
        // Sell price
        _FinanceFigure(
          label: 'Sell',
          amount: item.sellPrice,
          currency: item.currency,
          bold: true,
        ),
        const Spacer(),
        // Margin badge
        _MarginBadge(margin: item.margin, currency: item.currency),
      ],
    );
  }
}

class _FinanceFigure extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final bool bold;
  const _FinanceFigure({
    required this.label,
    required this.amount,
    required this.currency,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
        CurrencyAmount(
          amount: amount,
          currency: currency,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF222222),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Margin badge ──────────────────────────────────────────────────────────────

class _MarginBadge extends StatelessWidget {
  final double margin;
  final String currency;
  const _MarginBadge({required this.margin, required this.currency});

  String _fmt(double v) {
    final r = v.round();
    return r.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = margin >= 0;
    final color = isPositive
        ? const Color(0xFF5A9E6F)
        : const Color(0xFFD4845A);
    final prefix = isPositive ? '+' : '−';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$prefix$currency ${_fmt(margin.abs())}',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Deposit row ───────────────────────────────────────────────────────────────

class _DepositRow extends StatelessWidget {
  final CostItem item;
  const _DepositRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final remainingColor = item.remainingBalance > 0.005
        ? const Color(0xFFD4845A)
        : const Color(0xFF5A9E6F);

    return Row(
      children: [
        Text(
          'Deposit  ',
          style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted),
        ),
        CurrencyAmount(
          amount: item.depositPaid,
          currency: item.currency,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A9E6F)),
        ),
        Text(
          '  ·  Remaining  ',
          style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted),
        ),
        CurrencyAmount(
          amount: item.remainingBalance,
          currency: item.currency,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: remainingColor),
        ),
      ],
    );
  }
}

// ── Due date row ──────────────────────────────────────────────────────────────

class _DueDateRow extends StatelessWidget {
  final DateTime date;
  const _DueDateRow({required this.date});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date.isBefore(DateTime.now());
    final color = isOverdue
        ? const Color(0xFF991B1B)
        : AppColors.textMuted;

    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          isOverdue
              ? 'Overdue · ${DateFormat('d MMM').format(date)}'
              : 'Due ${DateFormat('d MMM').format(date)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Action menu ───────────────────────────────────────────────────────────────

class _BudgetActionMenu extends StatelessWidget {
  final VoidCallback onDelete;
  const _BudgetActionMenu({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      tooltip: 'Item options',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: Color(0xFFCCCCCC),
      ),
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFB00020)),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(
                    color: Color(0xFFB00020), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared screen widgets (used by both BudgetScreen and TripBudgetScreen)
// ─────────────────────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius:
              BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'Add Item',
              style: AppTextStyles.labelMedium
                  .copyWith(color: Colors.white),
            ),
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
    this.emptyDescription =
        'Add your first cost item to get started.',
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
            hasFilters
                ? 'No items match filters'
                : 'No budget items yet',
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
                  borderRadius: BorderRadius.circular(10),
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
