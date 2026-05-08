import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../services/map_view_mapper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DayNavigatorPanel — Journey Timeline Rail
// ─────────────────────────────────────────────────────────────────────────────

/// Vertical panel listing trip days as a luxury journey timeline.
///
/// Desktop: 280 px wide, full-height, scrollable.
/// Mobile:  embedded in the expandable bottom sheet (showBorder: false,
///          showHeader: false so the panel-level handle shows instead).
class DayNavigatorPanel extends StatelessWidget {
  final List<TripDay> days;
  final Map<String, List<ItineraryItem>> itemsByDayId;
  final List<TripMapMarker> allMarkers;
  final String? selectedDayId;
  final String? focusedItemId;
  final ValueChanged<String?> onDayTap;
  final ValueChanged<String>  onItemTap;
  final bool showBorder;
  final bool showHeader;

  const DayNavigatorPanel({
    super.key,
    required this.days,
    required this.itemsByDayId,
    required this.allMarkers,
    required this.selectedDayId,
    required this.focusedItemId,
    required this.onDayTap,
    required this.onItemTap,
    this.showBorder = true,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final mappedIds = {for (final m in allMarkers) m.item.id};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: showBorder
            ? const Border(right: BorderSide(color: AppColors.border, width: 1))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) _PanelHeader(dayCount: days.length),

          _AllDaysRow(
            selected: selectedDayId == null,
            onTap:    () => onDayTap(null),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.border),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                final allItems = (itemsByDayId[day.id] ?? const [])
                    .where((it) => it.type != ItemType.note)
                    .toList()
                  ..sort((a, b) {
                    final at = a.startTime;
                    final bt = b.startTime;
                    if (at == null && bt == null) return 0;
                    if (at == null) return 1;
                    if (bt == null) return -1;
                    return (at.hour * 60 + at.minute)
                        .compareTo(bt.hour * 60 + bt.minute);
                  });
                final isSelected = selectedDayId == day.id;

                return _DayCard(
                  day:           day,
                  items:         allItems,
                  mappedIds:     mappedIds,
                  isSelected:    isSelected,
                  isFirst:       i == 0,
                  isLast:        i == days.length - 1,
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.route_outlined, size: 13, color: AppColors.accent),
          const SizedBox(width: 7),
          Text(
            'JOURNEY',
            style: AppTextStyles.overline.copyWith(
              color:       AppColors.accentDark,
              letterSpacing: 1.4,
              fontSize:    10,
              fontWeight:  FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:        AppColors.accentFaint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentLight, width: 0.75),
            ),
            child: Text(
              '$dayCount days',
              style: AppTextStyles.labelSmall.copyWith(
                color:      AppColors.accentDark,
                fontSize:   10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _AllDaysRow ───────────────────────────────────────────────────────────────

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
              Icons.language_outlined,
              size:  13,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              'All Days',
              style: AppTextStyles.bodySmall.copyWith(
                color:      selected ? AppColors.accentDark : AppColors.textSecondary,
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

// ── _DayCard ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final TripDay day;
  final List<ItineraryItem> items;
  final Set<String>  mappedIds;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final String? focusedItemId;
  final VoidCallback onDayTap;
  final ValueChanged<String> onItemTap;

  const _DayCard({
    required this.day,
    required this.items,
    required this.mappedIds,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.focusedItemId,
    required this.onDayTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final mappedCount = items.where((it) => mappedIds.contains(it.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Day header ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: onDayTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: isSelected ? AppColors.accentFaint : Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline rail
                  _TimelineStrip(
                    isFirst:  isFirst,
                    isLast:   isLast,
                    isActive: isSelected,
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // DAY badge + date
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'DAY ${day.dayNumber}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize:   9,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              if (day.date != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('d MMM').format(day.date!),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                    color:    AppColors.textMuted,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (mappedCount > 0)
                                Text(
                                  '$mappedCount',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color:   AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // City name
                          Text(
                            day.city.isNotEmpty
                                ? day.city
                                : 'Day ${day.dayNumber}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Item list (when day is selected) ────────────────────────────────
        if (isSelected)
          for (final item in items)
            _ItemRow(
              item:     item,
              isMapped: mappedIds.contains(item.id),
              focused:  focusedItemId == item.id,
              onTap: mappedIds.contains(item.id)
                  ? () => onItemTap(item.id)
                  : null,
            ),

        if (!isLast)
          Divider(
            height:    1,
            thickness: 1,
            color:     AppColors.divider,
            indent:    36,
          ),
      ],
    );
  }
}

// ── _TimelineStrip ────────────────────────────────────────────────────────────

/// 36-px wide strip rendering the vertical timeline connector + day dot.
class _TimelineStrip extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool isActive;

  const _TimelineStrip({
    required this.isFirst,
    required this.isLast,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: CustomPaint(
        painter: _TimelinePainter(
          isFirst:  isFirst,
          isLast:   isLast,
          isActive: isActive,
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final bool isActive;

  const _TimelinePainter({
    required this.isFirst,
    required this.isLast,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const dotR    = 4.5;
    const activeR = 6.0;
    final r = isActive ? activeR : dotR;

    final linePaint = Paint()
      ..color       = AppColors.accentLight
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    if (!isFirst) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy - r - 1), linePaint);
    }
    if (!isLast) {
      canvas.drawLine(Offset(cx, cy + r + 1), Offset(cx, size.height), linePaint);
    }

    if (isActive) {
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.accent);
      canvas.drawCircle(
          Offset(cx, cy), r / 2.8, Paint()..color = Colors.white);
    } else {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color       = AppColors.border
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.isFirst  != isFirst  ||
      old.isLast   != isLast   ||
      old.isActive != isActive;
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
    final typeColor = item.effectiveColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: focused ? typeColor.withAlpha(16) : Colors.transparent,
        child: Row(
          children: [
            const SizedBox(width: 36), // align with content column
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: focused ? typeColor : typeColor.withAlpha(40),
                      width: focused ? 2.0 : 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.effectiveIcon,
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
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
