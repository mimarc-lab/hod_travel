import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientViewTheme — editorial design tokens for the client-facing layer.
//
// Intentionally separate from the internal ops design system so both can
// evolve independently. The client layer aims for luxury editorial calm;
// the ops layer optimises for information density and action.
// ─────────────────────────────────────────────────────────────────────────────

abstract class ClientViewTheme {
  // ── Page layout ──────────────────────────────────────────────────────────────
  static const double pageHPadNarrow = 24.0;
  static const double pageHPadWide   = 80.0;
  static const double headerVPad     = 56.0;
  static const double dayTopGap      = 56.0;
  static const double dayBottomGap   = 48.0;
  static const double itemSpacing    = 28.0;
  static const double accomTopPad    = 36.0;

  // ── Palette ───────────────────────────────────────────────────────────────────
  static const Color gold      = AppColors.accent;       // #C9A96E
  static const Color goldFaint = AppColors.accentFaint;  // #FDF8F0
  static const Color ink       = AppColors.textPrimary;  // #111318
  static const Color secondary = AppColors.textSecondary;// #6B7280
  static const Color muted     = AppColors.textMuted;    // #9CA3AF
  static const Color hairline  = Color(0xFFECEBE8);      // lighter than border
  static const Color pageBg    = AppColors.background;   // #F8F7F5
  static const Color surface   = AppColors.surface;      // #FFFFFF

  // ── Trip header ───────────────────────────────────────────────────────────────

  static final TextStyle eyebrow = GoogleFonts.inter(
    fontSize:    10.5,
    fontWeight:  FontWeight.w500,
    color:       gold,
    letterSpacing: 2.8,
  );

  static final TextStyle tripName = GoogleFonts.inter(
    fontSize:    38,
    fontWeight:  FontWeight.w300,
    color:       ink,
    letterSpacing: -0.8,
    height:      1.15,
  );

  static final TextStyle tripDates = GoogleFonts.inter(
    fontSize:   15,
    fontWeight: FontWeight.w400,
    color:      ink,
    height:     1.4,
  );

  static final TextStyle tripMeta = GoogleFonts.inter(
    fontSize:   13.5,
    fontWeight: FontWeight.w400,
    color:      secondary,
    height:     1.4,
  );

  static final TextStyle managerLabel = GoogleFonts.inter(
    fontSize:    10,
    fontWeight:  FontWeight.w500,
    color:       muted,
    letterSpacing: 1.8,
  );

  static final TextStyle managerName = GoogleFonts.inter(
    fontSize:   14,
    fontWeight: FontWeight.w500,
    color:      ink,
  );

  static final TextStyle managerSub = GoogleFonts.inter(
    fontSize:   12,
    fontWeight: FontWeight.w400,
    color:      muted,
  );

  // ── Day chapter ───────────────────────────────────────────────────────────────

  static final TextStyle dayLabel = GoogleFonts.inter(
    fontSize:    10,
    fontWeight:  FontWeight.w600,
    color:       gold,
    letterSpacing: 2.5,
  );

  static final TextStyle cityName = GoogleFonts.inter(
    fontSize:    26,
    fontWeight:  FontWeight.w300,
    color:       ink,
    letterSpacing: -0.3,
    height:      1.2,
  );

  static final TextStyle dayDate = GoogleFonts.inter(
    fontSize:    10.5,
    fontWeight:  FontWeight.w400,
    color:       muted,
    letterSpacing: 0.8,
  );

  static final TextStyle dayIntro = GoogleFonts.inter(
    fontSize:   13,
    fontWeight: FontWeight.w300,
    color:      secondary,
    fontStyle:  FontStyle.italic,
    height:     1.55,
  );

  // ── Itinerary items ───────────────────────────────────────────────────────────

  static final TextStyle itemTime = GoogleFonts.inter(
    fontSize:    10.5,
    fontWeight:  FontWeight.w400,
    color:       muted,
    letterSpacing: 0.3,
  );

  static final TextStyle itemTypeLabel = GoogleFonts.inter(
    fontSize:    10,
    fontWeight:  FontWeight.w500,
    color:       muted,
    letterSpacing: 1.5,
  );

  static final TextStyle itemTitle = GoogleFonts.inter(
    fontSize:   15.5,
    fontWeight: FontWeight.w500,
    color:      ink,
    height:     1.3,
  );

  static final TextStyle itemDescription = GoogleFonts.inter(
    fontSize:   13.5,
    fontWeight: FontWeight.w300,
    color:      secondary,
    height:     1.65,
  );

  static final TextStyle itemMeta = GoogleFonts.inter(
    fontSize:    10.5,
    fontWeight:  FontWeight.w400,
    color:       muted,
    letterSpacing: 0.2,
  );

  // ── Accommodation ─────────────────────────────────────────────────────────────

  static final TextStyle accomLabel = GoogleFonts.inter(
    fontSize:    10,
    fontWeight:  FontWeight.w500,
    color:       gold,
    letterSpacing: 2.2,
  );

  static final TextStyle accomName = GoogleFonts.inter(
    fontSize:    20,
    fontWeight:  FontWeight.w300,
    color:       ink,
    letterSpacing: -0.2,
    height:      1.2,
  );

  static final TextStyle accomDesc = GoogleFonts.inter(
    fontSize:   13,
    fontWeight: FontWeight.w300,
    color:      secondary,
    fontStyle:  FontStyle.italic,
    height:     1.6,
  );

  static final TextStyle accomFeatures = GoogleFonts.inter(
    fontSize:   11,
    fontWeight: FontWeight.w400,
    color:      muted,
    height:     1.5,
  );
}
