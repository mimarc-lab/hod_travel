import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// Typography scale for the adaptive table system.
/// All styles use Inter via google_fonts — consistent with AppTextStyles.
abstract class AdaptiveTypography {
  // ── Column header row ─────────────────────────────────────────────────────
  static TextStyle get columnHeader => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
        height: 1.4,
      );

  // ── Primary cell — entity name, task/trip title ───────────────────────────
  static TextStyle get primaryCell => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  /// Second line beneath primary cell (sub-label, trip name, etc.)
  static TextStyle get primarySubCell => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.3,
      );

  // ── Secondary cell — dates, locations, assignee names ────────────────────
  static TextStyle get secondaryCell => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ── Tertiary cell — timestamps, IDs, internal metadata ───────────────────
  static TextStyle get tertiaryCell => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.4,
      );

  // ── Group section header ──────────────────────────────────────────────────
  static TextStyle get groupHeaderLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.1,
        height: 1.4,
      );

  /// Count badge inside group header
  static TextStyle get groupCount => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        height: 1.4,
      );

  // ── Chip labels ───────────────────────────────────────────────────────────
  static TextStyle get chipLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );

  static TextStyle get chipLabelCompact => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
      );
}
