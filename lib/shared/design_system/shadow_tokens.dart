import 'package:flutter/material.dart';

/// Two-entry BoxShadow pairs for smooth Flutter interpolation.
/// Each state (resting / hover) has the same number of shadows so
/// AnimatedContainer transitions cleanly without a shadow count mismatch.
abstract class AdaptiveShadows {
  // ── Row (desktop / tablet inline row) ────────────────────────────────────
  static const List<BoxShadow> rowResting = [
    BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
    BoxShadow(color: Color(0x04000000), blurRadius: 8,  offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> rowHover = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x06000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // ── Card (mobile / tablet card layout) ───────────────────────────────────
  static const List<BoxShadow> cardResting = [
    BoxShadow(color: Color(0x06000000), blurRadius: 8,  offset: Offset(0, 2)),
    BoxShadow(color: Color(0x04000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x0E000000), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x08000000), blurRadius: 32, offset: Offset(0, 10)),
  ];
}
