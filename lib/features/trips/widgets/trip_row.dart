import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/trip_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ── Premium travel gradient palette ──────────────────────────────────────────

const _kTripGradients = <List<Color>>[
  [Color(0xFF1C2B4A), Color(0xFF2D4A7A)],   // Mediterranean blue
  [Color(0xFF1A3A2A), Color(0xFF2D5A3D)],   // Rainforest green
  [Color(0xFF3A1A1A), Color(0xFF6B2A2A)],   // Desert dusk
  [Color(0xFF2A1A3A), Color(0xFF4C2D6B)],   // Violet twilight
  [Color(0xFF1A2A3A), Color(0xFF2A4A6B)],   // Nordic fjord
  [Color(0xFF3A2A1A), Color(0xFF6B4C2A)],   // Sahara amber
];

const _kCardRadius = 16.0;
const _kHeroHeight = 110.0;

// ── TripCard ─────────────────────────────────────────────────────────────────

/// Premium editorial trip card for the trip portfolio grid.
class TripCard extends StatefulWidget {
  final Trip trip;

  /// Index into [_kTripGradients]. Use `trip.id.hashCode.abs() % 6` for
  /// consistent per-trip colour assignment.
  final int gradientIndex;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const TripCard({
    super.key,
    required this.trip,
    required this.gradientIndex,
    required this.onTap,
    this.onEdit,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final gradient = _kTripGradients[widget.gradientIndex.clamp(0, 5)];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: [
              BoxShadow(
                color: Color(_hovered ? 0x12000000 : 0x07000000),
                blurRadius: _hovered ? 24 : 8,
                offset: Offset(0, _hovered ? 8 : 3),
              ),
              BoxShadow(
                color: Color(_hovered ? 0x05000000 : 0x00000000),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroArea(
                  trip: widget.trip,
                  gradient: gradient,
                  hovered: _hovered,
                ),
                _CardBody(
                  trip: widget.trip,
                  onEdit: widget.onEdit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero image area ───────────────────────────────────────────────────────────

class _HeroArea extends StatelessWidget {
  final Trip trip;
  final List<Color> gradient;
  final bool hovered;

  const _HeroArea({
    required this.trip,
    required this.gradient,
    required this.hovered,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kHeroHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Gradient background — scales subtly on hover
          AnimatedScale(
            scale: hovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
            ),
          ),
          // Bottom gradient overlay for depth
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(50),
                  ],
                ),
              ),
            ),
          ),
          // Status chip — top right, glassmorphism style
          Positioned(
            top: 10,
            right: 10,
            child: _StatusOverlay(status: trip.status),
          ),
          // Destination hint at bottom left
          if (trip.destinationSummary.isNotEmpty)
            Positioned(
              left: 12,
              bottom: 10,
              right: 70,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 10,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      trip.destinationSummary,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status overlay chip ───────────────────────────────────────────────────────

class _StatusOverlay extends StatelessWidget {
  final TripStatus status;
  const _StatusOverlay({required this.status});

  static Color _textColor(TripStatus s) {
    switch (s) {
      case TripStatus.planning:    return const Color(0xFF6B7280);
      case TripStatus.confirmed:   return const Color(0xFF1D4ED8);
      case TripStatus.inProgress:  return const Color(0xFF065F46);
      case TripStatus.completed:   return const Color(0xFF374151);
      case TripStatus.cancelled:   return const Color(0xFF991B1B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(224),  // ~0.88 opacity
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withAlpha(100)),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textColor(status),
          height: 1.2,
        ),
      ),
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onEdit;
  const _CardBody({required this.trip, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.startDate != null && trip.endDate != null
        ? '${DateFormat('d MMM').format(trip.startDate!)} – ${DateFormat('d MMM yy').format(trip.endDate!)}'
        : 'Dates TBD';
    final hasNotes = trip.notes != null && trip.notes!.trim().isNotEmpty;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip name + action menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trip.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111111),
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  _ActionMenu(onEdit: onEdit!),
              ],
            ),
            const SizedBox(height: 4),
            // Date · guests
            Text(
              '$dateStr  ·  ${trip.guestCount} guest${trip.guestCount == 1 ? '' : 's'}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF777777),
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Notes / mood line (optional)
            if (hasNotes) ...[
              const SizedBox(height: 3),
              Text(
                trip.notes!.trim(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF999999),
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            // Lead avatar + name
            Row(
              children: [
                UserAvatar(user: trip.tripLead, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.tripLead.name.split(' ').first,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF888888),
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action menu ───────────────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  const _ActionMenu({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onEdit();
      },
      tooltip: 'Trip options',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: Color(0xFFBBBBBB),
      ),
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
    );
  }
}
