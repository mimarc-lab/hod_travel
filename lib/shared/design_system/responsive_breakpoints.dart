import 'package:flutter/material.dart';

/// Layout tier resolved from screen width.
/// Used by AdaptiveTable, AdaptiveRow, and AdaptiveColumn to determine
/// which columns are visible and which layout variant to render.
enum Layout { mobile, tablet, desktop }

/// Screen-width breakpoints for the HOD Travel adaptive table system.
abstract class AdaptiveBreakpoints {
  static const double mobile = 600.0;
  static const double tablet = 1024.0;

  static Layout layoutOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < mobile) return Layout.mobile;
    if (w < tablet) return Layout.tablet;
    return Layout.desktop;
  }

  static bool isMobile(BuildContext context) =>
      layoutOf(context) == Layout.mobile;

  static bool isTablet(BuildContext context) =>
      layoutOf(context) == Layout.tablet;

  static bool isDesktop(BuildContext context) =>
      layoutOf(context) == Layout.desktop;

  /// True when secondary columns (dates, assignee, etc.) should collapse.
  static bool collapseSecondary(BuildContext context) => isMobile(context);

  /// True when tertiary columns (IDs, notes, timestamps) should hide.
  static bool collapseTertiary(BuildContext context) => !isDesktop(context);
}
