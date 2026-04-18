import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DuplicateWarningPanel — shown when DuplicateDetectionService finds possible
// duplicate suppliers before a new record is created.
//
// Matching logic lives in DuplicateDetectionService (business layer).
// This widget is display-only.
//
// The user can:
//   • Enrich an existing matched supplier (→ caller opens merge sheet)
//   • Create a new supplier anyway      (→ dismisses panel)
// ─────────────────────────────────────────────────────────────────────────────

class DuplicateWarningPanel extends StatelessWidget {
  final List<Supplier> matches;
  final void Function(Supplier) onEnrichExisting;
  final VoidCallback onCreateAnyway;

  const DuplicateWarningPanel({
    super.key,
    required this.matches,
    required this.onEnrichExisting,
    required this.onCreateAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 15, color: Color(0xFF92400E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    matches.length == 1
                        ? 'Possible duplicate found'
                        : '${matches.length} possible duplicates found',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Match rows (show at most 3)
          ...matches.take(3).map((s) => _MatchRow(
                supplier: s,
                onEnrich: () => onEnrichExisting(s),
              )),

          // Footer — create anyway
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.sm),
            child: GestureDetector(
              onTap: onCreateAnyway,
              child: Text(
                'Create new supplier anyway →',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEnrich;

  const _MatchRow({required this.supplier, required this.onEnrich});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: supplier.category.color.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(supplier.category.icon,
                size: 13, color: supplier.category.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (supplier.city.isNotEmpty || supplier.country.isNotEmpty)
                  Text(
                    [supplier.city, supplier.country]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style: AppTextStyles.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onEnrich,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Enrich Existing',
                style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
