import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../shared/adaptive_table/adaptive_column.dart';
import '../../../shared/adaptive_table/adaptive_row.dart';
import '../../../shared/adaptive_table/adaptive_row_actions.dart';
import '../../../shared/adaptive_table/adaptive_status_chip.dart';
import '../../../shared/design_system/radius_tokens.dart';
import '../../../shared/design_system/responsive_breakpoints.dart';
import '../../../shared/design_system/shadow_tokens.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../../../shared/design_system/typography_tokens.dart';
import '../../../shared/widgets/approval_chip.dart';
import 'cost_status_chip.dart';

// ── Column definitions ─────────────────────────────────────────────────────────

/// Adaptive column set for budget cost items.
///
/// PRIMARY   → always visible (item name + category icon)
/// SECONDARY → tablet + desktop (net, sell, margin, status)
/// TERTIARY  → desktop only (due date, supplier)
List<AdaptiveColumn<CostItem>> budgetColumns() {
  return [
    // PRIMARY — item name + category icon + city
    AdaptiveColumn<CostItem>(
      key: 'item',
      label: 'Item',
      priority: ColumnPriority.primary,
      flex: 3,
      builder: (item) => _ItemCell(item: item),
    ),

    // SECONDARY — net cost
    AdaptiveColumn<CostItem>(
      key: 'net',
      label: 'Net Cost',
      priority: ColumnPriority.secondary,
      width: 88,
      alignment: ColumnAlignment.end,
      builder: (item) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Net',
              style: AdaptiveTypography.tertiaryCell
                  .copyWith(fontSize: 10)),
          CurrencyAmount(
            amount: item.netCost,
            currency: item.currency,
            style: AdaptiveTypography.secondaryCell,
          ),
        ],
      ),
    ),

    // SECONDARY — sell price
    AdaptiveColumn<CostItem>(
      key: 'sell',
      label: 'Sell Price',
      priority: ColumnPriority.secondary,
      width: 88,
      alignment: ColumnAlignment.end,
      builder: (item) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sell',
              style: AdaptiveTypography.tertiaryCell
                  .copyWith(fontSize: 10)),
          CurrencyAmount(
            amount: item.sellPrice,
            currency: item.currency,
            style: AdaptiveTypography.secondaryCell
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),

    // SECONDARY — margin badge
    AdaptiveColumn<CostItem>(
      key: 'margin',
      label: 'Margin',
      priority: ColumnPriority.secondary,
      width: 88,
      alignment: ColumnAlignment.end,
      builder: (item) =>
          _MarginBadge(margin: item.margin, currency: item.currency),
    ),

    // SECONDARY — payment status
    AdaptiveColumn<CostItem>(
      key: 'status',
      label: 'Payment',
      priority: ColumnPriority.secondary,
      width: 100,
      builder: (item) => AdaptiveStatusChip(
        label: item.paymentStatus.label,
        backgroundColor: item.paymentStatus.bgColor,
        textColor: item.paymentStatus.textColor,
        compact: true,
      ),
    ),

    // TERTIARY — due date (desktop only)
    AdaptiveColumn<CostItem>(
      key: 'due',
      label: 'Due Date',
      priority: ColumnPriority.tertiary,
      width: 90,
      builder: (item) => item.paymentDueDate != null
          ? _DueDateText(date: item.paymentDueDate!)
          : Text('—', style: AdaptiveTypography.tertiaryCell),
    ),

    // TERTIARY — supplier (desktop only)
    AdaptiveColumn<CostItem>(
      key: 'supplier',
      label: 'Supplier',
      priority: ColumnPriority.tertiary,
      width: 120,
      builder: (item) => Text(
        item.supplierName ?? '—',
        style: AdaptiveTypography.tertiaryCell,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ];
}

// ── BudgetRow — adaptive entry point ──────────────────────────────────────────

