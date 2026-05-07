import 'package:flutter/material.dart';
import '../design_system/responsive_breakpoints.dart';

/// Visual importance tier — controls column visibility per breakpoint:
///   primary   → always visible
///   secondary → tablet + desktop only
///   tertiary  → desktop only
enum ColumnPriority { primary, secondary, tertiary }

enum ColumnAlignment { start, center, end }

/// Describes one column in an AdaptiveTable.
///
/// Provide either [width] (fixed pixels) or [flex] (proportional share).
/// The [builder] receives the row item and returns the cell widget.
class AdaptiveColumn<T> {
  final String key;
  final String label;
  final ColumnPriority priority;
  final double? width;   // fixed px — takes precedence over flex
  final double? flex;    // proportional flex factor
  final ColumnAlignment alignment;
  final Widget Function(T item) builder;
  final bool sortable;
  final bool hideLabel;  // suppress column header text (e.g. actions column)

  const AdaptiveColumn({
    required this.key,
    required this.label,
    required this.priority,
    required this.builder,
    this.width,
    this.flex,
    this.alignment = ColumnAlignment.start,
    this.sortable = false,
    this.hideLabel = false,
  });

  /// Whether this column should render at the given [layout] tier.
  bool visibleFor(Layout layout) => switch (priority) {
        ColumnPriority.primary   => true,
        ColumnPriority.secondary => layout != Layout.mobile,
        ColumnPriority.tertiary  => layout == Layout.desktop,
      };

  Alignment get _alignment => switch (alignment) {
        ColumnAlignment.start  => Alignment.centerLeft,
        ColumnAlignment.center => Alignment.center,
        ColumnAlignment.end    => Alignment.centerRight,
      };

  /// Wraps the cell in either a fixed [SizedBox] or an [Expanded].
  Widget sized(Widget cell) {
    final aligned = Align(alignment: _alignment, child: cell);
    if (width != null) return SizedBox(width: width, child: aligned);
    return Expanded(flex: (flex ?? 1.0).round(), child: aligned);
  }
}
