// ─────────────────────────────────────────────────────────────────────────────
// TravelerRole
// ─────────────────────────────────────────────────────────────────────────────

enum TravelerRole {
  primary,
  spouse,
  partner,
  child,
  infant,
  teen,
  parent,
  aide,
  guest,
  other;

  String get label => switch (this) {
    TravelerRole.primary => 'Primary',
    TravelerRole.spouse => 'Spouse',
    TravelerRole.partner => 'Partner',
    TravelerRole.child => 'Child',
    TravelerRole.infant => 'Infant',
    TravelerRole.teen => 'Teen',
    TravelerRole.parent => 'Parent',
    TravelerRole.aide => 'Aide / Assistant',
    TravelerRole.guest => 'Guest',
    TravelerRole.other => 'Other',
  };

  String get dbValue => name;

  static TravelerRole fromDb(String? v) => TravelerRole.values.firstWhere(
    (e) => e.dbValue == v,
    orElse: () => TravelerRole.guest,
  );
}

enum AgeBracket {
  infant,
  child,
  teen,
  adult,
  senior;

  String get label => switch (this) {
    AgeBracket.infant => 'Infant (0–2)',
    AgeBracket.child => 'Child (3–12)',
    AgeBracket.teen => 'Teen (13–17)',
    AgeBracket.adult => 'Adult (18–64)',
    AgeBracket.senior => 'Senior (65+)',
  };

  String get dbValue => name;

  static AgeBracket? fromDb(String? v) => v == null
      ? null
      : AgeBracket.values.firstWhere(
          (e) => e.dbValue == v,
          orElse: () => AgeBracket.adult,
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientTraveler — a sub-profile under a ClientDossier
// ─────────────────────────────────────────────────────────────────────────────

class ClientTraveler {
  final String id;
  final String dossierId;
  final String name;
  final TravelerRole role;
  final AgeBracket? ageBracket;
  final String? dietaryNotes;
  final String? roomingNotes;
  final String? activityNotes;
  final String? medicalNotes;
  final String? personalityNotes;
  final int sortOrder;
  final DateTime createdAt;

  const ClientTraveler({
    required this.id,
    required this.dossierId,
    required this.name,
    this.role = TravelerRole.guest,
    this.ageBracket,
    this.dietaryNotes,
    this.roomingNotes,
    this.activityNotes,
    this.medicalNotes,
    this.personalityNotes,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory ClientTraveler.fromMap(Map<String, dynamic> r) => ClientTraveler(
    id: r['id'] as String,
    dossierId: r['dossier_id'] as String,
    name: r['name'] as String,
    role: TravelerRole.fromDb(r['role'] as String?),
    ageBracket: AgeBracket.fromDb(r['age_bracket'] as String?),
    dietaryNotes: r['dietary_notes'] as String?,
    roomingNotes: r['rooming_notes'] as String?,
    activityNotes: r['activity_notes'] as String?,
    medicalNotes: r['medical_notes'] as String?,
    personalityNotes: r['personality_notes'] as String?,
    sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  Map<String, dynamic> toMap({String? dossierId}) => {
    'dossier_id': ?dossierId,
    'name': name,
    'role': role.dbValue,
    'age_bracket': ageBracket?.dbValue,
    'dietary_notes': dietaryNotes,
    'rooming_notes': roomingNotes,
    'activity_notes': activityNotes,
    'medical_notes': medicalNotes,
    'personality_notes': personalityNotes,
    'sort_order': sortOrder,
  };

  ClientTraveler copyWith({
    String? name,
    TravelerRole? role,
    AgeBracket? ageBracket,
    bool clearAgeBracket = false,
    String? dietaryNotes,
    bool clearDietary = false,
    String? roomingNotes,
    bool clearRooming = false,
    String? activityNotes,
    bool clearActivity = false,
    String? medicalNotes,
    bool clearMedical = false,
    String? personalityNotes,
    bool clearPersonality = false,
    int? sortOrder,
  }) => ClientTraveler(
    id: id,
    dossierId: dossierId,
    name: name ?? this.name,
    role: role ?? this.role,
    ageBracket: clearAgeBracket ? null : (ageBracket ?? this.ageBracket),
    dietaryNotes: clearDietary ? null : (dietaryNotes ?? this.dietaryNotes),
    roomingNotes: clearRooming ? null : (roomingNotes ?? this.roomingNotes),
    activityNotes: clearActivity ? null : (activityNotes ?? this.activityNotes),
    medicalNotes: clearMedical ? null : (medicalNotes ?? this.medicalNotes),
    personalityNotes: clearPersonality
        ? null
        : (personalityNotes ?? this.personalityNotes),
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
  );
}
