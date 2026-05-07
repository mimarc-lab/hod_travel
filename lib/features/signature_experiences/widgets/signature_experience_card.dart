import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/signature_experience.dart';

// ── Public card widget ────────────────────────────────────────────────────────

/// Editorial image-led card for a single [SignatureExperience].
///
/// Layout A (has media): cinematic image with category chip, status chip,
/// and title overlaid on a bottom gradient. Description + meta below.
///
/// Layout B (no media): elegant category-colour gradient placeholder with
/// centered icon. Title + description + meta below on white.
class SignatureExperienceCard extends StatefulWidget {
  final SignatureExperience experience;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SignatureExperienceCard({
    super.key,
    required this.experience,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<SignatureExperienceCard> createState() =>
      _SignatureExperienceCardState();
}

class _SignatureExperienceCardState extends State<SignatureExperienceCard> {
  bool _hovered = false;

  static const List<BoxShadow> _shadowResting = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 4,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> _shadowHover = [
    BoxShadow(
      color: Color(0x18000000),
      blurRadius: 28,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final e = widget.experience;
    final imageUrl =
        e.mediaLinks.isNotEmpty ? e.mediaLinks.first : null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _hovered ? _shadowHover : _shadowResting,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image / placeholder area (220px fixed)
                _ImageArea(
                  experience: e,
                  imageUrl: imageUrl,
                  hovered: _hovered,
                ),
                // Text body — fills remaining space via Expanded in grid
                Expanded(
                  child: _TextBody(
                    experience: e,
                    hasImage: imageUrl != null,
                    hovered: _hovered,
                    isMobile: isMobile,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Image / placeholder area ──────────────────────────────────────────────────

class _ImageArea extends StatelessWidget {
  final SignatureExperience experience;
  final String? imageUrl;
  final bool hovered;

  const _ImageArea({
    required this.experience,
    required this.imageUrl,
    required this.hovered,
  });

  @override
  Widget build(BuildContext context) {
    final cat = experience.category;
    final hasImage = imageUrl != null;

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background: real image or category gradient ──────────────────
          if (hasImage)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 1.0,
                end: hovered ? 1.07 : 1.0,
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, scale, _) => Transform.scale(
                scale: scale,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) =>
                      _CategoryPlaceholder(category: cat),
                ),
              ),
            )
          else
            _CategoryPlaceholder(category: cat),

          // ── Gradient overlay ────────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hasImage
                      ? [Colors.transparent, const Color(0xCC000000)]
                      : [Colors.transparent, cat.color.withAlpha(160)],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),

          // ── Category chip (top-left) ────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: _GlassCategoryChip(category: cat),
          ),

          // ── Status chip (top-right) ─────────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: _GlassStatusChip(status: experience.status),
          ),

          // ── Title overlay on gradient (layout A — has image) ────────────
          if (hasImage)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Text(
                experience.title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                  height: 1.25,
                  shadows: const [
                    Shadow(color: Color(0x40000000), blurRadius: 6),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Category gradient placeholder ─────────────────────────────────────────────

class _CategoryPlaceholder extends StatelessWidget {
  final ExperienceCategory category;
  const _CategoryPlaceholder({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            category.color.withAlpha(160),
            category.color.withAlpha(230),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          category.icon,
          size: 52,
          color: Colors.white.withAlpha(200),
        ),
      ),
    );
  }
}

// ── Glassmorphism chips ───────────────────────────────────────────────────────

class _GlassCategoryChip extends StatelessWidget {
  final ExperienceCategory category;
  const _GlassCategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha(70),
          width: 0.5,
        ),
      ),
      child: Text(
        category.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _GlassStatusChip extends StatelessWidget {
  final ExperienceStatus status;
  const _GlassStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isFlagship = status == ExperienceStatus.flagship;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isFlagship
            ? AppColors.accent.withAlpha(230)
            : Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isFlagship ? Colors.white : status.color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Text body ─────────────────────────────────────────────────────────────────

class _TextBody extends StatelessWidget {
  final SignatureExperience experience;
  final bool hasImage;
  final bool hovered;
  final bool isMobile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TextBody({
    required this.experience,
    required this.hasImage,
    required this.hovered,
    required this.isMobile,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final hasMenu = onEdit != null || onDelete != null;

    // Refined metadata line: "Private · Tokyo · 2 Hours · 4–12 guests"
    final metaParts = <String>[
      e.experienceType.label,
      if (e.locationNotes != null && e.locationNotes!.isNotEmpty)
        e.locationNotes!,
      if (e.durationLabel != null && e.durationLabel!.isNotEmpty)
        e.durationLabel!,
      if (e.idealGroupSizeMin != null || e.idealGroupSizeMax != null)
        e.groupSizeLabel,
    ];
    final metaLine = metaParts.join(' · ');

    // Mood tags (max 2)
    final moodTags = e.tags.take(2).toList();
    final showMenu = isMobile || hovered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title — layout B only (no image). Layout A has title on image.
          if (!hasImage) ...[
            Text(
              e.title,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111111),
                letterSpacing: -0.2,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],

          // Editorial description
          if (e.shortDescriptionClient != null &&
              e.shortDescriptionClient!.isNotEmpty) ...[
            Text(
              e.shortDescriptionClient!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF555555),
                height: 1.5,
              ),
              maxLines: hasImage ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          const Spacer(),

          // Metadata line
          if (metaLine.isNotEmpty)
            Text(
              metaLine,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                height: 1.4,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // Tags + actions row
          if (moodTags.isNotEmpty || hasMenu) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mood tags
                for (final tag in moodTags) ...[
                  _MoodTag(label: tag),
                  if (tag != moodTags.last) const SizedBox(width: 4),
                ],
                const Spacer(),
                // Actions menu — fades in on desktop hover, always on mobile
                if (hasMenu)
                  AnimatedOpacity(
                    opacity: showMenu ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 140),
                    child: _CardMenu(onEdit: onEdit, onDelete: onDelete),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mood tag pill ─────────────────────────────────────────────────────────────

class _MoodTag extends StatelessWidget {
  final String label;
  const _MoodTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentFaint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.accentDark,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Card action menu ──────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _CardMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit' && onEdit != null) onEdit!();
        if (v == 'delete' && onDelete != null) onDelete!();
      },
      tooltip: 'Options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined,
                  size: 14, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onEdit != null && onDelete != null) const PopupMenuDivider(),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 14, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ]),
          ),
      ],
      child: Container(
        width: 28,
        height: 28,
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
