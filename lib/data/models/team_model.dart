import 'user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Team
// ─────────────────────────────────────────────────────────────────────────────

class Team {
  final String id;
  final String name;
  final String? slug;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    this.slug,
    required this.createdAt,
  });

  factory Team.fromDb(Map<String, dynamic> r) => Team(
    id:        r['id'] as String,
    name:      r['name'] as String,
    slug:      r['slug'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  Map<String, dynamic> toDb() => {
    'name': name,
    'slug': slug,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// TeamMember
// ─────────────────────────────────────────────────────────────────────────────

class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final AppRole role;
  final bool isActive;
  final AppUser? profile;   // populated when fetching with join

  const TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.isActive,
    this.profile,
  });

  factory TeamMember.fromDb(Map<String, dynamic> r) => TeamMember(
    id:       r['id'] as String,
    teamId:   r['team_id'] as String,
    userId:   r['user_id'] as String,
    role:     appRoleFromDb(r['role'] as String? ?? 'staff'),
    isActive: r['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toDb() => {
    'team_id':   teamId,
    'user_id':   userId,
    'role':      appRoleToDb(role),
    'is_active': isActive,
  };
}
