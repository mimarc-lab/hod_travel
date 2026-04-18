class TeamMemberPermission {
  final String id;
  final String userId;
  final String teamId;
  final String permissionKey;
  final bool permissionValue;
  final String? grantedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamMemberPermission({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.permissionKey,
    required this.permissionValue,
    this.grantedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamMemberPermission.fromMap(Map<String, dynamic> m) =>
      TeamMemberPermission(
        id:              m['id'] as String,
        userId:          m['user_id'] as String,
        teamId:          m['team_id'] as String,
        permissionKey:   m['permission_key'] as String,
        permissionValue: m['permission_value'] as bool,
        grantedBy:       m['granted_by'] as String?,
        createdAt:       DateTime.parse(m['created_at'] as String),
        updatedAt:       DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
    'user_id':          userId,
    'team_id':          teamId,
    'permission_key':   permissionKey,
    'permission_value': permissionValue,
    if (grantedBy != null) 'granted_by': grantedBy,
  };

  TeamMemberPermission copyWith({bool? permissionValue, String? grantedBy}) =>
      TeamMemberPermission(
        id:              id,
        userId:          userId,
        teamId:          teamId,
        permissionKey:   permissionKey,
        permissionValue: permissionValue ?? this.permissionValue,
        grantedBy:       grantedBy ?? this.grantedBy,
        createdAt:       createdAt,
        updatedAt:       DateTime.now(),
      );
}

class RolePermissionDefault {
  final String role;
  final String permissionKey;
  final bool permissionValue;

  const RolePermissionDefault({
    required this.role,
    required this.permissionKey,
    required this.permissionValue,
  });

  factory RolePermissionDefault.fromMap(Map<String, dynamic> m) =>
      RolePermissionDefault(
        role:            m['role'] as String,
        permissionKey:   m['permission_key'] as String,
        permissionValue: m['permission_value'] as bool,
      );
}
