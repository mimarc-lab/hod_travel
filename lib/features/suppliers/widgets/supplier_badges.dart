import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CategoryBadge — coloured pill showing supplier category
// ─────────────────────────────────────────────────────────────────────────────

class CategoryBadge extends StatelessWidget {
  final SupplierCategory category;
  final bool compact; // compact = icon only with tiny label below

  const CategoryBadge({super.key, required this.category, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: compact ? 11 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CategoryIconBadge — square icon tile for use in list items
// ─────────────────────────────────────────────────────────────────────────────

class CategoryIconBadge extends StatelessWidget {
  final SupplierCategory category;
  final double size;

  const CategoryIconBadge({super.key, required this.category, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(category.icon, size: size * 0.44, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PreferredBadge — gold star chip
// ─────────────────────────────────────────────────────────────────────────────

class PreferredBadge extends StatelessWidget {
  const PreferredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(22),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: AppColors.accent),
          const SizedBox(width: 3),
          Text(
            'Preferred',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RatingDots — compact 1–5 rating display using filled/outline stars
// ─────────────────────────────────────────────────────────────────────────────

class RatingDots extends StatelessWidget {
  final double rating; // 1–5
  final double size;
  final Color? color;

  const RatingDots({
    super.key,
    required this.rating,
    this.size = 11,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    final r = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < r ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < r ? c : AppColors.textMuted,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RatingPicker — interactive 1–5 star selector used in the editor
// ─────────────────────────────────────────────────────────────────────────────

class RatingPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const RatingPicker({super.key, required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: filled ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        );
      }),
    );
  }
}
