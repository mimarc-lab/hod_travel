import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../providers/run_sheet_provider.dart';

class RunSheetFilterBar extends StatefulWidget {
  final RunSheetProvider provider;
  const RunSheetFilterBar({super.key, required this.provider});

  @override
  State<RunSheetFilterBar> createState() => _RunSheetFilterBarState();
}

class _RunSheetFilterBarState extends State<RunSheetFilterBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.provider.filter.query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _updateQuery(String q) {
    widget.provider.setFilter(widget.provider.filter.copyWith(query: q));
  }

  void _toggleStatus(RunSheetStatus s) {
    final current = widget.provider.filter.status;
    widget.provider.setFilter(
      current == s
          ? widget.provider.filter.copyWith(clearStatus: true)
          : widget.provider.filter.copyWith(status: s),
    );
  }

  void _toggleType(ItemType t) {
    final current = widget.provider.filter.type;
    widget.provider.setFilter(
      current == t
          ? widget.provider.filter.copyWith(clearType: true)
          : widget.provider.filter.copyWith(type: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.provider.filter;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical:   AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Search box
          SizedBox(
            width: 200,
            height: 32,
            child: TextField(
              controller: _search,
              onChanged:  _updateQuery,
              style:      AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:        'Search items…',
                hintStyle:       AppTextStyles.bodySmall,
                prefixIcon:      const Icon(Icons.search_rounded,
                    size: 14, color: AppColors.textMuted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                contentPadding:  const EdgeInsets.symmetric(vertical: 6),
                isDense:         true,
                border:          OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                enabledBorder:   OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:   const BorderSide(color: AppColors.border),
                ),
                focusedBorder:   OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:   const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                filled:    true,
                fillColor: AppColors.surfaceAlt,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Status chips
          Wrap(
            spacing: 4,
            children: [
              _FilterChip(
                label:    'In Progress',
                active:   filter.status == RunSheetStatus.inProgress,
                color:    RunSheetStatus.inProgress.color,
                onTap:    () => _toggleStatus(RunSheetStatus.inProgress),
              ),
              _FilterChip(
                label:    'Delayed',
                active:   filter.status == RunSheetStatus.delayed,
                color:    RunSheetStatus.delayed.color,
                onTap:    () => _toggleStatus(RunSheetStatus.delayed),
              ),
              _FilterChip(
                label:    'Issue',
                active:   filter.status == RunSheetStatus.issueFlagged,
                color:    RunSheetStatus.issueFlagged.color,
                onTap:    () => _toggleStatus(RunSheetStatus.issueFlagged),
              ),
              _FilterChip(
                label:    'Completed',
                active:   filter.status == RunSheetStatus.completed,
                color:    RunSheetStatus.completed.color,
                onTap:    () => _toggleStatus(RunSheetStatus.completed),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),

          // Type filter
          _TypeDropdown(
            selected: filter.type,
            onChanged: _toggleType,
            onClear: () => widget.provider
                .setFilter(filter.copyWith(clearType: true)),
          ),

          const Spacer(),

          // Clear all
          if (filter.isActive)
            TextButton(
              onPressed: () {
                _search.clear();
                widget.provider.clearFilter();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final Color  color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        active ? color.withAlpha(20) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: active ? color.withAlpha(100) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:      active ? color : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final ItemType?    selected;
  final ValueChanged<ItemType> onChanged;
  final VoidCallback onClear;

  const _TypeDropdown({
    required this.selected,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ItemType>(
      initialValue: selected,
      onSelected:   onChanged,
      tooltip: 'Filter by type',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => ItemType.values.map((t) => PopupMenuItem(
        value: t,
        child: Row(
          children: [
            Icon(t.icon, size: 13, color: t.color),
            const SizedBox(width: 8),
            Text(t.label, style: const TextStyle(fontSize: 13)),
            if (selected == t) ...[
              const Spacer(),
              const Icon(Icons.check_rounded, size: 13),
            ],
          ],
        ),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        selected != null
              ? selected!.color.withAlpha(15)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(
            color: selected != null
                ? selected!.color.withAlpha(80)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected?.icon ?? Icons.category_outlined,
              size:  13,
              color: selected?.color ?? AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              selected?.label ?? 'Type',
              style: AppTextStyles.labelSmall.copyWith(
                color: selected?.color ?? AppColors.textSecondary,
                fontWeight: selected != null ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size:  13,
              color: selected?.color ?? AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
