/// Spacing scale for the HOD Travel adaptive table system.
/// All values follow a 4px grid inherited from AppSpacing, but scoped to
/// operational data display rather than page layout.
abstract class AdaptiveSpacing {
  // ── Row ──────────────────────────────────────────────────────────────────
  static const double rowGap           = 6.0;   // vertical gap between rows
  static const double rowPaddingH      = 16.0;  // left/right inside a row
  static const double rowPaddingV      = 12.0;  // top/bottom inside a row
  static const double rowPaddingHCompact = 12.0;
  static const double rowPaddingVCompact = 8.0;

  // ── Table header ─────────────────────────────────────────────────────────
  static const double headerPaddingV   = 10.0;

  // ── Column ───────────────────────────────────────────────────────────────
  static const double columnGap        = 12.0;  // horizontal gap between cols

  // ── Group section ────────────────────────────────────────────────────────
  static const double groupGap            = 20.0; // gap between group sections
  static const double groupHeaderPaddingH = 4.0;
  static const double groupHeaderPaddingV = 6.0;
  static const double groupBelowHeaderGap = 6.0;  // between header and first row

  // ── Chip ─────────────────────────────────────────────────────────────────
  static const double chipPaddingH        = 10.0;
  static const double chipPaddingV        = 4.0;
  static const double chipPaddingHCompact = 8.0;
  static const double chipPaddingVCompact = 3.0;

  // ── Action zone ──────────────────────────────────────────────────────────
  static const double actionIconSize   = 16.0;
  static const double actionGap        = 4.0;
  static const double actionZoneWidth  = 28.0;  // width reserved for menu icon
}
