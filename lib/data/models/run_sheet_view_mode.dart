import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetViewMode — domain enum for role-based run sheet projections.
// One data source, multiple filtered views depending on the viewer's role.
// ─────────────────────────────────────────────────────────────────────────────

enum RunSheetViewMode {
  director,    // Full view — all items, all notes, all controls
  driver,      // Transport + flights only — logistics + transport notes
  guide,       // Experiences only — guide notes visible
  operations,  // All items — ops + logistics notes, no hidden internal detail
}

extension RunSheetViewModeInfo on RunSheetViewMode {
  String get label => switch (this) {
    RunSheetViewMode.director   => 'Trip Director',
    RunSheetViewMode.driver     => 'Driver',
    RunSheetViewMode.guide      => 'Guide',
    RunSheetViewMode.operations => 'Operations',
  };

  String get description => switch (this) {
    RunSheetViewMode.director   => 'Full run sheet — all items and notes',
    RunSheetViewMode.driver     => 'Transport & flight items — logistics notes',
    RunSheetViewMode.guide      => 'Experience items — guide-specific notes',
    RunSheetViewMode.operations => 'All items — ops and logistics details',
  };

  String get accessScope => switch (this) {
    RunSheetViewMode.director   => 'Full access',
    RunSheetViewMode.driver     => 'Transport only',
    RunSheetViewMode.guide      => 'Activities only',
    RunSheetViewMode.operations => 'All items, operational detail',
  };

  IconData get icon => switch (this) {
    RunSheetViewMode.director   => Icons.manage_accounts_rounded,
    RunSheetViewMode.driver     => Icons.directions_car_rounded,
    RunSheetViewMode.guide      => Icons.hiking_rounded,
    RunSheetViewMode.operations => Icons.settings_rounded,
  };

  Color get color => switch (this) {
    RunSheetViewMode.director   => const Color(0xFF7C3AED),
    RunSheetViewMode.driver     => const Color(0xFF1D4ED8),
    RunSheetViewMode.guide      => const Color(0xFF065F46),
    RunSheetViewMode.operations => const Color(0xFFC9A96E),
  };

  Color get bgColor => switch (this) {
    RunSheetViewMode.director   => const Color(0xFFF5F3FF),
    RunSheetViewMode.driver     => const Color(0xFFEFF6FF),
    RunSheetViewMode.guide      => const Color(0xFFF0FDF4),
    RunSheetViewMode.operations => const Color(0xFFFDF8F0),
  };

  String get dbValue => switch (this) {
    RunSheetViewMode.director   => 'director',
    RunSheetViewMode.driver     => 'driver',
    RunSheetViewMode.guide      => 'guide',
    RunSheetViewMode.operations => 'operations',
  };

  /// Whether this is a restricted (non-director) view.
  bool get isRestricted => this != RunSheetViewMode.director;

  static RunSheetViewMode fromDb(String raw) => switch (raw) {
    'driver'     => RunSheetViewMode.driver,
    'guide'      => RunSheetViewMode.guide,
    'operations' => RunSheetViewMode.operations,
    _            => RunSheetViewMode.director,
  };
}
