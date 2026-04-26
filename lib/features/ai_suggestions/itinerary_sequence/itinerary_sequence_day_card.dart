import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/proposed_itinerary_day.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItinerarySequenceDayCard
//
// Shows one proposed day with its items and notes.
// Each item can be toggled included/removed, and title/time-block edited inline.
//
// All state lives in the parent (ItinerarySequenceReviewScreen) via callbacks.
// ─────────────────────────────────────────────────────────────────────────────

class ItinerarySequenceDayCard extends StatelessWidget {
  final ProposedItineraryDay day;
  final int dayIndex;

  /// itemId → true  means the item is included in the apply set.
  final Map<String, bool> includedItems;

  /// Called when the user toggles an item's included state.
  final void Function(String itemId, bool included) onToggleItem;

  /// Called when the user removes an item entirely from the draft.
  final void Function(String itemId) onRemoveItem;

  /// Called when the user edits an item's title inline.
  final void Function(String itemId, String title) onEditTitle;

  /// Called when the user changes an item's time-block.
  final void Function(String itemId, String timeBlock) onEditTimeBlock;

  const ItinerarySequenceDayCard({
    super.key,
    required this.day,
    required this.dayIndex,
    required this.includedItems,
    required this.onToggleItem,
    required this.onRemoveItem,
    required this.onEditTitle,
    required this.onEditTimeBlock,
  });

  @override
  Widget build(BuildContext context) {
    final activeItems  = day.items;
    final includedCount= activeItems.where((i) => includedItems[i.id] == true).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day header ──────────────────────────────────────────────────
          _DayHeader(day: day, includedCount: includedCount, total: activeItems.length),

          if (activeItems.isNotEmpty)
            const Divider(height: 1, color: AppColors.border),

          // ── Items ────────────────────────────────────────────────────────
          ...activeItems.map((item) => _ItemRow(
                key:            ValueKey(item.id),
                item:           item,
                included:       includedItems[item.id] ?? true,
                onToggle:       (v) => onToggleItem(item.id, v),
                onRemove:       ()  => onRemoveItem(item.id),
                onEditTitle:    (t) => onEditTitle(item.id, t),
                onEditTimeBlock:(tb)=> onEditTimeBlock(item.id, tb),
              )),

          // ── Pacing + routing notes ───────────────────────────────────────
          if (day.pacingNotes.isNotEmpty || day.routingNotes.isNotEmpty)
            _DayNotes(pacingNotes: day.pacingNotes, routingNotes: day.routingNotes),
        ],
      ),
    );
  }
}

