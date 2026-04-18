import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/cost_item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaymentStatusChip
// ─────────────────────────────────────────────────────────────────────────────

class PaymentStatusChip extends StatelessWidget {
  final PaymentStatus status;
  const PaymentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: status.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CostCategoryBadge
// ─────────────────────────────────────────────────────────────────────────────

class CostCategoryBadge extends StatelessWidget {
  final CostCategory category;
  final bool iconOnly;
  const CostCategoryBadge({super.key, required this.category, this.iconOnly = false});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: iconOnly ? 7 : 8,
        vertical: iconOnly ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 11, color: color),
          if (!iconOnly) ...[
            const SizedBox(width: 4),
            Text(
              category.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CostCategoryIconTile — square icon for list items
// ─────────────────────────────────────────────────────────────────────────────

class CostCategoryIconTile extends StatelessWidget {
  final CostCategory category;
  final double size;
  const CostCategoryIconTile({super.key, required this.category, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(category.icon, size: size * 0.44, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CurrencyAmount — formatted amount with currency code
// ─────────────────────────────────────────────────────────────────────────────

class CurrencyAmount extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? style;
  final bool compact;

  const CurrencyAmount({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.compact = false,
  });

  String _format(double v) {
    if (compact && v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k';
    }
    // Comma-separated, 0 decimal places for whole numbers
    final rounded = v.round();
    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary);
    return Text(
      '$currency ${_format(amount)}',
      style: baseStyle,
    );
  }
}
