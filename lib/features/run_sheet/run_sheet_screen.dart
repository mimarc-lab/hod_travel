import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/run_sheet_item.dart';
import '../../data/models/trip_model.dart';
import '../client_view/client_view_theme.dart';
import 'providers/run_sheet_provider.dart';
import 'widgets/run_sheet_day_selector.dart';
import 'widgets/run_sheet_editorial_item.dart';
import 'widgets/run_sheet_filter_bar.dart';
import 'widgets/run_sheet_share_dialog.dart';
import 'widgets/run_sheet_view_mode_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetScreen — internal staff-facing execution view
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetScreen extends StatefulWidget {
  final Trip             trip;

  /// The view mode to activate. Defaults to [RunSheetViewMode.director]
  /// (full access). Pass a restricted mode when opening via a share link.
  final RunSheetViewMode viewMode;

  /// When the screen is opened via a share token, the responsible user id
  /// enables assignment-based filtering (driver/guide sees their own items
  /// even if they fall outside the role's default item types).
  final String?          responsibleUserId;

  /// Set to false when opened from a public share link to hide the re-share
  /// button even for director-mode tokens.
  final bool             canShare;

  const RunSheetScreen({
    super.key,
    required this.trip,
    this.viewMode         = RunSheetViewMode.director,
    this.responsibleUserId,
    this.canShare         = true,
  });

  @override
  State<RunSheetScreen> createState() => _RunSheetScreenState();
}

class _RunSheetScreenState extends State<RunSheetScreen> {
  late final RunSheetProvider _provider;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = RunSheetProvider(
      tripId:              widget.trip.id,
      itineraryRepository: repos?.itinerary,
      runSheetRepository:  repos?.runSheets,
      teamId:              repos?.currentTeamId,
      viewMode:            widget.viewMode,
      responsibleUserId:   widget.responsibleUserId,
      isShareLink:         !widget.canShare,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: ClientViewTheme.pageBg,
      appBar: _RunSheetAppBar(
        trip:       widget.trip,
        viewMode:   widget.viewMode,
        onShare:    widget.canShare && widget.viewMode == RunSheetViewMode.director
            ? () {
                // Read items at tap time so we always have the loaded list.
                showRunSheetShareDialog(
                  context,
                  tripId:   widget.trip.id,
                  tripName: widget.trip.name,
                  allItems: List.from(_provider.allItems),
                  days:     List.from(_provider.days),
                );
              }
            : null, // only directors can share; hidden on public share views
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            );
          }
          if (_provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 36, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(_provider.error!, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _provider.reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (_provider.days.isEmpty) {
            return _EmptyState(onRefresh: _provider.reload);
          }

          return Column(
            children: [
              // View-mode banner (shown for all restricted views)
              if (widget.viewMode.isRestricted)
                RunSheetViewModeBanner(mode: widget.viewMode),

              // Filter bar (search + filters) — before day chips on mobile
              RunSheetFilterBar(provider: _provider),

              // Day chips carousel (mobile only — desktop uses panel)
              if (isMobile) RunSheetDayChips(provider: _provider),

              // Body
              Expanded(
                child: isMobile
                    ? _MobileBody(provider: _provider)
                    : _DesktopBody(provider: _provider),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _RunSheetAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Trip             trip;
  final RunSheetViewMode viewMode;
  final VoidCallback?    onShare;

  const _RunSheetAppBar({
    required this.trip,
    required this.viewMode,
    this.onShare,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor:  ClientViewTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded,
            size: 18, color: AppColors.textSecondary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Run Sheet',
            style: GoogleFonts.inter(
              fontSize:    15,
              fontWeight:  FontWeight.w500,
              color:       ClientViewTheme.ink,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            trip.name,
            style: ClientViewTheme.itemMeta,
          ),
        ],
      ),
      actions: [
        _ViewBadge(viewMode: viewMode),
        if (onShare != null)
          IconButton(
            onPressed: onShare,
            tooltip:   'Share access',
            icon: const Icon(Icons.share_rounded,
                size: 18, color: AppColors.textSecondary),
          ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: ClientViewTheme.hairline),
      ),
    );
  }
}

class _ViewBadge extends StatelessWidget {
  final RunSheetViewMode viewMode;
  const _ViewBadge({required this.viewMode});

  @override
  Widget build(BuildContext context) {
    if (viewMode == RunSheetViewMode.director) {
      // Unchanged "INTERNAL" style
      return Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 11, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              'INTERNAL',
              style: AppTextStyles.overline.copyWith(
                color:         Colors.orange.shade700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    // Role badge for restricted views
    final color = viewMode.color;
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(viewMode.icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            viewMode.label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(
              color:         color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop layout ────────────────────────────────────────────────────────────

class _DesktopBody extends StatelessWidget {
  final RunSheetProvider provider;
  const _DesktopBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RunSheetDayPanel(provider: provider),
        Expanded(child: _ItemList(provider: provider)),
      ],
    );
  }
}

// ── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileBody extends StatelessWidget {
  final RunSheetProvider provider;
  const _MobileBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    return _ItemList(provider: provider);
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  final RunSheetProvider provider;
  const _ItemList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final items   = provider.visibleItems;
    final day     = provider.selectedDay;
    final isMob   = Responsive.isMobile(context);
    final hPad    = isMob ? 20.0 : 40.0;

    return CustomScrollView(
      slivers: [
        // Editorial day chapter header
        if (day != null)
          SliverToBoxAdapter(
              child: _DayHeader(day: day, provider: provider, hPad: hPad)),

        // Items
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_outlined,
                      size: 36, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    provider.filter.isActive
                        ? 'No items match the current filters.'
                        : 'No items for this day.',
                    style: AppTextStyles.bodySmall,
                  ),
                  if (provider.filter.isActive) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: provider.clearFilter,
                      child: const Text('Clear filters'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else ...[
          SliverList.separated(
            itemCount:        items.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: ClientViewTheme.hairline),
            itemBuilder: (_, i) => RunSheetEditorialItem(
              item:     items[i],
              provider: provider,
              hPad:     hPad,
            ),
          ),
          const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.massive)),
        ],
      ],
    );
  }
}

// ── Day header ────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final TripDay          day;
  final RunSheetProvider provider;
  final double           hPad;
  const _DayHeader({required this.day, required this.provider, this.hPad = 40.0});

