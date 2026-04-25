import 'package:flutter/material.dart';
import 'approval_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum CostCategory {
  accommodation,
  dining,
  transport,
  experience,
  guide,
  logistics,
  flights,
  other,
}

enum PaymentStatus { pending, due, paid, cancelled }

enum MarkupType { percentage, fixed }

// ─────────────────────────────────────────────────────────────────────────────
// CostItem model
// ─────────────────────────────────────────────────────────────────────────────

class CostItem {
  final String id;
  final String tripId;
  final String? taskId;
  final String? itineraryItemId;
  final String? supplierId;
  final String? supplierName;
  final String itemName;
  final CostCategory category;
  final String city;
  final DateTime? date;
  final String currency;
  final double netCost;
  final double depositPaid;
  final MarkupType markupType;
  final double markupValue; // percentage (e.g. 15.0) or fixed amount
  final double sellPrice;
  final PaymentStatus paymentStatus;
  final ApprovalStatus approvalStatus;
  final DateTime? paymentDueDate;
  final String? notes;

  const CostItem({
    required this.id,
    required this.tripId,
    this.taskId,
    this.itineraryItemId,
    this.supplierId,
    this.supplierName,
    required this.itemName,
    required this.category,
    required this.city,
    this.date,
    required this.currency,
    required this.netCost,
    this.depositPaid = 0,
    required this.markupType,
    required this.markupValue,
    required this.sellPrice,
    required this.paymentStatus,
    this.approvalStatus = ApprovalStatus.draft,
    this.paymentDueDate,
    this.notes,
  });

  /// Derived sell price from net + markup (does not mutate; use in editor preview).
  static double deriveSellPrice(
      double net, MarkupType type, double markup) {
    if (type == MarkupType.percentage) {
      return net * (1 + markup / 100);
    } else {
      return net + markup;
    }
  }

  double get margin => sellPrice - netCost;
  double get remainingBalance => netCost - depositPaid;

