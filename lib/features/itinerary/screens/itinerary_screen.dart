import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/trip_model.dart';
import '../../../features/ai_suggestions/itinerary_sequence/itinerary_sequence_review_screen.dart';
import '../providers/itinerary_provider.dart';
import '../widgets/day_navigator.dart';
import '../widgets/itinerary_day_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryScreen — Full-width Operational Itinerary Composer
// ─────────────────────────────────────────────────────────────────────────────

/// Itinerary Builder tab — shown inside TripBoardScreen's TabBarView.
/// Uses AutomaticKeepAliveClientMixin to preserve state across tab switches.
/// Pass [provider] to share an existing ItineraryProvider (e.g. from TripBoardScreen).
class ItineraryScreen extends StatefulWidget {
  final Trip trip;
  final ItineraryProvider? provider;
  const ItineraryScreen({super.key, required this.trip, this.provider});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen>
    with AutomaticKeepAliveClientMixin {
  late final ItineraryProvider _provider;
  late final bool _ownsProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.provider != null) {
      _provider = widget.provider!;
      _ownsProvider = false;
    } else {
      _provider = ItineraryProvider(
        widget.trip,
        repository: AppRepositories.instance?.itinerary,
        teamId:     AppRepositories.instance?.currentTeamId,
      );
      _ownsProvider = true;
    }
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.isLoading && _provider.days.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (_provider.error != null && _provider.days.isEmpty) {
          return _ErrorState(provider: _provider);
        }
        if (_provider.days.isEmpty) {
          return _EmptyItinerary(provider: _provider);
        }

