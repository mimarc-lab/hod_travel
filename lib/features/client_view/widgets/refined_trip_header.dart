import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/trip_model.dart';
import '../client_view_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RefinedTripHeader
//
// Opening section of the client itinerary. Calm, editorial, understated.
// Presents the journey name, dates, destinations, and journey manager.
//
// Replaces the SaaS-style stats strip with a simple gold rule and generous
// whitespace. No numbers-in-boxes. No status badges.
// ─────────────────────────────────────────────────────────────────────────────

class RefinedTripHeader extends StatelessWidget {
  final Trip trip;

  const RefinedTripHeader({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final hPad = wide ? ClientViewTheme.pageHPadWide : ClientViewTheme.pageHPadNarrow;

    return Container(
      color: ClientViewTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top gold accent line — 2px, restrained
          Container(height: 2, color: ClientViewTheme.gold),

          // Hero content
          Padding(
            padding: EdgeInsets.fromLTRB(
                hPad, ClientViewTheme.headerVPad, hPad, 48),
            child: wide
                ? _WideLayout(trip: trip)
                : _NarrowLayout(trip: trip),
          ),

          // Bottom separator — thin hairline, no stat boxes
          Container(
            margin: EdgeInsets.symmetric(horizontal: hPad),
            height: 1,
            color: ClientViewTheme.hairline,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Wide layout ───────────────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final Trip trip;
  const _WideLayout({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _HeroText(trip: trip)),
        const SizedBox(width: 56),
        _JourneyManager(trip: trip),
      ],
    );
  }
}

// ── Narrow layout ─────────────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final Trip trip;
  const _NarrowLayout({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroText(trip: trip),
        const SizedBox(height: 36),
        _JourneyManager(trip: trip),
      ],
    );
  }
}

// ── Hero text ─────────────────────────────────────────────────────────────────

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
        Text('PRIVATE JOURNEY', style: ClientViewTheme.eyebrow),
        const SizedBox(height: 14),

        // Trip name
        Text(trip.name, style: ClientViewTheme.tripName),
        const SizedBox(height: 22),

        // Dates + nights
        if (dateStr != null) ...[
          Row(
            children: [
              Text(dateStr, style: ClientViewTheme.tripDates),
              if (nights != null) ...[
                Text(
                  '  ·  $nights nights',
                  style: ClientViewTheme.tripDates.copyWith(
                      color: ClientViewTheme.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Destinations — dot-separated, no chips
        if (trip.destinations.isNotEmpty)
          Text(
            trip.destinations.join('  ·  '),
            style: ClientViewTheme.tripMeta,
          ),
      ],
    );
  }
}

// ── Journey manager block ─────────────────────────────────────────────────────

class _JourneyManager extends StatelessWidget {
  final Trip trip;
  const _JourneyManager({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('YOUR JOURNEY MANAGER', style: ClientViewTheme.managerLabel),
        const SizedBox(height: 8),
        Text(trip.tripLead.name, style: ClientViewTheme.managerName),
        const SizedBox(height: 3),
        Text('HOD Travel', style: ClientViewTheme.managerSub),
      ],
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
  if (trip.startDate != null) {
    return DateFormat('d MMMM yyyy').format(trip.startDate!);
  }
  return DateFormat('d MMMM yyyy').format(trip.endDate!);
}

int? _nights(Trip trip) {
  if (trip.startDate == null || trip.endDate == null) return null;
  final n = trip.endDate!.difference(trip.startDate!).inDays;
  return n > 0 ? n : null;
}
