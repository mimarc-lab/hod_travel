import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/itinerary_models.dart';
import '../providers/itinerary_provider.dart';
import 'item_editor.dart';
import 'itinerary_item_card.dart';

/// Scrollable view for a single trip day — groups items by TimeBlock.
/// key: ValueKey(day.id) ensures state resets when the selected day changes.
class ItineraryDayView extends StatelessWidget {
  final TripDay day;
  final ItineraryProvider provider;

  /// Optional callback for the "Fill with AI" button shown on empty days.
  final VoidCallback? onAiFill;

  const ItineraryDayView({
    super.key,
    required this.day,
    required this.provider,
    this.onAiFill,
  });

  @override
  Widget build(BuildContext context) {
    final items = provider.itemsForDay(day.id);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _DayViewHeader(day: day, provider: provider)),
        if (items.isEmpty)
          SliverFillRemaining(child: _EmptyDayState(onAiFill: onAiFill))
        else ...[
          for (final block in TimeBlock.values)
            _TimeBlockSection(
              block: block,
              items: items.where((i) => i.timeBlock == block).toList(),
              day: day,
              provider: provider,
            ),
        ],
        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.massive)),
      ],
    );
  }
}

// ── Day header ────────────────────────────────────────────────────────────────

class _DayViewHeader extends StatelessWidget {
  final TripDay day;
  final ItineraryProvider provider;
  const _DayViewHeader({required this.day, required this.provider});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day ${day.dayNumber}  ·  ${day.date != null ? DateFormat('EEEE, d MMMM yyyy').format(day.date!) : ''}',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  day.city,
                  style: AppTextStyles.heading2,
                ),
                if (day.label != null)
                  Text(day.label!, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          // Add item button
          _AddItemButton(
            onTap: () => showItemEditor(context, provider: provider, dayId: day.id),
          ),
        ],
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddItemButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text('Add Item',
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Time block section ────────────────────────────────────────────────────────

class _TimeBlockSection extends StatelessWidget {
  final TimeBlock block;
  final List<ItineraryItem> items;
  final TripDay day;
  final ItineraryProvider provider;

  const _TimeBlockSection({
    required this.block,
    required this.items,
    required this.day,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Sort by start time ascending within the block. Items without a start
    // time come after timed items, in their existing DB sort_order.
    final sortedItems = [...items]..sort((a, b) {
        final at = a.startTime;
        final bt = b.startTime;
        if (at != null && bt != null) {
          final cmp = (at.hour * 60 + at.minute)
              .compareTo(bt.hour * 60 + bt.minute);
          if (cmp != 0) return cmp;
        }
        if (at != null) return -1;
        if (bt != null) return 1;
        return 0; // stable sort preserves relative DB order for untimed items
      });

    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, AppSpacing.base, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BlockHeader(block: block),
            const SizedBox(height: AppSpacing.sm),
            _ReorderableItemList(
              block: block,
              items: sortedItems,
              day: day,
              provider: provider,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  final TimeBlock block;
  const _BlockHeader({required this.block});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(block.label.toUpperCase(), style: AppTextStyles.overline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }
}

// ── Reorderable item list ─────────────────────────────────────────────────────

class _ReorderableItemList extends StatelessWidget {
  final TimeBlock block;
  final List<ItineraryItem> items;
  final TripDay day;
  final ItineraryProvider provider;

  const _ReorderableItemList({
    required this.block,
    required this.items,
    required this.day,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 4,
        shadowColor: AppColors.accent.withAlpha(40),
        child: child,
      ),
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        // items is the sorted display list passed from _TimeBlockSection.
        // Reorder directly using item references (avoids index mapping
        // against the unsorted provider list which caused wrong positions).
        final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
        final reordered = [...items];
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(adjusted, moved);
        provider.reorderBlock(
          dayId:        day.id,
          block:        block,
          newBlockOrder: reordered,
        );
      },
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ReorderableDragStartListener(
          key: ValueKey(item.id),
          index: index,
          child: ItineraryItemCard(item: item, provider: provider),
        );
      },
    );
  }
}

// ── Empty day state ───────────────────────────────────────────────────────────

class _EmptyDayState extends StatelessWidget {
  final VoidCallback? onAiFill;
  const _EmptyDayState({this.onAiFill});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.map_outlined,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('No items yet', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text('Tap "Add Item" to build this day\'s schedule.',
              style: AppTextStyles.bodySmall),
          if (onAiFill != null) ...[
            const SizedBox(height: AppSpacing.base),
            GestureDetector(
              onTap: onAiFill,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    Text(
                      'Fill this day with AI',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
