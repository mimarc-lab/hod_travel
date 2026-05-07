import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/radius_tokens.dart';
import '../design_system/shadow_tokens.dart';
import '../design_system/spacing_tokens.dart';
import '../design_system/responsive_breakpoints.dart';
import 'adaptive_column.dart';

/// The core desktop/tablet row container.
///
/// Renders columns horizontally using the [AdaptiveColumn] definitions,
/// filtering to only those visible at the current [layout] tier.
/// Provides hover lift (−2px Y), two-shadow system, white background,
/// rounded corners, and an optional left accent bar.
///
/// The row action widget (popup menu) fades in on hover and is invisible
/// at rest — avoiding always-visible action clutter.
class AdaptiveRow<T> extends StatefulWidget {
  final T item;
  final List<AdaptiveColumn<T>> columns;
  final Layout layout;
  final VoidCallback? onTap;
  final Widget? actionsWidget;
  final Color? accentBar;

  const AdaptiveRow({
    super.key,
    required this.item,
    required this.columns,
    required this.layout,
    this.onTap,
    this.actionsWidget,
    this.accentBar,
  });

  @override
  State<AdaptiveRow<T>> createState() => _AdaptiveRowState<T>();
}

class _AdaptiveRowState<T> extends State<AdaptiveRow<T>> {
  bool _hovered = false;

  List<AdaptiveColumn<T>> get _visible =>
      widget.columns.where((c) => c.visibleFor(widget.layout)).toList();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AdaptiveRadius.rowBorder,
            boxShadow:
                _hovered ? AdaptiveShadows.rowHover : AdaptiveShadows.rowResting,
          ),
          child: ClipRRect(
            borderRadius: AdaptiveRadius.rowBorder,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left accent bar
                  if (widget.accentBar != null)
                    Container(width: 3, color: widget.accentBar),

                  // Column cells
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdaptiveSpacing.rowPaddingH,
                        vertical: AdaptiveSpacing.rowPaddingV,
                      ),
                      child: Row(
                        children: _buildCells(),
                      ),
                    ),
                  ),

                  // Row actions — fades in on hover
                  if (widget.actionsWidget != null)
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 140),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: widget.actionsWidget,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCells() {
    final cols = _visible;
    final result = <Widget>[];
    for (int i = 0; i < cols.length; i++) {
      result.add(cols[i].sized(cols[i].builder(widget.item)));
      if (i < cols.length - 1) {
        result.add(const SizedBox(width: AdaptiveSpacing.columnGap));
      }
    }
    return result;
  }
}
