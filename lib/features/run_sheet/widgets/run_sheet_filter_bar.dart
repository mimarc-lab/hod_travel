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

  void _updateQuery(String q) =>
      widget.provider.setFilter(widget.provider.filter.copyWith(query: q));

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

  void _clearAll() {
    _search.clear();
    widget.provider.clearFilter();
  }

  @override
  Widget build(BuildContext context) {
    final filter   = widget.provider.filter;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: isMobile
          ? _MobileLayout(
              search:         _search,
              filter:         filter,
              onSearch:       _updateQuery,
              onToggleStatus: _toggleStatus,
              onToggleType:   _toggleType,
              onClear:        _clearAll,
              provider:       widget.provider,
            )
          : _DesktopLayout(
              search:         _search,
              filter:         filter,
              onSearch:       _updateQuery,
              onToggleStatus: _toggleStatus,
              onToggleType:   _toggleType,
              onClear:        _clearAll,
              provider:       widget.provider,
            ),
    );
  }
}

// ── Desktop layout ─────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final TextEditingController search;
  final RunSheetFilter        filter;
  final ValueChanged<String>  onSearch;
  final ValueChanged<RunSheetStatus> onToggleStatus;
  final ValueChanged<ItemType>       onToggleType;
  final VoidCallback          onClear;
  final RunSheetProvider      provider;

  const _DesktopLayout({
    required this.search,
    required this.filter,
    required this.onSearch,
    required this.onToggleStatus,
    required this.onToggleType,
    required this.onClear,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 32,
            child: _SearchField(ctrl: search, onChanged: onSearch),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusChips(filter: filter, onToggle: onToggleStatus),
          const SizedBox(width: AppSpacing.sm),
          _TypeDropdown(
            selected:  filter.type,
            onChanged: onToggleType,
            onClear: () => provider
                .setFilter(filter.copyWith(clearType: true)),
          ),
          const Spacer(),
          if (filter.isActive)
            _ClearButton(onTap: onClear),
        ],
      ),
    );
  }
}

// ── Mobile layout ──────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final TextEditingController search;
  final RunSheetFilter        filter;
  final ValueChanged<String>  onSearch;
  final ValueChanged<RunSheetStatus> onToggleStatus;
  final ValueChanged<ItemType>       onToggleType;
  final VoidCallback          onClear;
  final RunSheetProvider      provider;

  const _MobileLayout({
    required this.search,
    required this.filter,
    required this.onSearch,
    required this.onToggleStatus,
    required this.onToggleType,
    required this.onClear,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: full-width search
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, 6),
          child: SizedBox(
            height: 36,
            child: _SearchField(ctrl: search, onChanged: onSearch),
          ),
        ),
        // Row 2: horizontally scrollable chips + type dropdown + clear
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
          child: Row(
            children: [
              _StatusChips(filter: filter, onToggle: onToggleStatus),
              const SizedBox(width: 6),
              _TypeDropdown(
                selected:  filter.type,
                onChanged: onToggleType,
                onClear: () => provider
                    .setFilter(filter.copyWith(clearType: true)),
              ),
              if (filter.isActive) ...[
                const SizedBox(width: 8),
                _ClearButton(onTap: onClear),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String>  onChanged;

  const _SearchField({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged:  onChanged,
      style:      AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText:  'Search items…',
        hintStyle: AppTextStyles.bodySmall,
        prefixIcon: const Icon(Icons.search_rounded,
            size: 14, color: AppColors.textMuted),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        isDense:   true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:   const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled:    true,
        fillColor: AppColors.surfaceAlt,
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  final RunSheetFilter             filter;
  final ValueChanged<RunSheetStatus> onToggle;

  const _StatusChips({required this.filter, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterChip(
          label:  'In Progress',
          active: filter.status == RunSheetStatus.inProgress,
          color:  RunSheetStatus.inProgress.color,
          onTap:  () => onToggle(RunSheetStatus.inProgress),
        ),
        const SizedBox(width: 5),
        _FilterChip(
          label:  'Delayed',
          active: filter.status == RunSheetStatus.delayed,
          color:  RunSheetStatus.delayed.color,
          onTap:  () => onToggle(RunSheetStatus.delayed),
        ),
        const SizedBox(width: 5),
        _FilterChip(
          label:  'Issue',
          active: filter.status == RunSheetStatus.issueFlagged,
          color:  RunSheetStatus.issueFlagged.color,
          onTap:  () => onToggle(RunSheetStatus.issueFlagged),
        ),
        const SizedBox(width: 5),
        _FilterChip(
          label:  'Completed',
          active: filter.status == RunSheetStatus.completed,
          color:  RunSheetStatus.completed.color,
          onTap:  () => onToggle(RunSheetStatus.completed),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color        color;
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        active ? color.withAlpha(20) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: active ? color.withAlpha(100) : AppColors.border,
            width: active ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color:      active ? color : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            fontSize:   11,
          ),
        ),
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final ItemType?              selected;
  final ValueChanged<ItemType> onChanged;
  final VoidCallback           onClear;

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
      tooltip:      'Filter by type',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        selected != null
              ? selected!.color.withAlpha(15)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: selected != null
                ? selected!.color.withAlpha(80)
                : AppColors.border,
            width: selected != null ? 1.2 : 0.8,
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
                color:      selected?.color ?? AppColors.textSecondary,
                fontWeight: selected != null ? FontWeight.w600 : FontWeight.w500,
                fontSize:   11,
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

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        'Clear',
        style: AppTextStyles.labelSmall.copyWith(
          color:      AppColors.accent,
          fontWeight: FontWeight.w600,
          fontSize:   12,
        ),
      ),
    );
  }
}
