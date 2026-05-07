import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/responsive_breakpoints.dart';
import '../design_system/spacing_tokens.dart';
import '../design_system/typography_tokens.dart';
import 'adaptive_column.dart';
import 'adaptive_row.dart';
import 'adaptive_row_actions.dart';

// ── Group model ───────────────────────────────────────────────────────────────

/// Describes one collapsible section in a grouped [AdaptiveTable].
class AdaptiveTableGroup<T> {
  final String title;
  final Color? accentColor;
  final List<T> items;
  final bool initiallyExpanded;

  const AdaptiveTableGroup({
    required this.title,
    required this.items,
    this.accentColor,
    this.initiallyExpanded = true,
  });

  int get count => items.length;
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// Adaptive table orchestrator.
///
/// Provide either [items] (flat list) or [groups] (sectioned list) — not both.
///
/// On **desktop / tablet**: renders a column-header row followed by [AdaptiveRow]
/// containers, each showing the columns appropriate for the current breakpoint.
///
/// On **mobile**: renders [AdaptiveRow] with primary columns only; callers may
/// supply a custom [mobileCardBuilder] to switch to [AdaptiveMobileCard] instead.
///
/// Screens that need highly custom mobile layouts (e.g. TaskCenterScreen) can
/// use [AdaptiveRow], [AdaptiveGroupHeader], and [AdaptiveMobileCard] directly
/// rather than using this orchestrator.
class AdaptiveTable<T> extends StatelessWidget {
  final List<T>? items;
  final List<AdaptiveTableGroup<T>>? groups;
  final List<AdaptiveColumn<T>> columns;
  final String Function(T) keyExtractor;
  final void Function(T)? onRowTap;
  final List<AdaptiveAction<T>>? actions;
  final bool showHeader;
  final EdgeInsets? padding;
  final Widget? emptyState;
  final bool isLoading;

  /// Optional: per-item accent bar colour derived from item data.
  final Color? Function(T)? accentBarBuilder;

  /// Static fallback accent bar colour (used when [accentBarBuilder] is null).
  final Color? accentBarColor;

  const AdaptiveTable({
    super.key,
    this.items,
    this.groups,
    required this.columns,
    required this.keyExtractor,
    this.onRowTap,
    this.actions,
    this.showHeader = true,
    this.padding,
    this.emptyState,
    this.isLoading = false,
    this.accentBarBuilder,
    this.accentBarColor,
  }) : assert(
          (items != null) ^ (groups != null),
          'Provide either items or groups, not both.',
        );

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.accent, strokeWidth: 2),
      );
    }

    final layout = AdaptiveBreakpoints.layoutOf(context);
    final allItems =
        items ?? groups!.expand((g) => g.items).toList();

    if (allItems.isEmpty && emptyState != null) {
      return emptyState!;
    }

    final hPad = switch (layout) {
      Layout.mobile  => 16.0,
      Layout.tablet  => 24.0,
      Layout.desktop => 32.0,
    };

    final effectivePadding =
        padding ?? EdgeInsets.fromLTRB(hPad, 16, hPad, 64);

    return ListView(
      padding: effectivePadding,
      children: [
        if (showHeader && layout != Layout.mobile)
          _ColumnHeaderRow<T>(
            columns: columns,
            layout: layout,
            hasActions: actions != null && actions!.isNotEmpty,
          ),
        if (groups != null)
          ..._buildGroups(layout)
        else
          ..._buildRows(items!, layout),
      ],
    );
  }

  // ── Group sections ──────────────────────────────────────────────────────

  List<Widget> _buildGroups(Layout layout) {
    final result = <Widget>[];
    for (int g = 0; g < groups!.length; g++) {
      result.add(
        _GroupSection<T>(
          group: groups![g],
          columns: columns,
          layout: layout,
          onRowTap: onRowTap,
          actions: actions,
          accentBarBuilder: accentBarBuilder,
          accentBarColor: accentBarColor,
          keyExtractor: keyExtractor,
        ),
      );
      if (g < groups!.length - 1) {
        result.add(const SizedBox(height: AdaptiveSpacing.groupGap));
      }
    }
    return result;
  }

  // ── Flat rows ──────────────────────────────────────────────────────────

  List<Widget> _buildRows(List<T> rowItems, Layout layout) {
    final result = <Widget>[];
    for (int i = 0; i < rowItems.length; i++) {
      result.add(_buildRow(rowItems[i], layout));
      if (i < rowItems.length - 1) {
        result.add(const SizedBox(height: AdaptiveSpacing.rowGap));
      }
    }
    return result;
  }

  Widget _buildRow(T item, Layout layout) {
    final accent = accentBarBuilder?.call(item) ?? accentBarColor;
    final actionsWidget = (actions != null && actions!.isNotEmpty)
        ? AdaptiveRowActions<T>(item: item, actions: actions!)
        : null;

    return AdaptiveRow<T>(
      key: ValueKey(keyExtractor(item)),
      item: item,
      columns: columns,
      layout: layout,
      onTap: onRowTap != null ? () => onRowTap!(item) : null,
      actionsWidget: actionsWidget,
      accentBar: accent,
    );
  }
}

