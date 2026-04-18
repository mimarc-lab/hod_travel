// ─────────────────────────────────────────────────────────────────────────────
// Questionnaire schema — the DreamMaker standard preference template.
// Predefined and opinionated; responses stored as Map<String, dynamic>.
// ─────────────────────────────────────────────────────────────────────────────

enum QItemType { text, longText, choice, multiChoice, scale, yesNo }

class QItem {
  final String key;
  final String label;
  final QItemType type;
  final List<String>? options;
  final String? hint;

  const QItem({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.hint,
  });
}

class QSection {
  final String id;
  final String title;
  final String subtitle;
  final List<QItem> items;

  const QSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// The standard DreamMaker questionnaire template
// ─────────────────────────────────────────────────────────────────────────────

const List<QSection> kDreamMakerQuestionnaire = [
  // ── Travel Style ────────────────────────────────────────────────────────────
  QSection(
    id: 'travel_style',
    title: 'Travel Style',
    subtitle: 'How your client travels and what they value most.',
    items: [
      QItem(
        key: 'trip_pacing',
        label: 'Preferred pace of travel',
        type: QItemType.choice,
        options: ['Slow & Immersive', 'Balanced', 'Action-Packed'],
        hint: 'How many activities per day feels right?',
      ),
      QItem(
        key: 'privacy_level',
        label: 'Privacy preference',
        type: QItemType.choice,
        options: ['Very Private', 'Standard', 'Open / Social'],
      ),
      QItem(
        key: 'luxury_expectation',
        label: 'Luxury expectation',
        type: QItemType.choice,
        options: ['Ultra Luxury (best of best)', 'High End', 'Comfortable & Considered'],
      ),
      QItem(
        key: 'structure_vs_flexibility',
        label: 'Structure vs. flexibility',
        type: QItemType.choice,
        options: ['Highly Structured', 'Balanced', 'Spontaneous'],
        hint: 'Do they prefer every day fully planned, or prefer room to explore?',
      ),
      QItem(
        key: 'guide_preference',
        label: 'Guide preference',
        type: QItemType.choice,
        options: ['Private Only', 'Small Group OK', 'No Preference'],
      ),
      QItem(
        key: 'travel_motivations',
        label: 'What does travel mean to them?',
        type: QItemType.longText,
        hint: 'Relaxation, discovery, family bonding, status, personal growth…',
      ),
    ],
  ),

  // ── Accommodation ───────────────────────────────────────────────────────────
  QSection(
    id: 'accommodation',
    title: 'Accommodation',
    subtitle: 'Preferences around stays and properties.',
    items: [
      QItem(
        key: 'property_type',
        label: 'Preferred property type',
        type: QItemType.choice,
        options: ['Hotel', 'Villa / Private Residence', 'Mixed'],
      ),
      QItem(
        key: 'room_type',
        label: 'Preferred room / suite type',
        type: QItemType.text,
        hint: 'e.g. suite, interconnecting rooms, sea view, butler service…',
      ),
      QItem(
        key: 'bedding_preferences',
        label: 'Bedding preferences',
        type: QItemType.text,
        hint: 'e.g. king bed, twin beds, hypoallergenic, firm mattress…',
      ),
      QItem(
        key: 'wellness_importance',
        label: 'How important is wellness / spa access?',
        type: QItemType.choice,
        options: ['Essential — must have', 'Preferred', 'Not a priority'],
      ),
      QItem(
        key: 'amenity_priorities',
        label: 'Property amenity priorities',
        type: QItemType.multiChoice,
        options: [
          'Private pool', 'Beach access', 'Gym', 'Spa', 'Butler service',
          'Kids club', 'Restaurant on site', 'Quiet / no families',
        ],
      ),
      QItem(
        key: 'accommodation_notes',
        label: 'Anything else about accommodation?',
        type: QItemType.longText,
      ),
    ],
  ),

  // ── Dining ─────────────────────────────────────────────────────────────────
  QSection(
    id: 'dining',
    title: 'Dining',
    subtitle: 'Food preferences, dietary needs, and dining style.',
    items: [
      QItem(
        key: 'dining_style',
        label: 'Preferred dining style',
        type: QItemType.choice,
        options: ['Fine Dining / Michelin-level', 'Casual & Local', 'Mix of both'],
      ),
      QItem(
        key: 'cuisine_preferences',
        label: 'Favourite cuisine types',
        type: QItemType.text,
        hint: 'e.g. Japanese, Italian, seafood, local street food…',
      ),
      QItem(
        key: 'dietary_restrictions',
        label: 'Dietary restrictions',
        type: QItemType.multiChoice,
        options: [
          'Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free',
          'Halal', 'Kosher', 'No pork', 'No shellfish', 'None',
        ],
      ),
      QItem(
        key: 'allergies',
        label: 'Food allergies',
        type: QItemType.text,
        hint: 'List any confirmed allergies clearly.',
      ),
      QItem(
        key: 'dining_dislikes',
        label: 'Strong food dislikes',
        type: QItemType.text,
        hint: 'What should never appear on the table?',
      ),
      QItem(
        key: 'alcohol_preference',
        label: 'Alcohol preference',
        type: QItemType.choice,
        options: ['Wine-focused', 'Cocktails', 'Champagne', 'Non-drinking', 'Flexible'],
      ),
      QItem(
        key: 'dining_notes',
        label: 'Additional dining notes',
        type: QItemType.longText,
      ),
    ],
  ),

  // ── Experiences ─────────────────────────────────────────────────────────────
  QSection(
    id: 'experiences',
    title: 'Experiences',
    subtitle: 'What they love doing and what they avoid.',
    items: [
      QItem(
        key: 'cultural_interest',
        label: 'Cultural / heritage interest',
        type: QItemType.scale,
        hint: '1 = not interested, 5 = very important',
      ),
      QItem(
        key: 'adventure_interest',
        label: 'Adventure / active experiences',
        type: QItemType.scale,
      ),
      QItem(
        key: 'relaxation_interest',
        label: 'Relaxation / slow travel interest',
        type: QItemType.scale,
      ),
      QItem(
        key: 'intellectual_interest',
        label: 'Intellectual / educational interest',
        type: QItemType.scale,
      ),
      QItem(
        key: 'shopping_interest',
        label: 'Shopping interest',
        type: QItemType.scale,
      ),
      QItem(
        key: 'experience_highlights',
        label: 'Past experiences they loved',
        type: QItemType.longText,
        hint: 'What were their trip highlights?',
      ),
      QItem(
        key: 'experience_dislikes',
        label: 'Experiences to avoid',
        type: QItemType.longText,
        hint: 'What should we never include?',
      ),
    ],
  ),

  // ── Family / Travelers ──────────────────────────────────────────────────────
  QSection(
    id: 'travelers',
    title: 'Family & Travelers',
    subtitle: 'Who is travelling and any specific needs.',
    items: [
      QItem(
        key: 'group_composition',
        label: 'Who is in the group?',
        type: QItemType.text,
        hint: 'e.g. couple + 2 children (ages 6 & 9) + grandparents',
      ),
      QItem(
        key: 'children_needs',
        label: 'Children-specific needs',
        type: QItemType.longText,
        hint: 'Club kids, babysitters, age-appropriate activities, cots, food…',
      ),
      QItem(
        key: 'group_dynamic',
        label: 'Group dynamic notes',
        type: QItemType.longText,
        hint: 'Any useful context about how the group travels together.',
      ),
      QItem(
        key: 'accessibility_needs',
        label: 'Accessibility or mobility needs',
        type: QItemType.longText,
      ),
    ],
  ),

  // ── Wellness ────────────────────────────────────────────────────────────────
  QSection(
    id: 'wellness',
    title: 'Wellness & Comfort',
    subtitle: 'Physical comfort, climate, and wellbeing needs.',
    items: [
      QItem(
        key: 'heat_tolerance',
        label: 'Heat tolerance',
        type: QItemType.choice,
        options: ['Low — prefers cool', 'Medium', 'High — comfortable in heat'],
      ),
      QItem(
        key: 'walking_tolerance',
        label: 'Walking tolerance',
        type: QItemType.choice,
        options: ['Limited', 'Moderate', 'Extensive'],
      ),
      QItem(
        key: 'prefers_late_starts',
        label: 'Prefer late morning starts?',
        type: QItemType.yesNo,
      ),
      QItem(
        key: 'dislikes_crowds',
        label: 'Sensitive to crowds?',
        type: QItemType.yesNo,
      ),
      QItem(
        key: 'wellness_treatments',
        label: 'Favourite wellness treatments',
        type: QItemType.text,
        hint: 'Massage, yoga, meditation, thermal pools…',
      ),
      QItem(
        key: 'comfort_notes',
        label: 'Other comfort considerations',
        type: QItemType.longText,
      ),
    ],
  ),

  // ── Logistics ───────────────────────────────────────────────────────────────
  QSection(
    id: 'logistics',
    title: 'Logistics & Special Requests',
    subtitle: 'Practical preferences that shape on-the-ground planning.',
    items: [
      QItem(
        key: 'transport_preference',
        label: 'Ground transport preference',
        type: QItemType.text,
        hint: 'e.g. Mercedes, electric vehicle, no vans, private jet only…',
      ),
      QItem(
        key: 'photography_sensitivity',
        label: 'Photography / privacy sensitivity',
        type: QItemType.choice,
        options: ['Very sensitive — no photography', 'Standard', 'Happy to be photographed'],
      ),
      QItem(
        key: 'security_needs',
        label: 'Security requirements',
        type: QItemType.text,
        hint: 'Close protection, discreet, standard…',
      ),
      QItem(
        key: 'special_requests',
        label: 'Any other special requests',
        type: QItemType.longText,
        hint: 'Anniversaries, surprises, gifting, flowers, in-room setup…',
      ),
      QItem(
        key: 'past_trip_feedback',
        label: 'Feedback from past trips',
        type: QItemType.longText,
        hint: 'What worked well? What did they not enjoy?',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ClientQuestionnaireResponse
// ─────────────────────────────────────────────────────────────────────────────

enum QuestionnaireSource { internal, clientCall, direct }

enum ResponseStatus {
  draft,
  submitted,
  reviewed,
  applied;

  String get label => switch (this) {
    ResponseStatus.draft     => 'Draft',
    ResponseStatus.submitted => 'Submitted',
    ResponseStatus.reviewed  => 'Reviewed',
    ResponseStatus.applied   => 'Applied',
  };

  String get dbValue => name;

  static ResponseStatus fromDb(String? v) => switch (v) {
    'submitted' => ResponseStatus.submitted,
    'reviewed'  => ResponseStatus.reviewed,
    'applied'   => ResponseStatus.applied,
    _           => ResponseStatus.draft,
  };
}

class ClientQuestionnaireResponse {
  final String id;
  final String dossierId;
  final String teamId;
  final String? tripId;
  final String? completedBy;
  final DateTime completedAt;
  final DateTime? updatedAt;
  final DateTime? appliedAt;
  final Map<String, dynamic> responses;
  final String? notes;
  final QuestionnaireSource source;
  final ResponseStatus status;

  const ClientQuestionnaireResponse({
    required this.id,
    required this.dossierId,
    required this.teamId,
    this.tripId,
    this.completedBy,
    required this.completedAt,
    this.updatedAt,
    this.appliedAt,
    required this.responses,
    this.notes,
    this.source = QuestionnaireSource.internal,
    this.status = ResponseStatus.submitted,
  });

  String get sourceLabel => switch (source) {
    QuestionnaireSource.internal   => 'Internal entry',
    QuestionnaireSource.clientCall => 'Client call',
    QuestionnaireSource.direct     => 'Client submitted',
  };

  bool get isDraft     => status == ResponseStatus.draft;
  bool get isSubmitted => status == ResponseStatus.submitted;
  bool get isApplied   => status == ResponseStatus.applied;

  factory ClientQuestionnaireResponse.fromMap(Map<String, dynamic> r) =>
      ClientQuestionnaireResponse(
        id:          r['id'] as String,
        dossierId:   r['dossier_id'] as String,
        teamId:      r['team_id'] as String,
        tripId:      r['trip_id'] as String?,
        completedBy: r['completed_by'] as String?,
        completedAt: r['completed_at'] != null
            ? DateTime.parse(r['completed_at'] as String)
            : DateTime.now(),
        updatedAt:   r['updated_at'] != null
            ? DateTime.parse(r['updated_at'] as String)
            : null,
        appliedAt:   r['applied_at'] != null
            ? DateTime.parse(r['applied_at'] as String)
            : null,
        responses:   (r['responses'] as Map<String, dynamic>?) ?? {},
        notes:       r['notes'] as String?,
        source:      _sourceFromDb(r['source'] as String?),
        status:      ResponseStatus.fromDb(r['status'] as String?),
      );

  Map<String, dynamic> toMap({String? dossierId, String? teamId}) => {
    if (dossierId != null) 'dossier_id': dossierId,
    if (teamId != null)    'team_id':    teamId,
    if (tripId != null)    'trip_id':    tripId,
    if (completedBy != null) 'completed_by': completedBy,
    'responses': responses,
    'notes':     notes,
    'source':    _sourceToDb(source),
    'status':    status.dbValue,
  };

  ClientQuestionnaireResponse copyWith({
    String? id,
    Map<String, dynamic>? responses,
    String? notes,
    QuestionnaireSource? source,
    ResponseStatus? status,
    DateTime? completedAt,
    DateTime? appliedAt,
  }) =>
      ClientQuestionnaireResponse(
        id:          id          ?? this.id,
        dossierId:   dossierId,
        teamId:      teamId,
        tripId:      tripId,
        completedBy: completedBy,
        completedAt: completedAt ?? this.completedAt,
        updatedAt:   DateTime.now(),
        appliedAt:   appliedAt   ?? this.appliedAt,
        responses:   responses   ?? this.responses,
        notes:       notes       ?? this.notes,
        source:      source      ?? this.source,
        status:      status      ?? this.status,
      );

  static QuestionnaireSource _sourceFromDb(String? v) => switch (v) {
    'client_call' => QuestionnaireSource.clientCall,
    'direct'      => QuestionnaireSource.direct,
    _             => QuestionnaireSource.internal,
  };

  static String _sourceToDb(QuestionnaireSource s) => switch (s) {
    QuestionnaireSource.clientCall => 'client_call',
    QuestionnaireSource.direct     => 'direct',
    QuestionnaireSource.internal   => 'internal',
  };
}
