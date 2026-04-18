import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/effective_permission.dart';
import '../../data/models/team_member_permission.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PermissionService
//
// Resolves effective dossier permissions for the current user by calling
// the resolve_dossier_permissions RPC (one round-trip, SECURITY DEFINER).
// Results are cached per userId+teamId for the session lifetime.
// Call invalidate() on sign-out.
// ─────────────────────────────────────────────────────────────────────────────

class PermissionService {
  final SupabaseClient _client;

  final Map<String, EffectivePermission> _cache = {};

  PermissionService(this._client);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Resolves all dossier permissions for [teamId].
  /// Uses [auth.uid()] implicitly inside the RPC.
  Future<EffectivePermission> resolve(String teamId) async {
    final userId = _client.auth.currentUser?.id ?? '';
    if (userId.isEmpty || teamId.isEmpty) return EffectivePermission.denied;

    final cacheKey = '$userId:$teamId';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      final rows = await _client.rpc(
        'resolve_dossier_permissions',
        params: {'p_team_id': teamId},
      ) as List;

      final map = <String, bool>{};
      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        map[r['permission_key'] as String] = r['permission_value'] as bool;
      }

      final perm = EffectivePermission(
        canViewDossier:        map[DossierPermissionKey.viewDossier]        ?? false,
        canEditDossier:        map[DossierPermissionKey.editDossier]        ?? false,
        canViewSensitiveNotes: map[DossierPermissionKey.viewSensitiveNotes] ?? false,
      );

      _cache[cacheKey] = perm;
      return perm;
    } catch (_) {
      return EffectivePermission.denied;
    }
  }

  /// Clears the cache. Call on sign-out or when overrides change.
  void invalidate() => _cache.clear();

  // ── Admin: override management ─────────────────────────────────────────────

  /// Fetches all permission overrides for [teamId] (admin use).
  Future<List<TeamMemberPermission>> fetchOverridesForTeam(String teamId) async {
    try {
      final rows = await _client
          .from('team_member_permissions')
          .select()
          .eq('team_id', teamId)
          .order('user_id') as List;
      return rows
          .map((r) => TeamMemberPermission.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Upserts a per-user permission override.
  Future<bool> upsertOverride(TeamMemberPermission override) async {
    try {
      final grantedBy = _client.auth.currentUser?.id;
      await _client.from('team_member_permissions').upsert({
        ...override.toMap(),
        'granted_by': grantedBy,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,team_id,permission_key');
      invalidate(); // clear cache so next resolve picks up the change
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a specific override, reverting to role default.
  Future<bool> deleteOverride(
      String userId, String teamId, String permissionKey) async {
    try {
      await _client
          .from('team_member_permissions')
          .delete()
          .eq('user_id', userId)
          .eq('team_id', teamId)
          .eq('permission_key', permissionKey);
      invalidate();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetches all role defaults (for display in admin UI).
  Future<List<RolePermissionDefault>> fetchRoleDefaults() async {
    try {
      final rows = await _client
          .from('role_permission_defaults')
          .select()
          .order('role') as List;
      return rows
          .map((r) => RolePermissionDefault.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
