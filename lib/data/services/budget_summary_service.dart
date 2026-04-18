import '../models/cost_item_model.dart';

// =============================================================================
// BudgetSummaryService
//
// Pure computation over a list of CostItems — no Supabase calls.
// Call after loading items via BudgetRepository.
// All amounts in the item's original currency; multi-currency totals
// are grouped separately.
// =============================================================================

class BudgetSummary {
  /// Total net cost across all items (same currency assumed, or use perCurrency).
  final double totalNetCost;

  /// Total sell price across all items.
  final double totalSellPrice;

  /// Gross margin = sellPrice - netCost.
  final double grossMargin;

  /// Margin percentage = grossMargin / sellPrice * 100. Null if sellPrice == 0.
  final double? marginPercent;

  /// Sum of sell prices for items with payment_status == 'due'.
  final double totalDue;

  /// Sum of sell prices for items with payment_status == 'paid'.
  final double totalPaid;

  /// Sum of sell prices for items with payment_status == 'pending'.
  final double totalPending;

  /// Number of items.
  final int itemCount;

  /// Per-currency breakdown: currency → totalSellPrice.
  final Map<String, double> perCurrency;

  const BudgetSummary({
    required this.totalNetCost,
    required this.totalSellPrice,
    required this.grossMargin,
    required this.marginPercent,
    required this.totalDue,
    required this.totalPaid,
    required this.totalPending,
    required this.itemCount,
    required this.perCurrency,
  });

  static const empty = BudgetSummary(
    totalNetCost:   0,
    totalSellPrice: 0,
    grossMargin:    0,
    marginPercent:  null,
    totalDue:       0,
    totalPaid:      0,
    totalPending:   0,
    itemCount:      0,
    perCurrency:    {},
  );
}

class BudgetSummaryService {
  /// Compute a summary from a list of cost items.
  static BudgetSummary compute(List<CostItem> items) {
    if (items.isEmpty) return BudgetSummary.empty;

    double netCost   = 0;
    double sellPrice = 0;
    double due       = 0;
    double paid      = 0;
    double pending   = 0;
    final Map<String, double> byCurrency = {};

    for (final item in items) {
      netCost   += item.netCost;
      sellPrice += item.sellPrice;

      switch (item.paymentStatus) {
        case PaymentStatus.due:
          due += item.sellPrice;
        case PaymentStatus.paid:
          paid += item.sellPrice;
        case PaymentStatus.pending:
          pending += item.sellPrice;
        case PaymentStatus.cancelled:
          break; // excluded from totals
      }

      byCurrency[item.currency] =
          (byCurrency[item.currency] ?? 0) + item.sellPrice;
    }

    final margin  = sellPrice - netCost;
    final marginPct = sellPrice > 0 ? (margin / sellPrice * 100) : null;

    return BudgetSummary(
      totalNetCost:   netCost,
      totalSellPrice: sellPrice,
      grossMargin:    margin,
      marginPercent:  marginPct,
      totalDue:       due,
      totalPaid:      paid,
      totalPending:   pending,
      itemCount:      items.length,
      perCurrency:    byCurrency,
    );
  }

  /// Compute summary scoped to a single trip.
  static BudgetSummary computeForTrip(List<CostItem> allItems, String tripId) =>
      compute(allItems.where((i) => i.tripId == tripId).toList());
}
