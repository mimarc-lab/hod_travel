import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_model.dart';

/// Full-bleed trip header for the client itinerary view.
/// Conveys the journey at a glance — name, dates, destinations, guests.
class ClientTripHeader extends StatelessWidget {
  final Trip trip;

  const ClientTripHeader({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gold top accent line ─────────────────────────────────────────
          Container(height: 3, color: AppColors.accent),

          // ── Main hero content ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 72 : AppSpacing.pagePaddingH,
              vertical: 48,
            ),
            child: wide
                ? _WideHero(trip: trip)
                : _NarrowHero(trip: trip),
          ),

          // ── Stats strip ──────────────────────────────────────────────────
          _StatsStrip(trip: trip, wide: wide),
        ],
      ),
    );
  }
}

// ── Wide (desktop) hero layout ────────────────────────────────────────────────

class _WideHero extends StatelessWidget {
  final Trip trip;
  const _WideHero({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _HeroText(trip: trip)),
        const SizedBox(width: 48),
        _ContactBlock(trip: trip),
      ],
    );
  }
}

// ── Narrow (mobile) hero layout ───────────────────────────────────────────────

class _NarrowHero extends StatelessWidget {
  final Trip trip;
  const _NarrowHero({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroText(trip: trip),
        const SizedBox(height: 32),
        _ContactBlock(trip: trip),
      ],
    );
  }
}

// ── Shared hero text ──────────────────────────────────────────────────────────

class _HeroText extends StatelessWidget {
  final Trip trip;
  const _HeroText({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateStr = _dateRange(trip);
    final nights  = _nights(trip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        Text(
          'PRIVATE JOURNEY',
          style: AppTextStyles.overline.copyWith(
            color: AppColors.accent,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),

        // Trip name — editorial, generous scale
        Text(
          trip.name,
          style: GoogleFonts.inter(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
            letterSpacing: -1,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 20),

        // Dates + nights
        if (dateStr != null) ...[
          Row(
            children: [
              Text(
                dateStr,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
              ),
              if (nights != null) ...[
                Text('  ·  ',
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted)),
                Text(
                  '$nights nights',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Destinations
        Wrap(
          spacing: 0,
          children: [
            for (int i = 0; i < trip.destinations.length; i++) ...[
              Text(
                trip.destinations[i],
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              if (i < trip.destinations.length - 1)
                Text('  ·  ',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.accentDark)),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Contact / trip lead block ─────────────────────────────────────────────────

class _ContactBlock extends StatelessWidget {
  final Trip trip;
  const _ContactBlock({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('YOUR JOURNEY MANAGER',
            style: AppTextStyles.overline.copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(
          trip.tripLead.name,
          style: AppTextStyles.heading2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          'HOD Travel',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final Trip trip;
  final bool wide;
  const _StatsStrip({required this.trip, required this.wide});

  @override
  Widget build(BuildContext context) {
    final nights = _nights(trip);
    return Container(
      color: AppColors.accentFaint,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 72 : AppSpacing.pagePaddingH,
        vertical: AppSpacing.base,
      ),
      child: Row(
        children: [
          _Stat(value: '${trip.guestCount}', label: 'Guests'),
          _StatDivider(),
          if (nights != null) ...[
            _Stat(value: '$nights', label: 'Nights'),
            _StatDivider(),
          ],
          _Stat(
            value: '${trip.destinations.length}',
            label: trip.destinations.length == 1 ? 'Destination' : 'Destinations',
          ),
          _StatDivider(),
          _Stat(value: trip.status.label, label: 'Status'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppTextStyles.heading3.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 1),
        Text(label, style: AppTextStyles.overline),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(width: 1, height: 28, color: AppColors.border),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _dateRange(Trip trip) {
  if (trip.startDate == null && trip.endDate == null) return null;
  if (trip.startDate != null && trip.endDate != null) {
    return '${DateFormat('d MMMM').format(trip.startDate!)} – '
        '${DateFormat('d MMMM yyyy').format(trip.endDate!)}';
  }
  if (trip.startDate != null) return DateFormat('d MMMM yyyy').format(trip.startDate!);
  return DateFormat('d MMMM yyyy').format(trip.endDate!);
}

int? _nights(Trip trip) {
  if (trip.startDate == null || trip.endDate == null) return null;
  final n = trip.endDate!.difference(trip.startDate!).inDays;
  return n > 0 ? n : null;
}
