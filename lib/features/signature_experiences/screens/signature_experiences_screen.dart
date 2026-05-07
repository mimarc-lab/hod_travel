import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/signature_experience.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/signature_experience_provider.dart';
import '../widgets/signature_experience_card.dart';
import '../widgets/signature_experience_filter_bar.dart';
import 'signature_experience_detail_screen.dart';
import 'signature_experience_form_screen.dart';

class SignatureExperiencesScreen extends StatefulWidget {
  const SignatureExperiencesScreen({super.key});

  @override
  State<SignatureExperiencesScreen> createState() =>
      _SignatureExperiencesScreenState();
}

class _SignatureExperiencesScreenState
    extends State<SignatureExperiencesScreen> {
  late final SignatureExperienceProvider _provider;
  String _search = '';
  ExperienceStatus? _filterStatus;
  ExperienceCategory? _filterCategory;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _provider = SignatureExperienceProvider(
      repository: AppRepositories.instance?.signatureExperiences,
      teamId: AppRepositories.instance?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  // ── Filtering ───────────────────────────────────────────────────────────────

  List<SignatureExperience> get _filtered {
    return _provider.experiences.where((e) {
      final q = _search.toLowerCase();
      final matchSearch = _search.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          (e.shortDescriptionClient?.toLowerCase().contains(q) ?? false) ||
          (e.conceptSummary?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchStatus =
          _filterStatus == null || e.status == _filterStatus;
      final matchCategory =
          _filterCategory == null || e.category == _filterCategory;
      return matchSearch && matchStatus && matchCategory;
    }).toList();
  }

  // Returns the best experience for the featured hero — must have media.
  // Prefers flagship, then approved. Hidden when any filter is active.
  SignatureExperience? get _featured {
    if (_search.isNotEmpty ||
        _filterStatus != null ||
        _filterCategory != null) {
      return null;
    }
    final withMedia = _provider.experiences
        .where((e) => e.mediaLinks.isNotEmpty)
        .toList();
    final flagship = withMedia
        .where((e) => e.status == ExperienceStatus.flagship)
        .toList();
    if (flagship.isNotEmpty) { return flagship.first; }
    final approved = withMedia
        .where((e) => e.status == ExperienceStatus.approved)
        .toList();
    if (approved.isNotEmpty) { return approved.first; }
    return null;
  }

  // ── Navigation (unchanged) ──────────────────────────────────────────────────

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SignatureExperienceFormScreen(provider: _provider),
      ),
    );
  }

  void _openDetail(SignatureExperience e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureExperienceDetailScreen(
          experience: e,
          provider: _provider,
        ),
      ),
    );
  }

  void _openEdit(SignatureExperience e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureExperienceFormScreen(
          provider: _provider,
          existing: e,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SignatureExperience e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete experience?'),
        content: Text(
          'This will permanently delete "${e.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _provider.delete(e.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not delete. Please try again.')),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = isMobile ? 1 : (width >= 1200 ? 3 : 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Experience Library',
        showMenuButton: isMobile,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        actions: [_CreateButton(onTap: _openCreate)],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          // ── Loading ──────────────────────────────────────────────────────
          if (_provider.isLoading && _provider.experiences.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (_provider.error != null &&
              _provider.experiences.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: AppSpacing.base),
                  Text(_provider.error!,
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.base),
                  GestureDetector(
                    onTap: _provider.reload,
                    child: Text(
                      'Retry',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            );
          }

          final featured = _featured;
          final filtered = _filtered;

          // ── Main content ─────────────────────────────────────────────────
          return CustomScrollView(
            slivers: [
              // Header + filters + featured
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    hPad, AppSpacing.xl, hPad, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Editorial page header
                    _LibraryHeader(
                      count: _provider.experiences.length,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Search + filters
                    SignatureExperienceFilterBar(
                      search: _search,
                      onSearchChanged: (v) =>
                          setState(() => _search = v),
                      filterStatus: _filterStatus,
                      onStatusChanged: (s) =>
                          setState(() => _filterStatus = s),
                      filterCategory: _filterCategory,
                      onCategoryChanged: (c) =>
                          setState(() => _filterCategory = c),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Featured cinematic card
                    if (featured != null) ...[
                      _FeaturedExperienceCard(
                        experience: featured,
                        onTap: () => _openDetail(featured),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    // Collection section label
                    _CollectionHeader(
                      filtered: filtered.length,
                      total: _provider.experiences.length,
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ]),
                ),
              ),

              // Experience grid (or empty state)
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: hPad),
                    child: EmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: 'No experiences found',
                      subtitle: _search.isNotEmpty ||
                              _filterStatus != null ||
                              _filterCategory != null
                          ? 'Try adjusting your search or filters.'
                          : 'Add your first DreamMaker experience to build the library.',
                      actionLabel: (_search.isEmpty &&
                              _filterStatus == null &&
                              _filterCategory == null)
                          ? 'Create Experience'
                          : null,
                      onAction: _openCreate,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      hPad, 0, hPad, AppSpacing.massive),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => SignatureExperienceCard(
                        experience: filtered[i],
                        onTap: () => _openDetail(filtered[i]),
                        onEdit: () => _openEdit(filtered[i]),
                        onDelete: () => _confirmDelete(filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      // Fixed card height: 220px image + 200px text body
                      mainAxisExtent: 420,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Library header ─────────────────────────────────────────────────────────────

class _LibraryHeader extends StatelessWidget {
  final int count;
  const _LibraryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DreamMaker Experiences',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Curated global collection of private experiences',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

// ── Collection section label ───────────────────────────────────────────────────

class _CollectionHeader extends StatelessWidget {
  final int filtered;
  final int total;
  const _CollectionHeader({required this.filtered, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'The Collection',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            filtered == total ? '$total' : '$filtered of $total',
            style: AppTextStyles.labelSmall,
          ),
        ),
      ],
    );
  }
}

// ── Featured cinematic hero card ───────────────────────────────────────────────

class _FeaturedExperienceCard extends StatefulWidget {
  final SignatureExperience experience;
  final VoidCallback onTap;

  const _FeaturedExperienceCard({
    required this.experience,
    required this.onTap,
  });

  @override
  State<_FeaturedExperienceCard> createState() =>
      _FeaturedExperienceCardState();
}

class _FeaturedExperienceCardState
    extends State<_FeaturedExperienceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.experience;
    final imageUrl = e.mediaLinks.first;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 300,
          transform:
              Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: _hovered
                ? const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 32,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Cinematic image with subtle zoom on hover ──────────
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 1.0,
                    end: _hovered ? 1.05 : 1.0,
                  ),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (_, scale, _) => Transform.scale(
                    scale: scale,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // ── Dark cinematic gradient ────────────────────────────
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x14000000),
                          Color(0xCC000000),
                        ],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── Featured badge (top-left) ──────────────────────────
                const Positioned(
                  top: 16,
                  left: 16,
                  child: _FeaturedBadge(),
                ),

                // ── Status chip (top-right) ────────────────────────────
                Positioned(
                  top: 16,
                  right: 16,
                  child: _FeaturedStatusChip(status: e.status),
                ),

                // ── Editorial text (bottom) ────────────────────────────
                Positioned(
                  bottom: 24,
                  left: 22,
                  right: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category + location meta
                      Row(
                        children: [
                          _FeaturedCategoryChip(
                              category: e.category),
                          if (e.locationNotes != null &&
                              e.locationNotes!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(
                              e.locationNotes!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withAlpha(180),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title — large
                      Text(
                        e.title,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Short description
                      if (e.shortDescriptionClient != null &&
                          e.shortDescriptionClient!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          e.shortDescriptionClient!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withAlpha(200),
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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

// ── Featured card sub-widgets ─────────────────────────────────────────────────

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 11, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            'FEATURED',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedStatusChip extends StatelessWidget {
  final ExperienceStatus status;
  const _FeaturedStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isFlagship = status == ExperienceStatus.flagship;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _FeaturedCategoryChip extends StatelessWidget {
  final ExperienceCategory category;
  const _FeaturedCategoryChip({required this.category});

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

// ── Create button ─────────────────────────────────────────────────────────────

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius:
              BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'New Experience',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