// ── Column header row ─────────────────────────────────────────────────────────

class _ColumnHeaderRow<T> extends StatelessWidget {
  final List<AdaptiveColumn<T>> columns;
  final Layout layout;
  final bool hasActions;

  const _ColumnHeaderRow({
    required this.columns,
    required this.layout,
    required this.hasActions,
  });

  @override
  Widget build(BuildContext context) {
    final visible = columns.where((c) => c.visibleFor(layout)).toList();

    return Padding(
      // 3px accent bar offset + rowPaddingH alignment
      padding: const EdgeInsets.only(
        left: 19,
        right: AdaptiveSpacing.rowPaddingH,
        bottom: AdaptiveSpacing.groupBelowHeaderGap,
      ),
      child: Row(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: AdaptiveSpacing.columnGap),
            visible[i].sized(
              visible[i].hideLabel
                  ? const SizedBox.shrink()
                  : Text(visible[i].label,
                      style: AdaptiveTypography.columnHeader),
            ),
          ],
          if (hasActions)
            const SizedBox(width: AdaptiveSpacing.actionZoneWidth),
        ],
      ),
    );
  }
}

// ── Group section with collapse/expand ────────────────────────────────────────

class _GroupSection<T> extends StatefulWidget {
  final AdaptiveTableGroup<T> group;
  final List<AdaptiveColumn<T>> columns;
  final Layout layout;
  final void Function(T)? onRowTap;
  final List<AdaptiveAction<T>>? actions;
  final Color? Function(T)? accentBarBuilder;
  final Color? accentBarColor;
  final String Function(T) keyExtractor;

  const _GroupSection({
    required this.group,
    required this.columns,
    required this.layout,
    required this.keyExtractor,
    this.onRowTap,
    this.actions,
    this.accentBarBuilder,
    this.accentBarColor,
  });

  @override
  State<_GroupSection<T>> createState() => _GroupSectionState<T>();
}

class _GroupSectionState<T> extends State<_GroupSection<T>>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _expanded = widget.group.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _expanded ? 1.0 : 0.0,
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) { _ctrl.forward(); } else { _ctrl.reverse(); }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.group.accentColor ?? AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header tile
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AdaptiveSpacing.groupHeaderPaddingV,
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(widget.group.title,
                    style: AdaptiveTypography.groupHeaderLabel),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.group.count}',
                      style: AdaptiveTypography.groupCount),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),

        // Rows
        SizeTransition(
          sizeFactor: _expand,
          child: Padding(
            padding: const EdgeInsets.only(
                top: AdaptiveSpacing.groupBelowHeaderGap),
            child: Column(
              children: [
                for (int i = 0; i < widget.group.items.length; i++) ...[
                  _buildRow(widget.group.items[i]),
                  if (i < widget.group.items.length - 1)
                    const SizedBox(height: AdaptiveSpacing.rowGap),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(T item) {
    final accent =
        widget.accentBarBuilder?.call(item) ?? widget.accentBarColor;
    final actionsWidget =
        (widget.actions != null && widget.actions!.isNotEmpty)
            ? AdaptiveRowActions<T>(item: item, actions: widget.actions!)
            : null;

    return AdaptiveRow<T>(
      key: ValueKey(widget.keyExtractor(item)),
      item: item,
      columns: widget.columns,
      layout: widget.layout,
      onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
      actionsWidget: actionsWidget,
      accentBar: accent,
    );
  }
}
