import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';

/// A single trip row in the trips list table.
class TripRow extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  /// When provided, an action menu (⋯) is shown at the end of the row.
  final VoidCallback? onEdit;

  const TripRow({
    super.key,
    required this.trip,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final trip = this.trip;
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yy').format(trip.endDate!)}'
        : 'Dates TBD';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceAlt,
        splashColor: AppColors.accentFaint,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPaddingH,
            vertical: 13,
          ),
          child: Row(
            children: [
              // Trip name + client
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(trip.clientName, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // Dates
              Expanded(
                flex: 2,
                child: Text(dateStr, style: AppTextStyles.bodySmall),
              ),
              // Destinations
              Expanded(
                flex: 3,
                child: Text(trip.destinationSummary, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
              ),
              // Trip lead
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    UserAvatar(user: trip.tripLead, size: 22),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        trip.tripLead.name.split(' ').first,
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: TripStatusChip(status: trip.status),
              ),
              // Guests
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('${trip.guestCount}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // Action menu + arrow
              if (onEdit != null)
                _TripRowMenu(onEdit: onEdit!),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Column header row for the trips table.
class TripTableHeader extends StatelessWidget {
  const TripTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPaddingH,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TRIP', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('DATES', style: AppTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('DESTINATIONS', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('LEAD', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('STATUS', style: AppTextStyles.tableHeader)),
          Expanded(flex: 1, child: Text('GUESTS', style: AppTextStyles.tableHeader)),
          // Space for action menu + chevron
          const SizedBox(width: 50),
        ],
      ),
    );
  }
}

// ── Action menu ───────────────────────────────────────────────────────────────

class _TripRowMenu extends StatelessWidget {
  final VoidCallback onEdit;
  const _TripRowMenu({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit();
      },
      tooltip: 'Trip options',
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit Trip'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border, width: 0.75),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
