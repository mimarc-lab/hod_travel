import 'package:flutter/material.dart';

/// Breakpoints and helpers for responsive layout.
abstract class Responsive {
  static const double mobileBreak = 600.0;
  static const double tabletBreak = 960.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreak;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreak && w < tabletBreak;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreak;

  /// Sidebar is visible on tablet and above.
  static bool showSidebar(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreak;
}
