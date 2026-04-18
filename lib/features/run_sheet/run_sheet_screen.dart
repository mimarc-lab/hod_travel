import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/run_sheet_item.dart';
import '../../data/models/trip_model.dart';
import 'providers/run_sheet_provider.dart';
import 'widgets/run_sheet_day_selector.dart';
import 'widgets/run_sheet_filter_bar.dart';
import 'widgets/run_sheet_item_card.dart';
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

  const RunSheetScreen({
    super.key,
    required this.trip,
    this.viewMode         = RunSheetViewMode.director,
    this.responsibleUserId,
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
      backgroundColor: AppColors.background,
      appBar: _RunSheetAppBar(
        trip:       widget.trip,
        viewMode:   widget.viewMode,
        onShare:    widget.viewMode == RunSheetViewMode.director
            ? () => showRunSheetShareDialog(
                  context,
                  tripId:   widget.trip.id,
                  tripName: widget.trip.name,
                )
            : null, // only directors can share
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

              // Day chips (mobile) or nothing (desktop uses panel)
              if (isMobile) RunSheetDayChips(provider: _provider),

              // Filter bar
              RunSheetFilterBar(provider: _provider),

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
      backgroundColor:  AppColors.surface,
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
          Text('Run Sheet', style: AppTextStyles.heading3),
          Text(
            trip.name,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        // INTERNAL badge (director) or ROLE badge (restricted views)
        _ViewBadge(viewMode: viewMode),

        // Share button — director only
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
        child: Divider(height: 1, color: AppColors.border),
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
          borderRadius: BorderRadius.circular(6),
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
        borderRadius: BorderRadius.circular(6),
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
        _StatsSidebar(provider: provider),
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
    final items = provider.visibleItems;
    final day   = provider.selectedDay;

    return CustomScrollView(
      slivers: [
        // Day header
        if (day != null)
          SliverToBoxAdapter(child: _DayHeader(day: day, provider: provider)),

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
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, 0, AppSpacing.base, AppSpacing.massive),
            sliver: SliverList.separated(
              itemCount:        items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => RunSheetItemCard(
                item:     items[i],
                provider: provider,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Day header ────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final TripDay          day;
  final RunSheetProvider provider;
  const _DayHeader({required this.day, required this.provider});

  @override
  Widget build(BuildContext context) {
    final dateStr = day.date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(day.date!)
        : '';
    final items = provider.visibleItems;
    final done  = items
        .where((i) => i.status == RunSheetStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day ${day.dayNumber}  ·  ${day.city.toUpperCase()}',
                    style: AppTextStyles.heading2,
                  ),
                  if (dateStr.isNotEmpty)
                    Text(dateStr, style: AppTextStyles.bodySmall),
                ],
              ),
              const Spacer(),
              if (items.isNotEmpty)
                _ProgressPill(done: done, total: items.length),
            ],
          ),
          if (day.title != null && day.title!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              day.title!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
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
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:           pct,
              minHeight:       5,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF059669)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$done / $total',
          style: AppTextStyles.labelSmall.copyWith(
            color:      AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Stats sidebar (desktop only) ──────────────────────────────────────────────

class _StatsSidebar extends StatelessWidget {
  final RunSheetProvider provider;
  const _StatsSidebar({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Stats are scoped to the active role's visible items
    final all       = provider.roleFilteredItems;
    final total     = all.length;
    final completed = all
        .where((i) => i.status == RunSheetStatus.completed)
        .length;
    final inProg    = all
        .where((i) => i.status == RunSheetStatus.inProgress)
        .length;
    final delayed   = all
        .where((i) => i.status == RunSheetStatus.delayed)
        .length;
    final issues    = all
        .where((i) => i.status == RunSheetStatus.issueFlagged)
        .length;

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRIP SUMMARY',
            style: AppTextStyles.overline.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatRow('Total items',  '$total',     AppColors.textSecondary),
          _StatRow('Completed',    '$completed', const Color(0xFF059669)),
          _StatRow('In Progress',  '$inProg',    const Color(0xFF1D4ED8)),
          if (delayed > 0)
            _StatRow('Delayed',   '$delayed',   const Color(0xFF92400E)),
          if (issues > 0)
            _StatRow('Issues',    '$issues',    const Color(0xFF991B1B)),

          const Divider(height: AppSpacing.xl, color: AppColors.border),

          const Spacer(),
          TextButton.icon(
            onPressed: provider.reload,
            icon:  const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color:      color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
