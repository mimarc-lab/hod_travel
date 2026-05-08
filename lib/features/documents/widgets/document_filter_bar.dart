import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/trip_document.dart';
import '../providers/documents_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DocumentFilterBar — horizontally scrollable status + type filter chips.
// ─────────────────────────────────────────────────────────────────────────────

class DocumentFilterBar extends StatelessWidget {
  final DocumentsProvider provider;
  const DocumentFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final hasFilter =
            provider.filterType != null || provider.filterStatus != null;

        return Container(
          color: AppColors.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH, 10,
                    AppSpacing.pagePaddingH, 10),
                child: Row(
                  children: [
                    // All / Clear
                    _Chip(
                      label:      'All',
                      isSelected: !hasFilter,
                      color:      AppColors.accent,
                      onTap:      provider.clearFilters,
                    ),
                    const SizedBox(width: 6),

                    // Status chips (exclude archived — operational statuses only)
                    ...DocumentStatus.values
                        .where((s) => s != DocumentStatus.archived)
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _Chip(
                                label:      s.label,
                                isSelected: provider.filterStatus == s,
                                color:      s.color,
                                onTap: () => provider.setFilterStatus(
                                  provider.filterStatus == s ? null : s,
                                ),
                              ),
                            )),

                    _BarDivider(),

                    // Type chips
                    ...DocumentType.values.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _Chip(
                            label:      t.label,
                            isSelected: provider.filterType == t,
                            color:      t.color,
                            onTap: () => provider.setFilterType(
                              provider.filterType == t ? null : t,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
            ],
          ),
        );
      },
    );
  }
}

class _BarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width:  1,
        height: 18,
        color:  AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool   isSelected;
  final Color  color;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withAlpha(120) : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize:   12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color:      isSelected ? color : AppColors.textSecondary,
            height:     1.3,
          ),
        ),
      ),
    );
  }
}
