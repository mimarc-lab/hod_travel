import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TeamRepository {
  /// Fetch all teams the current user belongs to.
  Future<List<Team>> fetchMyTeams();

  /// Fetch or create the default team for a user signing up for the first time.
  Future<Team> fetchOrCreateDefaultTeam(String userId, String teamName);

  /// Fetch all members of a team, including their profiles and roles.
  Future<List<TeamMember>> fetchMembers(String teamId);

  /// Add a user to a team.
  Future<TeamMember> addMember({
    required String teamId,
    required String userId,
    required AppRole role,
  });

  /// Update a member's role.
  Future<void> updateMemberRole({
    required String teamId,
    required String userId,
    required AppRole role,
  });

  /// Deactivate a team member (soft delete).
  Future<void> deactivateMember({
    required String teamId,
    required String userId,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseTeamRepository implements TeamRepository {
  final SupabaseClient _client;
  SupabaseTeamRepository(this._client);

  @override
  Future<List<Team>> fetchMyTeams() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw AppAuthException('Not authenticated');
    final rows = await _client
        .from('team_members')
        .select('teams(*)')
        .eq('user_id', uid)
        .eq('is_active', true);
    return (rows as List).map((r) {
      final t = (r as Map<String, dynamic>)['teams'] as Map<String, dynamic>;
      return Team.fromDb(t);
    }).toList();
  }

  @override
  Future<Team> fetchOrCreateDefaultTeam(
      String userId, String teamName) async {
    final existing = await fetchMyTeams();
    if (existing.isNotEmpty) return existing.first;

    // Create team then add creator as admin
    final teamRow = await _client
        .from('teams')
        .insert({'name': teamName})
        .select()
        .single();
    final team = Team.fromDb(teamRow);

    await _client.from('team_members').insert({
      'team_id':   team.id,
      'user_id':   userId,
      'role':      'admin',
      'is_active': true,
    });

    return team;
  }

  @override
  Future<List<TeamMember>> fetchMembers(String teamId) async {
    final rows = await _client
        .from('team_members')
        .select('*, profiles(id, full_name, email, avatar_url)')
        .eq('team_id', teamId)
        .eq('is_active', true)
        .order('created_at');

    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final m = TeamMember.fromDb(row);
      final p = row['profiles'] as Map<String, dynamic>?;
      if (p == null) return m;
      final profile = ProfileRow.fromJson(p).toAppUser(role: m.role);
      return TeamMember(
        id:       m.id,
        teamId:   m.teamId,
        userId:   m.userId,
        role:     m.role,
        isActive: m.isActive,
        profile:  profile,
      );
    }).toList();
  }

  @override
  Future<TeamMember> addMember({
    required String teamId,
    required String userId,
    required AppRole role,
  }) async {
    final row = await _client.from('team_members').upsert({
      'team_id':   teamId,
      'user_id':   userId,
      'role':      appRoleToDb(role),
      'is_active': true,
    }).select().single();
    return TeamMember.fromDb(row);
  }

  @override
  Future<void> updateMemberRole({
    required String teamId,
    required String userId,
    required AppRole role,
  }) async {
    await _client
        .from('team_members')
        .update({'role': appRoleToDb(role)})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  @override
  Future<void> deactivateMember({
    required String teamId,
    required String userId,
  }) async {
    await _client
        .from('team_members')
        .update({'is_active': false})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }
}
