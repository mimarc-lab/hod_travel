import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../services/map_view_mapper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DayNavigatorPanel
// ─────────────────────────────────────────────────────────────────────────────

/// Vertical left-side panel listing trip days and their mapped items.
///
/// Desktop: 260 px wide, full-height, scrollable.
/// Tablet:  220 px wide.
///
/// Tapping a day row filters the map to that day.
/// Tapping an item row focuses the corresponding pin and shows its detail card.
/// Tapping the active day again clears the filter (shows all).
class DayNavigatorPanel extends StatelessWidget {
  final List<TripDay> days;
  final Map<String, List<ItineraryItem>> itemsByDayId;
  final List<TripMapMarker> allMarkers;
  final String? selectedDayId;
  final String? focusedItemId;
  final ValueChanged<String?> onDayTap;    // null = clear filter
  final ValueChanged<String>  onItemTap;   // item.id

  const DayNavigatorPanel({
    super.key,
    required this.days,
    required this.itemsByDayId,
    required this.allMarkers,
    required this.selectedDayId,
    required this.focusedItemId,
    required this.onDayTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build a set of item IDs that are actually on the map
    final mappedIds = {for (final m in allMarkers) m.item.id};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(dayCount: days.length),

          // ── "All Days" row ────────────────────────────────────────────────
          _AllDaysRow(
            selected: selectedDayId == null,
            onTap:    () => onDayTap(null),
          ),

          Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── Day list ─────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day   = days[i];
                final items = (itemsByDayId[day.id] ?? const [])
                    .where((it) => it.type != ItemType.note)
                    .toList()
                  ..sort((a, b) {
                    final at = a.startTime;
                    final bt = b.startTime;
                    if (at == null && bt == null) return 0;
                    if (at == null) return 1;
                    if (bt == null) return -1;
                    final am = at.hour * 60 + at.minute;
                    final bm = bt.hour * 60 + bt.minute;
                    return am.compareTo(bm);
                  });
                final isSelected = selectedDayId == day.id;

                return _DayRow(
                  day:          day,
                  items:        items,
                  mappedIds:    mappedIds,
                  isSelected:   isSelected,
                  focusedItemId: focusedItemId,
                  onDayTap:  () => onDayTap(isSelected ? null : day.id),
                  onItemTap: onItemTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PanelHeader ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final int dayCount;
  const _PanelHeader({required this.dayCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            'DAYS',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.accent,
              letterSpacing: 1.2,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$dayCount',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _AllDaysRow ──────────────────────────────────────────────────────────────

class _AllDaysRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _AllDaysRow({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: selected ? AppColors.accentFaint : Colors.transparent,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              Icons.map_outlined,
              size: 14,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              'All Days',
              style: AppTextStyles.bodySmall.copyWith(
                color:      selected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize:   13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DayRow ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final TripDay   day;
  final List<ItineraryItem> items;
  final Set<String> mappedIds;
  final bool      isSelected;
  final String?   focusedItemId;
  final VoidCallback        onDayTap;
  final ValueChanged<String> onItemTap;

  const _DayRow({
    required this.day,
    required this.items,
    required this.mappedIds,
    required this.isSelected,
    required this.focusedItemId,
    required this.onDayTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Day header ───────────────────────────────────────────────────
        GestureDetector(
          onTap: onDayTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            color: isSelected ? AppColors.accentFaint : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Day number badge
                Container(
                  width:  30,
                  height: 18,
                  decoration: BoxDecoration(
                    color:        isSelected ? AppColors.accent : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.dayNumber}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize:   10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // City + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.city.isNotEmpty ? day.city : 'Day ${day.dayNumber}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color:      isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize:   12,
                        ),
                        maxLines:  1,
                        overflow:  TextOverflow.ellipsis,
                      ),
                      if (day.date != null)
                        Text(
                          DateFormat('d MMM').format(day.date!),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10,
                            color:    AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Item count on map
                if (items.isNotEmpty)
                  Text(
                    '${items.where((it) => mappedIds.contains(it.id)).length}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color:   AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Item list (shown when day is selected) ────────────────────────
        if (isSelected)
          for (final item in items)
            _ItemRow(
              item:     item,
              isMapped: mappedIds.contains(item.id),
              focused:  focusedItemId == item.id,
              onTap:    mappedIds.contains(item.id)
                  ? () => onItemTap(item.id)
                  : null,
            ),

        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.divider,
          indent: 16,
        ),
      ],
    );
  }
}

// ── _ItemRow ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final ItineraryItem item;
  final bool          isMapped;
  final bool          focused;
  final VoidCallback? onTap;

  const _ItemRow({
    required this.item,
    required this.isMapped,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = item.type.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: focused
            ? typeColor.withAlpha(18)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: focused ? typeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                Icon(
                  item.type.icon,
                  size:  12,
                  color: isMapped ? typeColor : AppColors.textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTextStyles.labelSmall.copyWith(
                      color:      isMapped
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: focused ? FontWeight.w600 : FontWeight.w400,
                      fontSize:   12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isMapped)
                  Icon(
                    Icons.location_off_outlined,
                    size:  11,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
