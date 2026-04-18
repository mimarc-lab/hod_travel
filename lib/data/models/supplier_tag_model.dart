// =============================================================================
// SupplierTag — team-scoped reusable tag (e.g. "Beachfront", "Michelin Star").
// Many-to-many with suppliers via supplier_tag_links.
// =============================================================================

class SupplierTag {
  final String id;
  final String teamId;
  final String name;
  final DateTime createdAt;

  const SupplierTag({
    required this.id,
    required this.teamId,
    required this.name,
    required this.createdAt,
  });

  factory SupplierTag.fromMap(Map<String, dynamic> m) => SupplierTag(
        id:        m['id'] as String,
        teamId:    m['team_id'] as String,
        name:      m['name'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'team_id': teamId,
        'name':    name,
      };

  SupplierTag copyWith({String? name}) => SupplierTag(
        id:        id,
        teamId:    teamId,
        name:      name ?? this.name,
        createdAt: createdAt,
      );
}
