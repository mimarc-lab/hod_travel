import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_component_model.dart';
import '../providers/components_provider.dart';

class ComponentFilterBar extends StatelessWidget {
  final ComponentsProvider provider;

  const ComponentFilterBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final selectedType   = provider.filterType;
        final selectedStatus = provider.filterStatus;
        final counts         = provider.countsByType;

        return Container(
          color: AppColors.background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH, 10, AppSpacing.pagePaddingH, 10),
                child: Row(
                  children: [
                    // All chip
                    _Chip(
                      label: 'All',
                      count: provider.allComponents.length,
                      selected: selectedType == null && selectedStatus == null,
                      onTap: () {
                        provider.setFilterType(null);
                        provider.setFilterStatus(null);
                      },
                    ),
                    const SizedBox(width: 6),

                    // Type chips — only shown when count > 0
                    ...ComponentType.values.map((type) {
                      final count = counts[type] ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TypeChip(
                          type:     type,
                          count:    count,
                          selected: selectedType == type,
                          onTap: () => provider.setFilterType(
                            selectedType == type ? null : type,
                          ),
                        ),
                      );
                    }),

                    // Status filter — hidden on mobile (shown in toolbar)
                    if (!Responsive.isMobile(context)) ...[
                      _BarDivider(),
                      _StatusChip(
                        selected: selectedStatus,
                        onSelected: provider.setFilterStatus,
                      ),
                    ],

                    // Clear
                    if (selectedType != null || selectedStatus != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      GestureDetector(
                        onTap: () {
                          provider.setFilterType(null);
                          provider.setFilterStatus(null);
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
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
        width: 1,
        height: 18,
        color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
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
          color: selected
              ? AppColors.accent.withAlpha(20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accent.withAlpha(120)
                : AppColors.border,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? AppColors.accent
                    : AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.accent
                    : AppColors.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final ComponentType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? type.color : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? type.color.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? type.color.withAlpha(120)
                : AppColors.border,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              type.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
                height: 1.3,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ComponentStatus? selected;
  final ValueChanged<ComponentStatus?> onSelected;

  const _StatusChip({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final color = selected?.color ?? AppColors.textSecondary;
    return PopupMenuButton<ComponentStatus?>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem<ComponentStatus?>(
          value: null,
          child: Text(
            'All statuses',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        const PopupMenuDivider(),
        ...ComponentStatus.values.map(
          (s) => PopupMenuItem<ComponentStatus?>(
            value: s,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected != null
              ? selected!.color.withAlpha(20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected != null
                ? selected!.color.withAlpha(120)
                : AppColors.border,
            width: selected != null ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected?.color ?? AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selected?.label ?? 'Status',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight:
                    selected != null ? FontWeight.w600 : FontWeight.w400,
                color: color,
                height: 1.3,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
