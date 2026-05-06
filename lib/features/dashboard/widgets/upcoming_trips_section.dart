import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/user_avatar.dart';

// Premium gradient palette — travel-inspired, editorial feel
const _kTripGradients = [
  [Color(0xFF1C2B4A), Color(0xFF2D4A7A)],   // Mediterranean blue
  [Color(0xFF1A3A2A), Color(0xFF2D5A3D)],   // Rainforest green
  [Color(0xFF3A1A1A), Color(0xFF6B2A2A)],   // Desert dusk
  [Color(0xFF2A1A3A), Color(0xFF4C2D6B)],   // Violet twilight
  [Color(0xFF1A2A3A), Color(0xFF2A4A6B)],   // Nordic fjord
  [Color(0xFF3A2A1A), Color(0xFF6B4C2A)],   // Sahara amber
];

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
        const SizedBox(height: AppSpacing.base),
        if (visible.isEmpty)
          const _EmptyUpcoming()
        else
          ...visible.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _EditorialTripCard(
                  trip: e.value,
                  gradientIndex: e.key % _kTripGradients.length,
                  onTap: () => onTripTap(e.value),
                ),
              )),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_takeoff_rounded,
                size: 24, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No upcoming trips',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editorial trip card ───────────────────────────────────────────────────────

class _EditorialTripCard extends StatefulWidget {
  final Trip trip;
  final int gradientIndex;
  final VoidCallback onTap;

  const _EditorialTripCard({
    required this.trip,
    required this.gradientIndex,
    required this.onTap,
  });

  @override
  State<_EditorialTripCard> createState() => _EditorialTripCardState();
}

class _EditorialTripCardState extends State<_EditorialTripCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final trip     = widget.trip;
    final gradient = _kTripGradients[widget.gradientIndex];

    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yyyy').format(trip.endDate!)}'
        : 'Dates TBD';
    final daysUntil = trip.startDate?.difference(DateTime.now()).inDays ?? 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Color(_hovered ? 0x14000000 : 0x07000000),
                blurRadius: _hovered ? 20 : 6,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
              BoxShadow(
                color: Color(_hovered ? 0x06000000 : 0x00000000),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Gradient hero area ─────────────────────────────────
                _GradientHero(
                  trip: trip,
                  gradient: gradient,
                  dateStr: dateStr,
                  daysUntil: daysUntil,
                ),
                // ── Card body ──────────────────────────────────────────
                _CardBody(trip: trip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient hero area ────────────────────────────────────────────────────────

class _GradientHero extends StatelessWidget {
  final Trip trip;
  final List<Color> gradient;
  final String dateStr;
  final int daysUntil;

  const _GradientHero({
    required this.trip,
    required this.gradient,
    required this.dateStr,
    required this.daysUntil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Destination pill
                if (trip.destinationSummary.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10, color: Colors.white70),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            trip.destinationSummary,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Days until badge
          if (trip.startDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Text(
                daysUntil <= 0
                    ? 'Today'
                    : daysUntil == 1
                        ? 'Tomorrow'
                        : 'in $daysUntil days',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card body ────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final Trip trip;
  const _CardBody({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yyyy').format(trip.endDate!)}'
        : 'Dates TBD';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip name + status chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  trip.name,
                  style: AppTextStyles.heading3.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TripStatusChip(status: trip.status),
            ],
          ),
          const SizedBox(height: 6),
          // Meta row: client · date · guests
          Row(
            children: [
              Text(
                trip.clientName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              _dot(),
              Text(
                dateStr,
                style: AppTextStyles.labelMedium,
              ),
              _dot(),
              const Icon(Icons.people_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(
                '${trip.guestCount}',
                style: AppTextStyles.labelMedium,
              ),
              const Spacer(),
              // Trip lead avatar
              UserAvatar(user: trip.tripLead, size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