  CostItem copyWith({
    String? tripId,
    String? taskId,
    bool clearTaskId = false,
    String? itineraryItemId,
    bool clearItineraryItemId = false,
    String? supplierId,
    bool clearSupplierId = false,
    String? supplierName,
    bool clearSupplierName = false,
    String? itemName,
    CostCategory? category,
    String? city,
    DateTime? date,
    bool clearDate = false,
    String? currency,
    double? netCost,
    double? depositPaid,
    MarkupType? markupType,
    double? markupValue,
    double? sellPrice,
    PaymentStatus? paymentStatus,
    ApprovalStatus? approvalStatus,
    DateTime? paymentDueDate,
    bool clearPaymentDueDate = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return CostItem(
      id: id,
      tripId: tripId ?? this.tripId,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      itineraryItemId: clearItineraryItemId
          ? null
          : (itineraryItemId ?? this.itineraryItemId),
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      supplierName: clearSupplierName ? null : (supplierName ?? this.supplierName),
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      city: city ?? this.city,
      date: clearDate ? null : (date ?? this.date),
      currency: currency ?? this.currency,
      netCost: netCost ?? this.netCost,
      depositPaid: depositPaid ?? this.depositPaid,
      markupType: markupType ?? this.markupType,
      markupValue: markupValue ?? this.markupValue,
      sellPrice: sellPrice ?? this.sellPrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      paymentDueDate: clearPaymentDueDate
          ? null
          : (paymentDueDate ?? this.paymentDueDate),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BudgetSummary — computed from a list of cost items
// ─────────────────────────────────────────────────────────────────────────────

class BudgetSummary {
  final double totalNetCost;
  final double totalSellPrice;
  final double totalMargin;
  final double outstandingAmount; // sell price of unpaid items
  final double totalDepositPaid;
  final double totalRemainingBalance;
  final int itemCount;

  const BudgetSummary({
    required this.totalNetCost,
    required this.totalSellPrice,
    required this.totalMargin,
    required this.outstandingAmount,
    required this.totalDepositPaid,
    required this.totalRemainingBalance,
    required this.itemCount,
  });

  static BudgetSummary fromItems(List<CostItem> items) {
    double net = 0, sell = 0, outstanding = 0, deposit = 0;
    for (final item in items) {
      net     += item.netCost;
      sell    += item.sellPrice;
      deposit += item.depositPaid;
      if (item.paymentStatus != PaymentStatus.paid &&
          item.paymentStatus != PaymentStatus.cancelled) {
        outstanding += item.sellPrice;
      }
    }
    return BudgetSummary(
      totalNetCost:         net,
      totalSellPrice:       sell,
      totalMargin:          sell - net,
      outstandingAmount:    outstanding,
      totalDepositPaid:     deposit,
      totalRemainingBalance: net - deposit,
      itemCount: items.length,
    );
  }

  static const BudgetSummary empty = BudgetSummary(
    totalNetCost:          0,
    totalSellPrice:        0,
    totalMargin:           0,
    outstandingAmount:     0,
    totalDepositPaid:      0,
    totalRemainingBalance: 0,
    itemCount:             0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Display extensions
// ─────────────────────────────────────────────────────────────────────────────

/// Parse a DB category string to [CostCategory].
CostCategory costCategoryFromDb(String s) => switch (s) {
  'accommodation' => CostCategory.accommodation,
  'dining'        => CostCategory.dining,
  'transport'     => CostCategory.transport,
  'experience'    => CostCategory.experience,
  'guide'         => CostCategory.guide,
  'logistics'     => CostCategory.logistics,
  'flights'       => CostCategory.flights,
  _               => CostCategory.other,
};

/// Parse a DB payment_status string to [PaymentStatus].
PaymentStatus paymentStatusFromDb(String s) => switch (s) {
  'due'       => PaymentStatus.due,
  'paid'      => PaymentStatus.paid,
  'cancelled' => PaymentStatus.cancelled,
  _           => PaymentStatus.pending,
};

extension CostCategoryDisplay on CostCategory {
  String get dbValue => switch (this) {
    CostCategory.accommodation => 'accommodation',
    CostCategory.dining        => 'dining',
    CostCategory.transport     => 'transport',
    CostCategory.experience    => 'experience',
    CostCategory.guide         => 'guide',
    CostCategory.logistics     => 'logistics',
    CostCategory.flights       => 'flights',
    CostCategory.other         => 'other',
  };

  String get label {
    switch (this) {
      case CostCategory.accommodation: return 'Accommodation';
      case CostCategory.dining:        return 'Dining';
      case CostCategory.transport:     return 'Transport';
      case CostCategory.experience:    return 'Experience';
      case CostCategory.guide:         return 'Guide';
      case CostCategory.logistics:     return 'Logistics';
      case CostCategory.flights:       return 'Flights';
      case CostCategory.other:         return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case CostCategory.accommodation: return Icons.hotel_rounded;
      case CostCategory.dining:        return Icons.restaurant_outlined;
      case CostCategory.transport:     return Icons.directions_car_outlined;
      case CostCategory.experience:    return Icons.star_border_rounded;
      case CostCategory.guide:         return Icons.person_pin_circle_outlined;
      case CostCategory.logistics:     return Icons.local_shipping_outlined;
      case CostCategory.flights:       return Icons.flight_rounded;
      case CostCategory.other:         return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CostCategory.accommodation: return const Color(0xFF7C6FAB);
      case CostCategory.dining:        return const Color(0xFFD4845A);
      case CostCategory.transport:     return const Color(0xFF4A90A4);
      case CostCategory.experience:    return const Color(0xFFC9A96E);
      case CostCategory.guide:         return const Color(0xFF5A9E6F);
      case CostCategory.logistics:     return const Color(0xFF8EA67B);
      case CostCategory.flights:       return const Color(0xFF5B8DB8);
      case CostCategory.other:         return const Color(0xFF8A8A8A);
    }
  }
}

extension PaymentStatusDisplay on PaymentStatus {
  String get dbValue => switch (this) {
    PaymentStatus.pending   => 'pending',
    PaymentStatus.due       => 'due',
    PaymentStatus.paid      => 'paid',
    PaymentStatus.cancelled => 'cancelled',
  };

  String get label {
    switch (this) {
      case PaymentStatus.pending:   return 'Pending';
      case PaymentStatus.due:       return 'Due';
      case PaymentStatus.paid:      return 'Paid';
      case PaymentStatus.cancelled: return 'Cancelled';
    }
  }

  Color get bgColor {
    switch (this) {
      case PaymentStatus.pending:   return const Color(0xFFF3F4F6);
      case PaymentStatus.due:       return const Color(0xFFFEF3C7);
      case PaymentStatus.paid:      return const Color(0xFFD1FAE5);
      case PaymentStatus.cancelled: return const Color(0xFFE5E7EB);
    }
  }

  Color get textColor {
    switch (this) {
      case PaymentStatus.pending:   return const Color(0xFF6B7280);
      case PaymentStatus.due:       return const Color(0xFF92400E);
      case PaymentStatus.paid:      return const Color(0xFF065F46);
      case PaymentStatus.cancelled: return const Color(0xFF9CA3AF);
    }
  }
}

extension MarkupTypeLabel on MarkupType {
  String get label {
    switch (this) {
      case MarkupType.percentage: return '% Markup';
      case MarkupType.fixed:      return 'Fixed Markup';
    }
  }
}
