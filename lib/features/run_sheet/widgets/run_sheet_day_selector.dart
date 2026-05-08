import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/itinerary_models.dart';
import '../providers/run_sheet_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Desktop: vertical day rail
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetDayPanel extends StatelessWidget {
  final RunSheetProvider provider;
  const RunSheetDayPanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final days     = provider.days;
    final selected = provider.selectedDay;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F1),
        border: Border(
            right: BorderSide(color: AppColors.border.withAlpha(180))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(
              'Days',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, AppSpacing.base),
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
  final TripDay      day;
  final bool         selected;
  final VoidCallback onTap;

  const _DayTile({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(day.date);
    final city    = day.city.isEmpty ? 'Day ${day.dayNumber}' : day.city;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin:  const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:        selected ? AppColors.accentFaint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border:       selected
              ? Border.all(color: AppColors.accent.withAlpha(70), width: 1)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Day number pill
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:       selected ? AppColors.accent : AppColors.surfaceAlt,
                shape:       BoxShape.circle,
                border:      selected
                    ? null
                    : Border.all(color: AppColors.border, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.dayNumber}',
                style: GoogleFonts.inter(
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // City + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city,
                    style: GoogleFonts.inter(
                      fontSize:   13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color:      selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      height:     1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (day.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      isToday ? 'Today' : DateFormat('d MMM').format(day.date!),
                      style: GoogleFonts.inter(
                        fontSize:   11,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        color:      isToday ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Active indicator dot
            if (selected)
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color:  AppColors.accent,
                  shape:  BoxShape.circle,
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
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile: horizontal day carousel
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetDayChips extends StatelessWidget {
  final RunSheetProvider provider;
  const RunSheetDayChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final days     = provider.days;
    final selected = provider.selectedDay;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: 10),
        child: Row(
          children: [
            for (int i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _DayCarouselCard(
                day:      days[i],
                selected: days[i].id == selected?.id,
                onTap:    () => provider.selectDay(days[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayCarouselCard extends StatelessWidget {
  final TripDay      day;
  final bool         selected;
  final VoidCallback onTap;

  const _DayCarouselCard({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(day.date);
    final city    = day.city.isNotEmpty ? day.city : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:        selected ? AppColors.accentFaint : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: selected ? AppColors.accent.withAlpha(90) : AppColors.border,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "Day N" label
            Text(
              isToday ? 'Today' : 'Day ${day.dayNumber}',
              style: GoogleFonts.inter(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      selected ? AppColors.accent : AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
            if (city != null) ...[
              const SizedBox(height: 3),
              Text(
                city,
                style: GoogleFonts.inter(
                  fontSize:   13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color:      selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ] else
              const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
