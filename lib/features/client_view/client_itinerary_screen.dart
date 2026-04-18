import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/trip_model.dart';
import 'client_view_theme.dart';
import 'services/client_safe_content_mapper.dart';
import 'services/pdf_export_service.dart';
import 'services/share_link_service.dart';
import 'widgets/itinerary_day_chapter.dart';
import 'widgets/refined_trip_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientItineraryScreen
//
// Client-facing itinerary — read-only, premium presentation layer.
// No internal fields, no ops chrome, no task or budget data.
// Feels like a luxury travel document, not a SaaS dashboard.
// ─────────────────────────────────────────────────────────────────────────────

class ClientItineraryScreen extends StatefulWidget {
  final Trip trip;

  const ClientItineraryScreen({super.key, required this.trip});

  @override
  State<ClientItineraryScreen> createState() => _ClientItineraryScreenState();
}

class _ClientItineraryScreenState extends State<ClientItineraryScreen>
    with AutomaticKeepAliveClientMixin {
  List<TripDay> _days = [];
  Map<String, List<ItineraryItem>> _itemsByDayId = {};
  bool _loading    = true;
  bool _exporting  = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppRepositories.instance?.itinerary;
    if (repo == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final days  = await repo.fetchDaysForTrip(widget.trip.id);
      days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      final items = await repo.fetchItemsForTrip(widget.trip.id);
      if (mounted) {
        setState(() {
          _days         = days;
          _itemsByDayId = items;
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    final url = await ShareLinkService.copyToClipboard(widget.trip.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Link copied — $url')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2028),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final safeItems = <String, List<ItineraryItem>>{};
      for (final entry in _itemsByDayId.entries) {
        safeItems[entry.key] = ClientSafeContentMapper.prepare(entry.value);
      }
      await PdfExportService.export(
        trip:        widget.trip,
        days:        _days,
        itemsByDayId: safeItems,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      );
    }

    return Column(
      children: [
        // Staff-only toolbar — not visible to the client
        _StaffToolbar(
          onShare:     _share,
          onExportPdf: _exporting ? null : _exportPdf,
          exporting:   _exporting,
        ),

        // Client presentation surface
        Expanded(
          child: Container(
            color: ClientViewTheme.pageBg,
            child: CustomScrollView(
              slivers: [
                // Refined trip header — no stats strip
                SliverToBoxAdapter(
                  child: RefinedTripHeader(trip: widget.trip),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.massive),
                ),

                if (_days.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(wide: wide),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final day        = _days[index];
                        final clientItems = ClientSafeContentMapper.prepare(
                          _itemsByDayId[day.id] ?? [],
                        );
                        return ItineraryDayChapter(
                          key:   ValueKey(day.id),
                          day:   day,
                          items: clientItems,
                          wide:  wide,
                        );
                      },
                      childCount: _days.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.massive),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Staff toolbar ─────────────────────────────────────────────────────────────
// Visible only inside the ops app. Not part of the client presentation.

class _StaffToolbar extends StatelessWidget {
  final VoidCallback  onShare;
  final VoidCallback? onExportPdf;
  final bool          exporting;

  const _StaffToolbar({
    required this.onShare,
    required this.onExportPdf,
    required this.exporting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical:   AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Client View',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textMuted)),
          const Spacer(),
          _ToolbarButton(
            icon:  Icons.link_rounded,
            label: 'Share Link',
            onTap: onShare,
          ),
          const SizedBox(width: AppSpacing.sm),
          _ToolbarButton(
            icon:    Icons.picture_as_pdf_outlined,
            label:   exporting ? 'Exporting…' : 'Export PDF',
            onTap:   onExportPdf,
            loading: exporting,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final VoidCallback? onTap;
  final bool       loading;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        enabled ? AppColors.surfaceAlt : AppColors.divider,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.textSecondary),
              )
            else
              Icon(icon, size: 13,
                  color: enabled ? AppColors.textSecondary : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: enabled ? AppColors.textSecondary : AppColors.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool wide;
  const _EmptyState({required this.wide});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color:        AppColors.accentFaint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map_outlined,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('Itinerary in preparation',
                style: AppTextStyles.heading2),
            const SizedBox(height: 6),
            Text(
              'Your personalised journey plan will appear here once confirmed.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
