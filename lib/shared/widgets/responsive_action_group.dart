import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import 'app_action.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResponsiveActionGroup
// ─────────────────────────────────────────────────────────────────────────────

/// Responsive layout for a group of 1–4 [AppAction] buttons.
///
/// **Desktop / tablet (>= 600 px)**
/// Horizontal row, natural width, right-aligned when used in a flex context.
/// Consistent [gap] between buttons.
///
/// **Mobile (< 600 px)**
/// - 1 button  : natural width (or full-width when [fillWidthOnMobile] = true)
/// - 2 buttons : each takes 50 % of available width
/// - 3 buttons : configurable via [primaryFullWidthFirst]
///   - true  → first button full-width, second+third share a row below
///   - false → first+second share a row, third is full-width below
///
/// When [fillWidthOnMobile] is false (the default), all breakpoints render the
/// group at natural (min-intrinsic) width. Use this inside headers and toolbars
/// where the surrounding Row already manages horizontal space.
class ResponsiveActionGroup extends StatelessWidget {
  final List<AppAction> actions;

  /// Gap between adjacent buttons (horizontal or vertical).
  final double gap;

  /// Mobile-only layout rule for 3-button groups.
  /// true  = primary button full-width on top, secondary pair below.
  /// false = secondary pair on top, last button full-width below.
  final bool primaryFullWidthFirst;

  /// When true, a single-button group stretches to fill available width on
  /// mobile. Also enables the 50/50 and stacked layouts for 2+ buttons.
  /// Set to false (default) when inside a Row alongside other widgets.
  final bool fillWidthOnMobile;

  const ResponsiveActionGroup({
    super.key,
    required this.actions,
    this.gap = 10,
    this.primaryFullWidthFirst = false,
    this.fillWidthOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final isMobile = Responsive.isMobile(context);
    final fill = fillWidthOnMobile && isMobile;

    // ── Desktop / tablet — or mobile without fill ─────────────────────────────
    if (!fill) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            AppActionButton(action: actions[i]),
          ],
        ],
      );
    }

    // ── Mobile with fill ──────────────────────────────────────────────────────
    if (actions.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: AppActionButton(action: actions.first),
      );
    }

    if (actions.length == 2) {
      return Row(
        children: [
          Expanded(child: AppActionButton(action: actions[0])),
          SizedBox(width: gap),
          Expanded(child: AppActionButton(action: actions[1])),
        ],
      );
    }

    // 3 buttons
    final a = actions;

    if (primaryFullWidthFirst) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppActionButton(action: a[0]),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: AppActionButton(action: a[1])),
              SizedBox(width: gap),
              Expanded(child: AppActionButton(action: a[2])),
            ],
          ),
        ],
      );
    }

    // Default: pair on top, last full-width below.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: AppActionButton(action: a[0])),
            SizedBox(width: gap),
            Expanded(child: AppActionButton(action: a[1])),
          ],
        ),
        SizedBox(height: gap),
        AppActionButton(action: a[2]),
      ],
    );
  }
}