        final day = _provider.selectedDay;
        return Column(
          children: [
            _ComposerToolbar(
              provider: _provider,
              onSuggestSequence: () => showItinerarySequenceReview(
                context,
                trip:              widget.trip,
                itineraryProvider: _provider,
              ),
            ),
            Expanded(
              child: day == null
                  ? const SizedBox.shrink()
                  : ItineraryDayView(
                      key: ValueKey(day.id),
                      day: day,
                      provider: _provider,
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ComposerToolbar
//
// LEFT:  Day selector dropdown  [ DAY 2 ▼  Venice ]
// RIGHT: AI actions  [ Suggest Sequence ]  [ + Add Day ]
// ─────────────────────────────────────────────────────────────────────────────

class _ComposerToolbar extends StatelessWidget {
  final ItineraryProvider provider;
  final VoidCallback onSuggestSequence;

  const _ComposerToolbar({
    required this.provider,
    required this.onSuggestSequence,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final hPad = mobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // ── Day selector ───────────────────────────────────────────────────
          _DaySelectorDropdown(provider: provider),

          const Spacer(),

          // ── AI suggest sequence ────────────────────────────────────────────
          if (mobile)
            Tooltip(
              message: 'Suggest Sequence',
              child: _IconAction(
                icon: Icons.view_timeline_rounded,
                color: const Color(0xFF0F766E),
                bgColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFF0F766E),
                onTap: onSuggestSequence,
              ),
            )
          else
            _TextAction(
              icon: Icons.view_timeline_rounded,
              label: 'Suggest Sequence',
              color: const Color(0xFF0F766E),
              bgColor: const Color(0xFFF0FDFA),
              borderColor: const Color(0xFF0F766E),
              onTap: onSuggestSequence,
            ),

          const SizedBox(width: AppSpacing.sm),

          // ── Add Day ────────────────────────────────────────────────────────
          if (mobile)
            Tooltip(
              message: 'Add Day',
              child: _IconAction(
                icon: Icons.add_rounded,
                color: AppColors.accent,
                bgColor: AppColors.accentFaint,
                borderColor: AppColors.accentLight,
                onTap: () => showAddDaySheet(context, provider: provider),
              ),
            )
          else
            _TextAction(
              icon: Icons.add_rounded,
              label: 'Add Day',
              color: AppColors.accent,
              bgColor: AppColors.accentFaint,
              borderColor: AppColors.accentLight,
              onTap: () => showAddDaySheet(context, provider: provider),
            ),
        ],
      ),
    );
  }
}

// ── _DaySelectorDropdown ──────────────────────────────────────────────────────

/// Premium day selector that opens a positioned overlay dropdown.
/// Shows "DAY N ▼ City" and lists all days with date + theme label.
class _DaySelectorDropdown extends StatefulWidget {
  final ItineraryProvider provider;
  const _DaySelectorDropdown({required this.provider});

  @override
  State<_DaySelectorDropdown> createState() => _DaySelectorDropdownState();
}

class _DaySelectorDropdownState extends State<_DaySelectorDropdown> {
  OverlayEntry? _overlay;
  bool _open = false;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_overlay != null) {
      _close();
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox;
    final offset    = renderBox.localToGlobal(Offset.zero);
    final size      = renderBox.size;

    _overlay = OverlayEntry(
      builder: (_) => _DayDropdownOverlay(
        provider:     widget.provider,
        anchorOffset: offset,
        anchorSize:   size,
        onSelect: (i) {
          widget.provider.selectDay(i);
          _close();
        },
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() => _open = true);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.provider.selectedDay;

    return GestureDetector(
      onTap: _toggleDropdown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _open ? AppColors.accent : AppColors.border,
            width: _open ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withAlpha(6),
              blurRadius: 8,
              offset:     const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DAY badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY ${day?.dayNumber ?? '—'}',
                style: AppTextStyles.labelSmall.copyWith(
                  color:      Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize:   9,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // City name
            Flexible(
              child: Text(
                day?.city.isNotEmpty == true ? day!.city : 'Select day',
                style: AppTextStyles.labelMedium.copyWith(
                  color:      AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              size:  16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _DayDropdownOverlay ───────────────────────────────────────────────────────

class _DayDropdownOverlay extends StatelessWidget {
  final ItineraryProvider provider;
  final Offset anchorOffset;
  final Size anchorSize;
  final ValueChanged<int> onSelect;
  final VoidCallback onDismiss;

  const _DayDropdownOverlay({
    required this.provider,
    required this.anchorOffset,
    required this.anchorSize,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss layer
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown card
        Positioned(
          top:  anchorOffset.dy + anchorSize.height + 6,
          left: anchorOffset.dx,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 290,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withAlpha(18),
                    blurRadius: 24,
                    offset:     const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  padding:   const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount:  provider.days.length,
                  itemBuilder: (_, i) {
                    final day        = provider.days[i];
                    final isSelected = provider.selectedDayIndex == i;
                    return _DropdownDayRow(
                      day:        day,
                      isSelected: isSelected,
                      itemCount: provider.itemsForDay(day.id)
                          .where((it) => it.type != ItemType.note)
                          .length,
                      onTap: () => onSelect(i),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── _DropdownDayRow ───────────────────────────────────────────────────────────

class _DropdownDayRow extends StatelessWidget {
  final TripDay day;
  final bool isSelected;
  final int itemCount;
  final VoidCallback onTap;

  const _DropdownDayRow({
    required this.day,
    required this.isSelected,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color:   isSelected ? AppColors.accentFaint : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // DAY badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        isSelected ? AppColors.accent : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY ${day.dayNumber}',
                style: AppTextStyles.labelSmall.copyWith(
                  color:      isSelected ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize:   9,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // City + date + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.city.isNotEmpty ? day.city : 'Day ${day.dayNumber}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (day.date != null || day.label != null)
                    Text(
                      [
                        if (day.date != null)
                          DateFormat('d MMM yyyy').format(day.date!),
                        if (day.label != null) day.label!,
                      ].join('  ·  '),
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 10,
                        color:    AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Item count badge
            if (itemCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        isSelected
                      ? AppColors.accent.withAlpha(22)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize:   10,
                    color:      isSelected ? AppColors.accentDark : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.check_rounded,
              size:  14,
              color: isSelected ? AppColors.accent : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar action buttons ────────────────────────────────────────────────────

class _TextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _TextAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: borderColor.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  34,
        height: 34,
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: borderColor.withAlpha(80)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final ItineraryProvider provider;
  const _ErrorState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 32, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              provider.error!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.base),
            TextButton.icon(
              onPressed: provider.reload,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyItinerary extends StatelessWidget {
  final ItineraryProvider provider;
  const _EmptyItinerary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              color:        AppColors.accentFaint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.map_outlined,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No itinerary yet', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text(
            'Add your first day to start building the schedule.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => showAddDaySheet(context, provider: provider),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Day'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation:       0,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
