import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/supplier_model.dart';
import 'supplier_badges.dart';

/// A single supplier row (desktop) or card (mobile) in the suppliers list.
class SupplierListItem extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SupplierListItem({
    super.key,
    required this.supplier,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Responsive.isMobile(context)
        ? _MobileCard(supplier: supplier, onTap: onTap, onDelete: onDelete)
        : _DesktopRow(supplier: supplier, onTap: onTap, onDelete: onDelete);
  }
}

// ── Desktop row ───────────────────────────────────────────────────────────────

class _DesktopRow extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _DesktopRow({required this.supplier, required this.onTap, this.onDelete});

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
            horizontal: AppSpacing.pagePaddingH,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              // Category icon
              CategoryIconBadge(category: supplier.category),
              const SizedBox(width: AppSpacing.base),

              // Name + city
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${supplier.city}, ${supplier.country}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Category badge
              Expanded(
                flex: 3,
                child: CategoryBadge(category: supplier.category),
              ),

              // Preferred + rating
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (supplier.preferred) ...[
                      const PreferredBadge(),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    RatingDots(rating: supplier.internalRating),
                  ],
                ),
              ),

              // Contact
              Expanded(
                flex: 3,
                child: supplier.contactName != null
                    ? Text(
                        supplier.contactName!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text('—', style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted)),
              ),

              // Last used (placeholder)
              SizedBox(
                width: 80,
                child: Text('—', style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted)),
              ),

              // Delete + chevron
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile card ───────────────────────────────────────────────────────────────

class _MobileCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _MobileCard({required this.supplier, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingHMobile,
        vertical: AppSpacing.xs,
      ),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryIconBadge(category: supplier.category, size: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(supplier.name,
                                style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (supplier.preferred) const PreferredBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          CategoryBadge(category: supplier.category, compact: true),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '${supplier.city}, ${supplier.country}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      RatingDots(rating: supplier.internalRating),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.textMuted),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.textMuted),
                        ),
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
