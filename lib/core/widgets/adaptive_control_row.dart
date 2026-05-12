import 'package:flutter/material.dart';

/// A horizontal row that distributes its children across the full available
/// width using [Expanded], separated by a consistent gap.
///
/// Replaces the [Row] + [Spacer] anti-pattern that leaves dead space between
/// controls. All children expand proportionally by default (flex = 1 each).
/// Pass [flexValues] to assign different weights, e.g. flex:1 for a filter
/// button and flex:2 for a search field.
///
/// Example — equal split:
/// ```dart
/// AdaptiveControlRow(
///   children: [StatusFilterButton(), AddButton()],
/// )
/// ```
///
/// Example — uneven priority:
/// ```dart
/// AdaptiveControlRow(
///   flexValues: const [1, 2],
///   children: [StatusFilterButton(), SearchField()],
/// )
/// ```
class AdaptiveControlRow extends StatelessWidget {
  final List<Widget> children;

  /// Optional flex weight for each child. Index must match [children].
  /// Defaults to 1 for any child without a corresponding entry.
  final List<int>? flexValues;

  /// Horizontal gap between items. Defaults to 12.
  final double gap;

  const AdaptiveControlRow({
    super.key,
    required this.children,
    this.flexValues,
    this.gap = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final List<Widget> row = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) row.add(SizedBox(width: gap));
      final flex =
          (flexValues != null && i < flexValues!.length) ? flexValues![i] : 1;
      row.add(Expanded(flex: flex, child: children[i]));
    }
    return Row(children: row);
  }
}
