import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../providers/run_sheet_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Desktop: vertical list panel
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetDayPanel extends StatelessWidget {
  final RunSheetProvider provider;
  const RunSheetDayPanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final days    = provider.days;
    final selected = provider.selectedDay;

    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'DAYS',
              style: AppTextStyles.overline.copyWith(letterSpacing: 1.5),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.base),
              itemCount: days.length,
              itemBuilder: (_, i) => _DayTile(
                day:      days[i],
                selected: days[i].id == selected?.id,
                onTap:    () => provider.selectDay(days[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final TripDay day;
  final bool    selected;
  final VoidCallback onTap;
  const _DayTile({required this.day, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(day.date);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: AppColors.accent.withAlpha(80))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.dayNumber}',
                style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.city.isEmpty ? 'Day ${day.dayNumber}' : day.city,
                    style: AppTextStyles.labelMedium.copyWith(
                      color:      selected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (day.date != null)
                    Text(
                      isToday ? 'Today' : DateFormat('d MMM').format(day.date!),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isToday ? AppColors.accent : AppColors.textMuted,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile: horizontal scrolling chips
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetDayChips extends StatelessWidget {
  final RunSheetProvider provider;
  const RunSheetDayChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final days     = provider.days;
    final selected = provider.selectedDay;

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final day = days[i];
          final sel = day.id == selected?.id;
          return GestureDetector(
            onTap: () => provider.selectDay(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Day ${day.dayNumber}${day.city.isNotEmpty ? ' · ${day.city}' : ''}',
                style: AppTextStyles.labelMedium.copyWith(
                  color:      sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
