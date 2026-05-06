import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/supplier_model.dart';

// ── Category gradient palette ─────────────────────────────────────────────────

const _kCategoryGradients = <SupplierType, List<Color>>{
  SupplierType.accommodation:      [Color(0xFF1C2B4A), Color(0xFF2D4A7A)],
  SupplierType.dining:             [Color(0xFF3D1A18), Color(0xFF6B2E2A)],
  SupplierType.transport:          [Color(0xFF1A2A3A), Color(0xFF2A4A6B)],
  SupplierType.guide:              [Color(0xFF1A3A2A), Color(0xFF2D5A3D)],
  SupplierType.experienceProvider: [Color(0xFF3A2A1A), Color(0xFF6B4C2A)],
  SupplierType.specialistServices: [Color(0xFF2A1A3A), Color(0xFF4C2D6B)],
  SupplierType.venue:              [Color(0xFF1A2A38), Color(0xFF2D3E5A)],
  SupplierType.other:              [Color(0xFF252525), Color(0xFF404040)],
};

const _kCardRadius = 18.0;
const _kHeroHeight = 120.0;

// ── SupplierCard ──────────────────────────────────────────────────────────────

/// Premium supplier card for the curated supplier portfolio grid.
/// Architecture note: heroImageUrl field reserved for future supplier media
/// integration (priority: hero image → media image → category gradient).
class SupplierCard extends StatefulWidget {
  final Supplier supplier;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SupplierCard({
    super.key,
    required this.supplier,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<SupplierCard> createState() => _SupplierCardState();
}

// Backward-compatible alias so any other importer still compiles.
typedef SupplierListItem = SupplierCard;

class _SupplierCardState extends State<SupplierCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final gradient =
        _kCategoryGradients[widget.supplier.effectiveSupplierType] ??
            [const Color(0xFF252525), const Color(0xFF404040)];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -3.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: [
              BoxShadow(
                color: Color(_hovered ? 0x12000000 : 0x06000000),
                blurRadius: _hovered ? 28 : 10,
                offset: Offset(0, _hovered ? 10 : 4),
              ),
              BoxShadow(
                color: Color(_hovered ? 0x06000000 : 0x00000000),
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
                _SupplierHero(
                  supplier: widget.supplier,
                  gradient: gradient,
                  hovered: _hovered,
                ),
                _SupplierCardBody(
                  supplier: widget.supplier,
                  onDelete: widget.onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero area ─────────────────────────────────────────────────────────────────

class _SupplierHero extends StatelessWidget {
  final Supplier supplier;
  final List<Color> gradient;
  final bool hovered;

  const _SupplierHero({
    required this.supplier,
    required this.gradient,
    required this.hovered,
  });

  @override
  Widget build(BuildContext context) {
    final type = supplier.effectiveSupplierType;
    final location = [supplier.city, supplier.country]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return SizedBox(
      height: _kHeroHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Gradient background — scales subtly on hover
          AnimatedScale(
            scale: hovered ? 1.06 : 1.0,
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
          // Bottom depth overlay
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
          // Category icon — centered, ghosted
          Center(
            child: Icon(
              type.icon,
              size: 34,
              color: Colors.white.withAlpha(60),
            ),
          ),
          // Location pill — bottom left
          if (location.isNotEmpty)
            Positioned(
              left: 12,
              bottom: 10,
              right: 52,
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
                      location,
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
          // Category chip — top right, glassmorphism
          Positioned(
            top: 10,
            right: 10,
            child: _CategoryOverlay(type: type),
          ),
        ],
      ),
    );
  }
}

// ── Category overlay chip ─────────────────────────────────────────────────────

class _CategoryOverlay extends StatelessWidget {
  final SupplierType type;
  const _CategoryOverlay({required this.type});

  String _shortLabel(SupplierType t) => switch (t) {
        SupplierType.accommodation      => 'Accommodation',
        SupplierType.dining             => 'Dining',
        SupplierType.transport          => 'Transport',
        SupplierType.guide              => 'Guide',
        SupplierType.experienceProvider => 'Experience',
        SupplierType.specialistServices => 'Specialist',
        SupplierType.venue              => 'Venue',
        SupplierType.other              => 'Other',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(224),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.color),
          const SizedBox(width: 4),
          Text(
            _shortLabel(type),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────────

class _SupplierCardBody extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback? onDelete;

  const _SupplierCardBody({required this.supplier, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasNotes =
        supplier.notes != null && supplier.notes!.trim().isNotEmpty;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + action menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    supplier.name,
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
                if (onDelete != null)
                  _SupplierActionMenu(onDelete: onDelete!),
              ],
            ),
            // Preferred Partner badge
            if (supplier.preferred) ...[
              const SizedBox(height: 4),
              const _PreferredPartnerBadge(),
            ],
            // Notes / editorial personality line
            if (hasNotes) ...[
              const SizedBox(height: 5),
              Text(
                supplier.notes!.trim(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF888888),
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            // Primary contact
            if (supplier.contactName != null)
              _ContactRow(name: supplier.contactName!),
          ],
        ),
      ),
    );
  }
}

// ── Preferred Partner badge ───────────────────────────────────────────────────

class _PreferredPartnerBadge extends StatelessWidget {
  const _PreferredPartnerBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.diamond_outlined,
          size: 11,
          color: AppColors.accent.withAlpha(180),
        ),
        const SizedBox(width: 4),
        Text(
          'Preferred Partner',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Contact row ───────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final String name;
  const _ContactRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 12,
          color: Color(0xFFAAAAAA),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF777777),
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Action menu ───────────────────────────────────────────────────────────────

class _SupplierActionMenu extends StatelessWidget {
  final VoidCallback onDelete;
  const _SupplierActionMenu({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      tooltip: 'Supplier options',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: Color(0xFFCCCCCC),
      ),
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFB00020)),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Color(0xFFB00020), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
