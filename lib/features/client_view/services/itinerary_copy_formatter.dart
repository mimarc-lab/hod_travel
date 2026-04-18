import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryCopyFormatter — lightweight presentation helpers for the client view.
//
// Formats raw data into clean, calm, editorial display strings.
// No external dependencies — pure string transforms.
// ─────────────────────────────────────────────────────────────────────────────

abstract class ItineraryCopyFormatter {
  // ── Time ─────────────────────────────────────────────────────────────────────

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'am' : 'pm';
    return '$h:$m $p';
  }

  static String? formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null) return null;
    final s = formatTime(start);
    if (end == null) return s;
    // Omit second am/pm if same period
    if (start.period == end.period) {
      final h = end.hourOfPeriod == 0 ? 12 : end.hourOfPeriod;
      final m = end.minute.toString().padLeft(2, '0');
      final p = end.period == DayPeriod.am ? 'am' : 'pm';
      return '$s – $h:$m $p';
    }
    return '$s – ${formatTime(end)}';
  }

  // ── Location ──────────────────────────────────────────────────────────────────

  /// Returns location and supplier as a single clean meta string.
  /// e.g. "Urasenke Tea House · Kyoto" or just "Kyoto"
  static String? formatPlaceMeta({String? location, String? supplierName}) {
    final parts = <String>[];
    if (supplierName != null && supplierName.trim().isNotEmpty) {
      parts.add(supplierName.trim());
    }
    if (location != null && location.trim().isNotEmpty) {
      // Don't repeat if location is the same as supplier
      if (parts.isEmpty || location.trim() != supplierName?.trim()) {
        parts.add(location.trim());
      }
    }
    if (parts.isEmpty) return null;
    return parts.join('  ·  ');
  }

  // ── Description ───────────────────────────────────────────────────────────────

  /// Trims and returns the description as-is. Use in-place of raw null checks.
  static String? formatDescription(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  // ── Feature list ─────────────────────────────────────────────────────────────

  /// Takes a multi-line or bullet-formatted list and returns it as a
  /// dot-separated single line suitable for accommodation feature blocks.
  /// e.g. "- Pool\n- Spa\n- Butler" → "Pool · Spa · Butler"
  static String? formatFeatureList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final lines = raw
        .split(RegExp(r'[\n•\-]'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    return lines.join('  ·  ');
  }

  // ── Type label ────────────────────────────────────────────────────────────────

  /// Returns an understated uppercase type label for display, or null if
  /// the type should not be shown (e.g. accommodation handled separately).
  static String? typeLabel(String typeDbValue) => switch (typeDbValue) {
        'experience' => 'EXPERIENCE',
        'dining'     => 'DINING',
        'transport'  => 'TRANSPORT',
        'flight'     => 'FLIGHT',
        'note'       => null, // notes shown without type label
        _            => null, // hotel handled by AccommodationFeatureSection
      };
}
