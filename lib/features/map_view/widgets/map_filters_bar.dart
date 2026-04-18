import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MapFiltersBar
// ─────────────────────────────────────────────────────────────────────────────

/// A horizontally-scrollable bar of type-filter chips and a route toggle.
///
/// Designed to float over the top of the map surface. Uses a frosted-glass
/// style card so the underlying tiles remain visible.
class MapFiltersBar extends StatelessWidget {
  final ItemType? selectedType;
  final bool showRoute;
  final ValueChanged<ItemType?> onTypeChanged;
  final ValueChanged<bool> onRouteToggled;

  const MapFiltersBar({
    super.key,
    required this.selectedType,
    required this.showRoute,
    required this.onTypeChanged,
    required this.onRouteToggled,
  });

  static const _filters = <(ItemType?, String, IconData)>[
    (null,                   'All',        Icons.apps_rounded),
    (ItemType.hotel,         'Hotels',     Icons.hotel_rounded),
    (ItemType.experience,    'Experience', Icons.star_border_rounded),
    (ItemType.dining,        'Dining',     Icons.restaurant_outlined),
    (ItemType.transport,     'Transport',  Icons.directions_car_outlined),
    (ItemType.flight,        'Flights',    Icons.flight_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(236),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Type chips ───────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _filters
                  .map((f) => _TypeChip(
                        label:    f.$2,
                        icon:     f.$3,
                        selected: selectedType == f.$1,
                        color:    f.$1?.color,
                        onTap:    () => onTypeChanged(f.$1),
                      ))
                  .toList(),
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Container(width: 0.75, height: 24, color: AppColors.border),
          const SizedBox(width: 2),

          // ── Route toggle ─────────────────────────────────────────────────
          _RouteToggle(
            active: showRoute,
            onTap:  () => onRouteToggled(!showRoute),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── _TypeChip ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final Color?   color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          color:        selected ? activeColor.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:  selected ? activeColor.withAlpha(80) : Colors.transparent,
            width:  0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:  13,
              color: selected ? activeColor : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color:      selected ? activeColor : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize:   11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _RouteToggle ─────────────────────────────────────────────────────────────

class _RouteToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _RouteToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color:        active
              ? AppColors.accent.withAlpha(22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:  active ? AppColors.accent.withAlpha(80) : Colors.transparent,
            width:  0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_outlined,
              size:  13,
              color: active ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              'Route',
              style: AppTextStyles.labelSmall.copyWith(
                color:      active ? AppColors.accent : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize:   11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
