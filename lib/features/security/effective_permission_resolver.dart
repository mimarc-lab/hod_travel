import '../../data/models/effective_permission.dart';
import '../../data/models/team_member_permission.dart';

// Pure, stateless resolution — no Supabase dependency.
// Takes role defaults and user overrides already fetched, returns merged result.

abstract class EffectivePermissionResolver {
  static EffectivePermission resolve({
    required String role,
    required List<RolePermissionDefault> roleDefaults,
    required List<TeamMemberPermission> userOverrides,
  }) {
    // Build default map for this role
    final defaults = <String, bool>{};
    for (final d in roleDefaults) {
      if (d.role == role) defaults[d.permissionKey] = d.permissionValue;
    }

    // Build override map
    final overrides = <String, bool>{};
    for (final o in userOverrides) {
      overrides[o.permissionKey] = o.permissionValue;
    }

    // Override takes precedence; fall back to role default; default to false
    bool get(String key) =>
        overrides.containsKey(key) ? overrides[key]! : (defaults[key] ?? false);

    return EffectivePermission(
      canViewDossier:        get(DossierPermissionKey.viewDossier),
      canEditDossier:        get(DossierPermissionKey.editDossier),
      canViewSensitiveNotes: get(DossierPermissionKey.viewSensitiveNotes),
    );
  }
}