// ── Day header ─────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final ProposedItineraryDay day;
  final int includedCount;
  final int total;
  const _DayHeader({required this.day, required this.includedCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final dateLabel = day.dateStr != null ? ' · ${day.dateStr}' : '';
    final cityLabel = day.city    != null ? ' — ${day.city}'    : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical:   AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width:  28,
            height: 28,
            decoration: BoxDecoration(
              color:        AppColors.accentFaint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${day.dayNumber}',
                style: AppTextStyles.labelMedium.copyWith(
                  color:      AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (day.title ?? 'Day ${day.dayNumber}') + cityLabel,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                if (dateLabel.isNotEmpty)
                  Text(
                    dateLabel.trimLeft().replaceFirst('·', '').trim(),
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          // Included count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        includedCount == total
                  ? const Color(0xFFDCFCE7)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(
                color: includedCount == total
                    ? const Color(0xFF16A34A).withAlpha(60)
                    : AppColors.border,
              ),
            ),
            child: Text(
              '$includedCount / $total',
              style: AppTextStyles.labelSmall.copyWith(
                color: includedCount == total
                    ? const Color(0xFF15803D)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item row ───────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final ProposedItineraryItem item;
  final bool                  included;
  final ValueChanged<bool>    onToggle;
  final VoidCallback          onRemove;
  final ValueChanged<String>  onEditTitle;
  final ValueChanged<String>  onEditTimeBlock;

  const _ItemRow({
    super.key,
    required this.item,
    required this.included,
    required this.onToggle,
    required this.onRemove,
    required this.onEditTitle,
    required this.onEditTimeBlock,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !included;

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical:   AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: dimmed ? AppColors.surfaceAlt : Colors.transparent,
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            SizedBox(
              width:  20,
              height: 20,
              child: Checkbox(
                value:          included,
                onChanged:      (v) => onToggle(v ?? false),
                activeColor:    AppColors.accent,
                shape:          RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Type icon
            _TypeIcon(typeName: item.componentTypeName),
            const SizedBox(width: AppSpacing.sm),

            // Title + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  if (item.location != null && item.location!.isNotEmpty)
                    Text(
                      item.location!,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),

            // Time block pill
            _TimeBlockPill(
              timeBlock:  item.timeBlock,
              startTime:  item.startTime,
              isFixed:    item.isFixedTime,
            ),
            const SizedBox(width: AppSpacing.xs),

            // ⋮ menu
            _ItemMenu(
              item:           item,
              onRemove:       onRemove,
              onEditTitle:    onEditTitle,
              onEditTimeBlock:onEditTimeBlock,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type icon ──────────────────────────────────────────────────────────────────

class _TypeIcon extends StatelessWidget {
  final String typeName;
  const _TypeIcon({required this.typeName});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (typeName.toLowerCase()) {
      'accommodation' => (Icons.hotel_rounded,      const Color(0xFF7C3AED)),
      'dining'        => (Icons.restaurant_rounded,  const Color(0xFFEA580C)),
      'transport'     => (Icons.directions_car_rounded, const Color(0xFF0369A1)),
      'flight'        => (Icons.flight_rounded,      const Color(0xFF0369A1)),
      'guide'         => (Icons.person_pin_rounded,  const Color(0xFF059669)),
      'special_arrangement' => (Icons.star_rounded,  const Color(0xFFC9A96E)),
      _               => (Icons.explore_rounded,     const Color(0xFF0891B2)),
    };

    return Container(
      width:  26,
      height: 26,
      decoration: BoxDecoration(
        color:        color.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

// ── Time block pill ────────────────────────────────────────────────────────────

class _TimeBlockPill extends StatelessWidget {
  final String  timeBlock;
  final String? startTime;
  final bool    isFixed;
  const _TimeBlockPill({required this.timeBlock, this.startTime, this.isFixed = false});

  @override
  Widget build(BuildContext context) {
    final label = startTime ?? _blockLabel(timeBlock);
    final color = isFixed
        ? const Color(0xFF0F766E)
        : AppColors.textMuted;
    final bg    = isFixed
        ? const Color(0xFFF0FDFA)
        : AppColors.surfaceAlt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color:      color,
          fontWeight: isFixed ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  String _blockLabel(String tb) => switch (tb.toLowerCase()) {
        'afternoon' => 'Afternoon',
        'evening'   => 'Evening',
        'all_day'   => 'All Day',
        _           => 'Morning',
      };
}

// ── Item context menu ──────────────────────────────────────────────────────────

class _ItemMenu extends StatelessWidget {
  final ProposedItineraryItem item;
  final VoidCallback          onRemove;
  final ValueChanged<String>  onEditTitle;
  final ValueChanged<String>  onEditTimeBlock;
  const _ItemMenu({
    required this.item,
    required this.onRemove,
    required this.onEditTitle,
    required this.onEditTimeBlock,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit')        _showEditDialog(context);
        if (value == 'remove')      onRemove();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove',
          child: Row(children: [
            Icon(Icons.remove_circle_outline_rounded, size: 14, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      child: Container(
        width:  28,
        height: 28,
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.more_horiz_rounded,
            size: 14, color: AppColors.textSecondary),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final titleCtrl  = TextEditingController(text: item.title);
    String timeBlock = item.timeBlock;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller:  titleCtrl,
                decoration:  const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Time Block', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: ['morning', 'afternoon', 'evening', 'all_day']
                    .map((tb) => ChoiceChip(
                          label:     Text(_tbLabel(tb)),
                          selected:  timeBlock == tb,
                          onSelected: (_) => setDialogState(() => timeBlock = tb),
                          selectedColor: AppColors.accentFaint,
                          labelStyle: AppTextStyles.labelSmall.copyWith(
                            color: timeBlock == tb
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newTitle = titleCtrl.text.trim();
                if (newTitle.isNotEmpty) onEditTitle(newTitle);
                onEditTimeBlock(timeBlock);
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _tbLabel(String tb) => switch (tb) {
        'afternoon' => 'Afternoon',
        'evening'   => 'Evening',
        'all_day'   => 'All Day',
        _           => 'Morning',
      };
}

// ── Day notes ──────────────────────────────────────────────────────────────────

class _DayNotes extends StatelessWidget {
  final List<String> pacingNotes;
  final List<String> routingNotes;
  const _DayNotes({required this.pacingNotes, required this.routingNotes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.md),
      decoration: const BoxDecoration(
        color:  Color(0xFFFAFAFA),
        border: Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(AppSpacing.cardRadius),
          bottomRight: Radius.circular(AppSpacing.cardRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in pacingNotes)
            _NoteRow(icon: Icons.timer_outlined, color: const Color(0xFF0891B2), text: note),
          for (final note in routingNotes)
            _NoteRow(icon: Icons.route_outlined, color: const Color(0xFFD97706), text: note),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _NoteRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.labelSmall.copyWith(
                color:  color,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
