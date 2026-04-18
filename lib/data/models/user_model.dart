import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppRole — permission tier for each team member
// ─────────────────────────────────────────────────────────────────────────────

enum AppRole { admin, tripLead, staff, finance }

extension AppRoleDisplay on AppRole {
  String get label {
    switch (this) {
      case AppRole.admin:    return 'Admin';
      case AppRole.tripLead: return 'Trip Lead';
      case AppRole.staff:    return 'Staff';
      case AppRole.finance:  return 'Finance';
    }
  }

  String get dbValue {
    switch (this) {
      case AppRole.admin:    return 'admin';
      case AppRole.tripLead: return 'trip_lead';
      case AppRole.staff:    return 'staff';
      case AppRole.finance:  return 'finance';
    }
  }

  String get description {
    switch (this) {
      case AppRole.admin:
        return 'Full access to all modules and approval actions';
      case AppRole.tripLead:
        return 'Can manage trip content and approve tasks and itinerary items';
      case AppRole.staff:
        return 'Can edit operational items but cannot approve pricing';
      case AppRole.finance:
        return 'Full access to budget module and cost approvals';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppUser
// ─────────────────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String initials;
  final Color avatarColor;
  final String role;        // job title (display string)
  final AppRole appRole;    // permission tier

  const AppUser({
    required this.id,
    required this.name,
    required this.initials,
    required this.avatarColor,
    required this.role,
    this.appRole = AppRole.staff,
  });
}

/// Pre-defined avatar colors for mock users.
const _avatarColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFF0EA5E9), // sky
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // violet
  AppColors.accent,  // gold
];

Color avatarColorFor(int index) => _avatarColors[index % _avatarColors.length];

/// Top-level helpers for DB ↔ AppRole conversion.
/// Extension statics are not callable as AppRole.x() in Dart,
/// so these live as plain top-level functions instead.
AppRole appRoleFromDb(String raw) => switch (raw) {
  'admin'     => AppRole.admin,
  'trip_lead' => AppRole.tripLead,
  'finance'   => AppRole.finance,
  _           => AppRole.staff,
};

String appRoleToDb(AppRole r) => r.dbValue;
