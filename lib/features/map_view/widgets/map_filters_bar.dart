import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MapFiltersBar
// ─────────────────────────────────────────────────────────────────────────────

/// A compact dropdown filter button + route toggle that floats over the map.
///
/// Tapping the filter button opens a dropdown list of type options.
/// Selecting any option applies it and closes the dropdown automatically.
class MapFiltersBar extends StatefulWidget {
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

  @override
  State<MapFiltersBar> createState() => _MapFiltersBarState();
}

class _MapFiltersBarState extends State<MapFiltersBar> {
  bool _open = false;

  static const _filters = <(ItemType?, String, IconData)>[
    (null,                'All',        Icons.apps_rounded),
    (ItemType.hotel,      'Hotels',     Icons.hotel_rounded),
    (ItemType.experience, 'Experience', Icons.star_border_rounded),
    (ItemType.dining,     'Dining',     Icons.restaurant_outlined),
    (ItemType.transport,  'Transport',  Icons.directions_car_outlined),
    (ItemType.flight,     'Flights',    Icons.flight_rounded),
  ];

  static BoxDecoration get _cardDecoration => BoxDecoration(
        color:        AppColors.surface.withAlpha(248),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:        Colors.black.withAlpha(12),
            blurRadius:   20,
            spreadRadius: 0,
            offset:       const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.borderSubtle, width: 0.75),
      );

  @override
  Widget build(BuildContext context) {
    final current = _filters.firstWhere(
      (f) => f.$1 == widget.selectedType,
      orElse: () => _filters.first,
    );
    final activeColor = current.$1?.color ?? AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Button bar ───────────────────────────────────────────────────────
        Container(
          decoration: _cardDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filter selector
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(current.$3, size: 13, color: activeColor),
                        const SizedBox(width: 6),
                        Text(
                          current.$2,
                          style: AppTextStyles.labelSmall.copyWith(
                            color:      activeColor,
                            fontWeight: FontWeight.w600,
                            fontSize:   12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _open ? Icons.expand_less : Icons.expand_more,
                          size:  15,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Divider
              Container(width: 0.75, height: 24, color: AppColors.border),

              // Route toggle
              _RouteToggle(
                active: widget.showRoute,
                onTap:  () => widget.onRouteToggled(!widget.showRoute),
              ),
            ],
          ),
        ),

        // ── Dropdown ─────────────────────────────────────────────────────────
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            width: 180,
            decoration: _cardDecoration,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: _filters.map((f) {
                final isSelected = widget.selectedType == f.$1;
                final fColor     = f.$1?.color ?? AppColors.accent;

                return GestureDetector(
                  onTap: () {
                    widget.onTypeChanged(f.$1);
                    setState(() => _open = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 110),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? fColor.withAlpha(18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          f.$3,
                          size:  13,
                          color: isSelected ? fColor : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.$2,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isSelected
                                  ? fColor
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, size: 12, color: fColor),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
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
        margin:  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withAlpha(22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent.withAlpha(80) : Colors.transparent,
            width: 0.75,
          ),
        ),
        child: SizedBox(
          height: 32,
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
      ),
    );
  }
}