  @override
  Widget build(BuildContext context) {
    final dateStr = day.date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(day.date!).toUpperCase()
        : '';
    final items = provider.visibleItems;
    final done  = items
        .where((i) => i.status == RunSheetStatus.completed)
        .length;
    final city = day.city.isEmpty ? 'Day ${day.dayNumber}' : day.city;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 36, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DAY label in gold
          Text(
            'DAY ${day.dayNumber.toString().padLeft(2, '0')}',
            style: ClientViewTheme.dayLabel,
          ),
          const SizedBox(height: 6),

          // City name — large light weight
          Text(city, style: ClientViewTheme.cityName),
          const SizedBox(height: 6),

          // Date + progress pill row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (dateStr.isNotEmpty)
                Text(dateStr, style: ClientViewTheme.dayDate),
              const Spacer(),
              if (items.isNotEmpty)
                _ProgressPill(done: done, total: items.length),
            ],
          ),

          // Day title / overview line
          if (day.title != null && day.title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(day.title!, style: ClientViewTheme.dayIntro),
          ],

          // Gold accent underline
          const SizedBox(height: 14),
          Container(width: 28, height: 1.5, color: ClientViewTheme.gold),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressPill({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:           pct,
              minHeight:       4,
              backgroundColor: ClientViewTheme.hairline,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  ClientViewTheme.gold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$done / $total',
          style: ClientViewTheme.itemMeta.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color:        AppColors.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No itinerary yet', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text(
            'Build the itinerary first, then return here to manage execution.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: onRefresh,
            icon:  const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
