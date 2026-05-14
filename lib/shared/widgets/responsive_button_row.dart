import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/responsive.dart';
import 'app_action.dart';
import 'overflow_action_menu.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResponsiveButtonRow
// ─────────────────────────────────────────────────────────────────────────────

/// A toolbar row with an optional [leading] widget (e.g., title, day selector,
/// search box) and a set of [AppAction] buttons on the right.
///
/// **Desktop / tablet (>= 600 px)**
/// ```
/// [ leading ]  ···  Spacer  ···  [ action1 ][ action2 ][ overflowAction1 ]
/// ```
/// All [actions] and [overflowActions] are shown inline as full-label buttons.
///
/// **Mobile (< 600 px)**
/// ```
/// [ ← leading fills remaining width → ]  [ icon1 ][ icon2 ][ ⋯ ]
/// ```
/// - [actions] render as compact (icon-only) buttons.
/// - [overflowActions] collapse into an [OverflowActionMenu].
/// - [leading] is wrapped in [Expanded] when [expandLeadingOnMobile] is true.
class ResponsiveButtonRow extends StatelessWidget {
  /// Left-side widget (title, search box, day picker, etc.).
  final Widget? leading;

  /// When true (default), wraps [leading] in an [Expanded] on mobile so it
  /// fills the space to the left of the action buttons.
  final bool expandLeadingOnMobile;

  /// Always-visible action buttons. Rendered compact (icon-only) on mobile,
  /// full-label on desktop.
  final List<AppAction> actions;

  /// Actions shown inline on desktop; collapsed into an [OverflowActionMenu]
  /// on mobile.
  final List<AppAction> overflowActions;

  /// Gap between buttons (and between [leading] and the first button).
  final double gap;

  const ResponsiveButtonRow({
    super.key,
    this.leading,
    this.expandLeadingOnMobile = true,
    required this.actions,
    this.overflowActions = const [],
    this.gap = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final List<Widget> children = [];

    // ── Leading ───────────────────────────────────────────────────────────────
    if (leading != null) {
      children.add(
        isMobile && expandLeadingOnMobile
            ? Expanded(child: leading!)
            : leading!,
      );
      if (!isMobile) children.add(const Spacer());
    }

    // ── Primary actions ───────────────────────────────────────────────────────
    for (int i = 0; i < actions.length; i++) {
      if (i > 0 || leading != null) children.add(SizedBox(width: gap));
      children.add(
        AppActionButton(
          action:  actions[i],
          compact: isMobile,
        ),
      );
    }

    // ── Overflow actions ──────────────────────────────────────────────────────
    if (overflowActions.isNotEmpty) {
      if (isMobile) {
        children.add(SizedBox(width: gap));
        children.add(OverflowActionMenu(actions: overflowActions));
      } else {
        for (final a in overflowActions) {
          children.add(SizedBox(width: gap));
          children.add(AppActionButton(action: a));
        }
      }
    }

    return Row(children: children);
  }
}