/// Renders a [CostItem] as:
/// - Desktop/Tablet: [AdaptiveRow] with columns (item · net · sell · margin · status · due · supplier)
/// - Mobile: [_MobileBudgetCard] preserving the rich financial card layout.
///
/// All financial logic is in the model; no computations live here.
class BudgetRow extends StatelessWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BudgetRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveBreakpoints.layoutOf(context);

    if (layout == Layout.mobile) {
      return _MobileBudgetCard(
        item: item,
        onTap: onTap,
        onDelete: onDelete,
      );
    }

    return AdaptiveRow<CostItem>(
      item: item,
      columns: budgetColumns(),
      layout: layout,
      onTap: onTap,
      accentBar: item.category.color,
      actionsWidget: AdaptiveRowActions<CostItem>(
        item: item,
        actions: [
          AdaptiveAction<CostItem>(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            isDestructive: true,
            onTap: (_) => onDelete(),
          ),
        ],
      ),
    );
  }
}

// ── Column header ─────────────────────────────────────────────────────────────

/// Shows column labels aligned to the [BudgetRow] desktop layout.
/// Pass the same [hPad] used by the surrounding [ListView].
/// Invisible on mobile.
class BudgetColumnHeader extends StatelessWidget {
  final double hPad;
  const BudgetColumnHeader({super.key, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final layout = AdaptiveBreakpoints.layoutOf(context);
    if (layout == Layout.mobile) return const SizedBox.shrink();

    final cols =
        budgetColumns().where((c) => c.visibleFor(layout)).toList();

    // Mirror AdaptiveRow inner offsets:
    // left  = hPad + 3 (accent bar) + rowPaddingH (16)
    // right = hPad + 8 (action right padding) + ~20 (icon)
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad + 19, 6, hPad + 36, 4),
      child: Row(
        children: [
          for (int i = 0; i < cols.length; i++) ...[
            if (i > 0)
              const SizedBox(width: AdaptiveSpacing.columnGap),
            cols[i].sized(
              Text(cols[i].label,
                  style: AdaptiveTypography.columnHeader),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Item cell (PRIMARY column) ────────────────────────────────────────────────

class _ItemCell extends StatelessWidget {
  final CostItem item;
  const _ItemCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CostCategoryIconTile(category: item.category, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.itemName,
                style: AdaptiveTypography.primaryCell.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              _SubLine(item: item),
              if (item.approvalStatus != ApprovalStatus.draft) ...[
                const SizedBox(height: 3),
                ApprovalStatusChip(
                    status: item.approvalStatus, compact: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubLine extends StatelessWidget {
  final CostItem item;
  const _SubLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = [
      item.category.label,
      if (item.city.isNotEmpty) item.city,
    ];
    return Text(
      parts.join(' · '),
      style: AdaptiveTypography.primarySubCell,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Margin badge ──────────────────────────────────────────────────────────────

class _MarginBadge extends StatelessWidget {
  final double margin;
  final String currency;
  const _MarginBadge({required this.margin, required this.currency});

  String _fmt(double v) => v.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    final isPositive = margin >= 0;
    final color =
        isPositive ? const Color(0xFF5A9E6F) : const Color(0xFFD4845A);
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

// ── Due date text ─────────────────────────────────────────────────────────────

class _DueDateText extends StatelessWidget {
  final DateTime date;
  const _DueDateText({required this.date});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date.isBefore(DateTime.now());
    final color = isOverdue ? const Color(0xFF991B1B) : AppColors.textMuted;
    return Text(
      isOverdue
          ? 'Overdue · ${DateFormat('d MMM').format(date)}'
          : DateFormat('d MMM').format(date),
      style: AdaptiveTypography.tertiaryCell.copyWith(
        color: color,
        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

// ── Mobile budget card ────────────────────────────────────────────────────────

class _MobileBudgetCard extends StatefulWidget {
  final CostItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MobileBudgetCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_MobileBudgetCard> createState() => _MobileBudgetCardState();
}

class _MobileBudgetCardState extends State<_MobileBudgetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasDeposit = item.depositPaid > 0;
    final hasDue = item.paymentDueDate != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AdaptiveRadius.cardBorder,
            boxShadow: _hovered
                ? AdaptiveShadows.cardHover
                : AdaptiveShadows.cardResting,
          ),
          child: ClipRRect(
            borderRadius: AdaptiveRadius.cardBorder,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar (category colour)
                  Container(width: 3, color: item.category.color),

                  // Card body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: icon + name + status + action menu
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CostCategoryIconTile(
                                  category: item.category, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
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
                                    if (item.supplierName != null &&
                                        item.supplierName!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.supplierName!,
                                        style:
                                            AdaptiveTypography.primarySubCell,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AdaptiveStatusChip(
                                    label: item.paymentStatus.label,
                                    backgroundColor:
                                        item.paymentStatus.bgColor,
                                    textColor: item.paymentStatus.textColor,
                                    compact: true,
                                  ),
                                  const SizedBox(height: 3),
                                  ApprovalStatusChip(
                                      status: item.approvalStatus,
                                      compact: true),
                                ],
                              ),
                              // Action menu (always visible on mobile)
                              _MobileActionMenu(onDelete: widget.onDelete),
                            ],
                          ),

                          const SizedBox(height: 9),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 9),

                          // Financial row: net → sell → margin
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Net',
                                      style: AdaptiveTypography.tertiaryCell
                                          .copyWith(fontSize: 10)),
                                  CurrencyAmount(
                                    amount: item.netCost,
                                    currency: item.currency,
                                    style: AdaptiveTypography.secondaryCell,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Icon(Icons.arrow_forward_rounded,
                                    size: 11, color: AppColors.textMuted),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sell',
                                      style: AdaptiveTypography.tertiaryCell
                                          .copyWith(fontSize: 10)),
                                  CurrencyAmount(
                                    amount: item.sellPrice,
                                    currency: item.currency,
                                    style: AdaptiveTypography.secondaryCell
                                        .copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              _MarginBadge(
                                  margin: item.margin,
                                  currency: item.currency),
                            ],
                          ),

                          // Deposit / remaining row
                          if (hasDeposit) ...[
                            const SizedBox(height: 5),
                            _DepositLine(item: item),
                          ],

                          // Due date row
                          if (hasDue) ...[
                            const SizedBox(height: 5),
                            _DueDateLine(date: item.paymentDueDate!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepositLine extends StatelessWidget {
  final CostItem item;
  const _DepositLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final remainingColor = item.remainingBalance > 0.005
        ? const Color(0xFFD4845A)
        : const Color(0xFF5A9E6F);
    return Row(
      children: [
        Text('Deposit  ',
            style: AdaptiveTypography.tertiaryCell),
        CurrencyAmount(
          amount: item.depositPaid,
          currency: item.currency,
          style: AdaptiveTypography.tertiaryCell.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5A9E6F)),
        ),
        Text('  ·  Remaining  ',
            style: AdaptiveTypography.tertiaryCell),
        CurrencyAmount(
          amount: item.remainingBalance,
          currency: item.currency,
          style: AdaptiveTypography.tertiaryCell.copyWith(
              fontWeight: FontWeight.w600, color: remainingColor),
        ),
      ],
    );
  }
}

class _DueDateLine extends StatelessWidget {
  final DateTime date;
  const _DueDateLine({required this.date});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date.isBefore(DateTime.now());
    final color =
        isOverdue ? const Color(0xFF991B1B) : AppColors.textMuted;
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          isOverdue
              ? 'Overdue · ${DateFormat('d MMM').format(date)}'
              : 'Due ${DateFormat('d MMM').format(date)}',
          style: AdaptiveTypography.tertiaryCell.copyWith(
            color: color,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _MobileActionMenu extends StatelessWidget {
  final VoidCallback onDelete;
  const _MobileActionMenu({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) { if (v == 'delete') onDelete(); },
      tooltip: 'Item options',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 16, color: Color(0xFFCCCCCC)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFB00020)),
              const SizedBox(width: 8),
              Text('Delete',
                  style: AdaptiveTypography.secondaryCell
                      .copyWith(color: const Color(0xFFB00020))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Backward-compatible alias ─────────────────────────────────────────────────
// Any file still importing BudgetItemCard from cost_item_row.dart continues
// to work. This alias allows gradual migration.
// ignore: unused_element
typedef _BudgetItemCardAlias = BudgetRow;

// Re-export AppSpacing for screens that previously got it via cost_item_row.dart
// (kept as a reminder; actual import stays in each screen file).
// ignore: unused_element
const _kBudgetRowGap = AppSpacing.sm; // 8px
