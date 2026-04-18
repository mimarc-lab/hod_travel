import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RoleService — real-user role/permission state
// Seeded from AuthProvider after sign-in via switchUser().
// The role switcher in Settings can still swap roles locally for preview.
// ─────────────────────────────────────────────────────────────────────────────

class RoleService extends ChangeNotifier {
  AppUser _currentUser;

  RoleService({AppUser? initialUser})
      : _currentUser = initialUser ??
            AppUser(
              id:          'anon',
              name:        'Guest',
              initials:    'G',
              avatarColor: avatarColorFor(0),
              role:        'Staff',
              appRole:     AppRole.staff,
            );

  AppUser get user => _currentUser;
  AppRole get role => _currentUser.appRole;

  /// Called by app.dart when AuthProvider emits a new user after sign-in.
  void switchUser(AppUser user) {
    if (_currentUser.id == user.id && _currentUser.appRole == user.appRole) {
      return;
    }
    _currentUser = user;
    notifyListeners();
  }

  /// Local role override for Settings demo/preview purposes.
  void switchRole(AppRole role) {
    if (_currentUser.appRole == role) return;
    _currentUser = AppUser(
      id:          _currentUser.id,
      name:        _currentUser.name,
      initials:    _currentUser.initials,
      avatarColor: _currentUser.avatarColor,
      role:        _currentUser.role,
      appRole:     role,
    );
    notifyListeners();
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  /// Can approve or reject any record
  bool get canApprove =>
      role == AppRole.admin || role == AppRole.tripLead;

  /// Can approve cost items and budget records
  bool get canApproveCosts =>
      role == AppRole.admin || role == AppRole.finance;

  /// Can edit budget fields (net cost, markup, sell price)
  bool get canEditPricing =>
      role == AppRole.admin || role == AppRole.finance;

  /// Can mark tasks Ready for Review
  bool get canSubmitForReview => true; // all roles

  /// Can see all budget data
  bool get canViewBudget =>
      role == AppRole.admin ||
      role == AppRole.finance ||
      role == AppRole.tripLead;

  /// Can manage supplier records
  bool get canEditSuppliers =>
      role == AppRole.admin || role == AppRole.tripLead;
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleScope — InheritedNotifier to inject RoleService into the tree
// ─────────────────────────────────────────────────────────────────────────────

class RoleScope extends InheritedNotifier<RoleService> {
  const RoleScope({
    super.key,
    required RoleService roleService,
    required super.child,
  }) : super(notifier: roleService);

  static RoleService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RoleScope>();
    assert(scope != null, 'No RoleScope found in widget tree');
    return scope!.notifier!;
  }
}
