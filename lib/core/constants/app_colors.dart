import 'package:flutter/material.dart';

/// HOD Travel — central color palette.
/// All colors are defined here and referenced throughout the app.
abstract class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F7F5);   // warm off-white canvas
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F3F1);   // subtle card tint

  // ── Sidebar ───────────────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF111318);
  static const Color sidebarActiveBg = Color(0xFF1E2028);
  static const Color sidebarText = Color(0xFF8A8F9E);
  static const Color sidebarActiveText = Color(0xFFFFFFFF);
  static const Color sidebarIcon = Color(0xFF5A5F6E);
  static const Color sidebarActiveIcon = Color(0xFFC9A96E);
  static const Color sidebarDivider = Color(0xFF1E2028);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111318);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Borders & Dividers ────────────────────────────────────────────────────
  static const Color border = Color(0xFFE8E7E5);
  static const Color divider = Color(0xFFF0EFED);
  static const Color borderSubtle = Color(0xFFF2F1EF);

  // ── Accent (gold) ─────────────────────────────────────────────────────────
  static const Color accent = Color(0xFFC9A96E);
  static const Color accentDark = Color(0xFFB8955A);
  static const Color accentLight = Color(0xFFF7EDD8);
  static const Color accentFaint = Color(0xFFFDF8F0);

  // ── Task / Trip Status ────────────────────────────────────────────────────
  static const Color statusNotStarted = Color(0xFFE5E7EB);
  static const Color statusNotStartedText = Color(0xFF6B7280);
  static const Color statusInProgress = Color(0xFFDBEAFE);
  static const Color statusInProgressText = Color(0xFF1D4ED8);
  static const Color statusDone = Color(0xFFD1FAE5);
  static const Color statusDoneText = Color(0xFF065F46);
  static const Color statusBlocked = Color(0xFFFEE2E2);
  static const Color statusBlockedText = Color(0xFF991B1B);
  static const Color statusWaiting = Color(0xFFFEF3C7);
  static const Color statusWaitingText = Color(0xFF92400E);
  static const Color statusOnHold = Color(0xFFF3F4F6);
  static const Color statusOnHoldText = Color(0xFF374151);

  // ── Priority ─────────────────────────────────────────────────────────────
  static const Color priorityLow = Color(0xFFD1FAE5);
  static const Color priorityLowText = Color(0xFF065F46);
  static const Color priorityMedium = Color(0xFFDBEAFE);
  static const Color priorityMediumText = Color(0xFF1D4ED8);
  static const Color priorityHigh = Color(0xFFFEF3C7);
  static const Color priorityHighText = Color(0xFF92400E);
  static const Color priorityUrgent = Color(0xFFFEE2E2);
  static const Color priorityUrgentText = Color(0xFF991B1B);

  // ── Cost Status ───────────────────────────────────────────────────────────
  static const Color costNotCosted = Color(0xFFE5E7EB);
  static const Color costNotCostedText = Color(0xFF6B7280);
  static const Color costEstimated = Color(0xFFFEF3C7);
  static const Color costEstimatedText = Color(0xFF92400E);
  static const Color costConfirmed = Color(0xFFD1FAE5);
  static const Color costConfirmedText = Color(0xFF065F46);
  static const Color costInvoiced = Color(0xFFDBEAFE);
  static const Color costInvoicedText = Color(0xFF1D4ED8);

  // ── Utility ───────────────────────────────────────────────────────────────
  static const Color shadow = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
  static const Color overlay = Color(0x80000000);
}
