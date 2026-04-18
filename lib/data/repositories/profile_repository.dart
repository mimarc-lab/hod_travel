import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper — avoids duplicating _loadProfiles() across repos
// ─────────────────────────────────────────────────────────────────────────────

/// Fetch all profiles and return them keyed by user ID.
/// Used by TripRepository and TaskRepository to resolve assignee names.
Future<Map<String, AppUser>> loadProfilesAsMap(SupabaseClient client) async {
  final rows = await client.from('profiles').select();
  return {
    for (final r in rows as List)
      (r as Map<String, dynamic>)['id'] as String:
          ProfileRow.fromJson(r).toAppUser(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileRow — maps public.profiles columns
// Role lives in team_members, not profiles.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileRow {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const ProfileRow({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  factory ProfileRow.fromJson(Map<String, dynamic> json) => ProfileRow(
    id:        json['id'] as String,
    fullName:  json['full_name'] as String? ?? '',
    email:     json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'full_name':  fullName,
    'email':      email,
    'avatar_url': avatarUrl,
  };

  /// Convert to app-level AppUser.
  /// [role] comes from team_members when available; defaults to staff.
  AppUser toAppUser({AppRole role = AppRole.staff, String? roleTitle}) {
    final initials = fullName.isNotEmpty
        ? fullName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : email.isNotEmpty ? email[0].toUpperCase() : '?';
    return AppUser(
      id:          id,
      name:        fullName.isNotEmpty ? fullName : email,
      initials:    initials,
      avatarColor: avatarColorFor(id.codeUnits.fold(0, (a, b) => a + b)),
      role:        roleTitle ?? role.label,
      appRole:     role,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class ProfileRepository {
  Future<ProfileRow?> fetchProfile(String userId);
  Future<List<ProfileRow>> fetchAllProfiles();
  Future<void> upsertProfile(ProfileRow profile);
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;
  SupabaseProfileRepository(this._client);

  @override
  Future<ProfileRow?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfileRow.fromJson(data);
  }

  @override
  Future<List<ProfileRow>> fetchAllProfiles() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('full_name');
    return (data as List)
        .map((e) => ProfileRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> upsertProfile(ProfileRow profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      ...profile.toJson(),
    });
  }
}
