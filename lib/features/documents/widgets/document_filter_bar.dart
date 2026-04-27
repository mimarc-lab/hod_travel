import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_document.dart';
import '../providers/documents_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DocumentFilterBar — search box + type/status filter chips.
// ─────────────────────────────────────────────────────────────────────────────

class DocumentFilterBar extends StatefulWidget {
  final DocumentsProvider provider;
  const DocumentFilterBar({super.key, required this.provider});

  @override
  State<DocumentFilterBar> createState() => _DocumentFilterBarState();
}

class _DocumentFilterBarState extends State<DocumentFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        return Container(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePaddingH, AppSpacing.sm,
                  AppSpacing.pagePaddingH, AppSpacing.xs,
                ),
                child: TextFormField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText:      'Search documents…',
                    hintStyle:     AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                    prefixIcon:    const Icon(Icons.search_rounded,
                        size: 16, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 14, color: AppColors.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              widget.provider.setSearchQuery('');
                            },
                          )
                        : null,
                    filled:       true,
                    fillColor:    AppColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical:   10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide:   const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide:   const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide:   const BorderSide(color: AppColors.accent),
                    ),
                  ),
                  style: AppTextStyles.bodyMedium,
                  onChanged: (v) {
                    setState(() {});
                    widget.provider.setSearchQuery(v);
                  },
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePaddingH, 4,
                  AppSpacing.pagePaddingH, AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Clear all
                    if (widget.provider.filterType != null ||
                        widget.provider.filterStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: GestureDetector(
                          onTap: widget.provider.clearFilters,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:        AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border:       Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.close_rounded,
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text('Clear',
                                    style: AppTextStyles.labelSmall),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Status filters
                    ...DocumentStatus.values
                        .where((s) => s != DocumentStatus.archived)
                        .map((s) => _FilterChip(
                              label:       s.label,
                              isSelected:  widget.provider.filterStatus == s,
                              color:       s.color,
                              onTap:       () => widget.provider.setFilterStatus(
                                widget.provider.filterStatus == s ? null : s,
                              ),
                            )),

                    const SizedBox(width: AppSpacing.xs),
                    Container(width: 1, height: 16, color: AppColors.border),
                    const SizedBox(width: AppSpacing.xs),

                    // Type filters
                    ...DocumentType.values.map((t) => _FilterChip(
                          label:      t.label,
                          isSelected: widget.provider.filterType == t,
                          color:      t.color,
                          onTap:      () => widget.provider.setFilterType(
                            widget.provider.filterType == t ? null : t,
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String     label;
  final bool       isSelected;
  final Color      color;
  final VoidCallback onTap;
  const _FilterChip({
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
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        isSelected ? color.withAlpha(20) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withAlpha(120) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:      isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
