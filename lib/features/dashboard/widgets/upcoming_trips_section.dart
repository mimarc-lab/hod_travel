import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';

class UpcomingTripsSection extends StatelessWidget {
  final List<Trip> trips;
  final void Function(Trip trip) onTripTap;

  const UpcomingTripsSection({
    super.key,
    required this.trips,
    required this.onTripTap,
  });

  @override
  Widget build(BuildContext context) {
    final visible = trips.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Upcoming Trips', actionLabel: 'View all'),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          const _EmptyUpcoming()
        else
          ...visible.map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _UpcomingTripCard(
                  trip: trip,
                  onTap: () => onTripTap(trip),
                ),
              )),
      ],
    );
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          'No upcoming trips',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _UpcomingTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const _UpcomingTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yyyy').format(trip.endDate!)}'
        : 'Dates TBD';
    final daysUntil = trip.startDate?.difference(DateTime.now()).inDays ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.surfaceAlt,
            splashColor: AppColors.accentFaint,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPaddingH),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(trip.name, style: AppTextStyles.heading3),
                            const SizedBox(width: AppSpacing.sm),
                            TripStatusChip(status: trip.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(trip.clientName, style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                trip.destinationSummary,
                                style: AppTextStyles.labelSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr, style: AppTextStyles.labelMedium),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text('${trip.guestCount} guests',
                              style: AppTextStyles.labelSmall),
                          const SizedBox(width: AppSpacing.sm),
                          UserAvatar(user: trip.tripLead, size: 22),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: daysUntil <= 30
                              ? AppColors.accentLight
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          daysUntil <= 0
                              ? 'Today'
                              : 'in $daysUntil days',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: daysUntil <= 30
                                ? AppColors.accentDark
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
