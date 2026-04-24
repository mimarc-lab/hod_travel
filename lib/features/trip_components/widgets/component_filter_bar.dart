import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
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
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingH,
            vertical:   AppSpacing.sm,
          ),
          child: Row(
            children: [
              // All chip
              _FilterChip(
                label: 'All',
                count: provider.allComponents.length,
                selected: selectedType == null && selectedStatus == null,
                onTap: () {
                  provider.setFilterType(null);
                  provider.setFilterStatus(null);
                },
              ),
              const SizedBox(width: AppSpacing.xs),

              // Type filter chips
              ...ComponentType.values.map((type) {
                final count = counts[type] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: _TypeFilterChip(
                    type:     type,
                    count:    count,
                    selected: selectedType == type,
                    onTap: () => provider.setFilterType(
                      selectedType == type ? null : type,
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Status filter dropdown
              _StatusFilterButton(
                selected: selectedStatus,
                onSelected: provider.setFilterStatus,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withAlpha(50)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final ComponentType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TypeFilterChip({
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
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? type.bgColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: selected ? type.color.withAlpha(80) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              type.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  final ComponentStatus? selected;
  final ValueChanged<ComponentStatus?> onSelected;

  const _StatusFilterButton({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ComponentStatus?>(
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem<ComponentStatus?>(
          value: null,
          child: Text('All statuses', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
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
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(s.label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected != null ? selected!.bgColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: selected != null ? selected!.color.withAlpha(80) : AppColors.border,
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
              style: AppTextStyles.labelMedium.copyWith(
                color: selected?.color ?? AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                color: selected?.color ?? AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
