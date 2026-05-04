import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/client_media_item.dart';
import '../../../data/models/trip_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientTripHero
//
// Full-bleed 320 px cinematic opening for the client itinerary.
//
// Layout:
//   ┌──────────────────────────────────────┐  320 px
//   │  [hero image, object-fit cover]      │
//   │                                      │
//   │  ░░░░░ gradient bottom overlay ░░░░░ │
//   │  Trip Name                           │
//   │  Dates                               │
//   │  Destinations                        │
//   └──────────────────────────────────────┘
//
// When heroImage is null → dark linen placeholder so layout never shifts.
// Image fades in over 200 ms once the URL is ready.
// ─────────────────────────────────────────────────────────────────────────────

class ClientTripHero extends StatelessWidget {
  final Trip             trip;
  final ClientMediaItem? heroImage;

  const ClientTripHero({super.key, required this.trip, this.heroImage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width:  double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background — dark placeholder or fading hero image
          heroImage != null
              ? _FadeInHero(item: heroImage!)
              : const ColoredBox(color: Color(0xFF1C1C1A)),

          // Gradient overlay — transparent top → dark bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x73000000)],
                stops:  [0.35, 1.0],
              ),
            ),
          ),

          // Trip info — bottom-left anchored
          Positioned(
            left:   16,
            right:  16,
            bottom: 24,
            child:  _TripInfoOverlay(trip: trip),
          ),
        ],
      ),
    );
  }
}

// ── Fading hero image ─────────────────────────────────────────────────────────

class _FadeInHero extends StatefulWidget {
  final ClientMediaItem item;
  const _FadeInHero({required this.item});

  @override
  State<_FadeInHero> createState() => _FadeInHeroState();
}

class _FadeInHeroState extends State<_FadeInHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl    = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static Map<String, String> _headers() {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken;
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child:   Image.network(
          widget.item.displayUrl,
          headers:      _headers(),
          fit:          BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: Color(0xFF1C1C1A)),
        ),
      );
}

// ── Trip info text overlay ────────────────────────────────────────────────────

class _TripInfoOverlay extends StatelessWidget {
  final Trip trip;
  const _TripInfoOverlay({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateStr = _dateRange(trip);
    final dests   = trip.destinations.isNotEmpty
        ? trip.destinations.join('  ·  ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        // Trip name — 28px bold white
        Text(
          trip.name,
          style: const TextStyle(
            fontSize:   28,
            fontWeight: FontWeight.w700,
            color:      Colors.white,
            height:     1.2,
          ),
        ),

        // Date range
        if (dateStr != null) ...[
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w500,
              color:      Color(0xD9FFFFFF), // rgba(255,255,255,0.85)
            ),
          ),
        ],

        // Destinations
        if (dests != null) ...[
          const SizedBox(height: 4),
          Text(
            dests,
            style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w400,
              color:      Color(0xB3FFFFFF), // rgba(255,255,255,0.70)
            ),
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Date helpers ──────────────────────────────────────────────────────────────

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
