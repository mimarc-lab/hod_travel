// ─────────────────────────────────────────────────────────────────────────────
// AI Memory — data models
// ─────────────────────────────────────────────────────────────────────────────

// ── SuggestionFeedbackEvent ───────────────────────────────────────────────────

enum FeedbackAction {
  approved,
  rejected,
  edited,
  dismissed,
  applied;

  String get dbValue => name;

  static FeedbackAction fromDb(String? v) => switch (v) {
        'approved'  => FeedbackAction.approved,
        'rejected'  => FeedbackAction.rejected,
        'edited'    => FeedbackAction.edited,
        'applied'   => FeedbackAction.applied,
        _           => FeedbackAction.dismissed,
      };
}

class SuggestionFeedbackEvent {
  final String id;
  final String teamId;
  final String? dossierId;
  final String? tripId;
  final String? suggestionId;
  final String suggestionType;
  final FeedbackAction action;
  final Map<String, dynamic>? originalValue;
  final Map<String, dynamic>? finalValue;
  final String? editSummary;
  final DateTime createdAt;

  const SuggestionFeedbackEvent({
    required this.id,
    required this.teamId,
    this.dossierId,
    this.tripId,
    this.suggestionId,
    required this.suggestionType,
    required this.action,
    this.originalValue,
    this.finalValue,
    this.editSummary,
    required this.createdAt,
  });

  factory SuggestionFeedbackEvent.fromMap(Map<String, dynamic> r) =>
      SuggestionFeedbackEvent(
        id:             r['id'] as String,
        teamId:         r['team_id'] as String,
        dossierId:      r['dossier_id'] as String?,
        tripId:         r['trip_id'] as String?,
        suggestionId:   r['suggestion_id'] as String?,
        suggestionType: r['suggestion_type'] as String,
        action:         FeedbackAction.fromDb(r['feedback_action'] as String?),
        originalValue:  r['original_value'] as Map<String, dynamic>?,
        finalValue:     r['final_value'] as Map<String, dynamic>?,
        editSummary:    r['edit_summary'] as String?,
        createdAt:      DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'team_id':        teamId,
        if (dossierId != null)    'dossier_id':     dossierId,
        if (tripId != null)       'trip_id':        tripId,
        if (suggestionId != null) 'suggestion_id':  suggestionId,
        'suggestion_type':  suggestionType,
        'feedback_action':  action.dbValue,
        if (originalValue != null) 'original_value': originalValue,
        if (finalValue != null)    'final_value':    finalValue,
        if (editSummary != null)   'edit_summary':   editSummary,
      };
}

// ── InferredPreferenceSignal ──────────────────────────────────────────────────

enum SignalConfidence {
  emerging, // 1–2 data points
  moderate, // 3–5 data points
  strong;   // 6+ data points

  String get label => switch (this) {
        SignalConfidence.emerging => 'Emerging',
        SignalConfidence.moderate => 'Moderate',
        SignalConfidence.strong   => 'Strong',
      };

  String get dbValue => name;

  static SignalConfidence fromDb(String? v) => switch (v) {
        'moderate' => SignalConfidence.moderate,
        'strong'   => SignalConfidence.strong,
        _          => SignalConfidence.emerging,
      };

  static SignalConfidence fromCount(int count) {
    if (count >= 6) return SignalConfidence.strong;
    if (count >= 3) return SignalConfidence.moderate;
    return SignalConfidence.emerging;
  }
}

class InferredPreferenceSignal {
  final String id;
  final String teamId;
  final String dossierId;
  final String signalKey;
  final String signalValue;
  final SignalConfidence confidence;
  final int evidenceCount;
  final String? evidenceSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InferredPreferenceSignal({
    required this.id,
    required this.teamId,
    required this.dossierId,
    required this.signalKey,
    required this.signalValue,
    required this.confidence,
    required this.evidenceCount,
    this.evidenceSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  String get humanLabel => _labels[signalKey] ?? signalKey;

  static const _labels = <String, String>{
    'pacing_preference':         'Pacing Preference',
    'prefers_late_starts':       'Start Time',
    'accommodation_preference':  'Accommodation Type',
    'cultural_interest':         'Cultural Interest',
    'adventure_interest':        'Adventure Interest',
    'relaxation_interest':       'Relaxation Interest',
    'intellectual_interest':     'Intellectual Interest',
    'shopping_interest':         'Shopping Interest',
    'dislikes_crowds':           'Crowd Sensitivity',
    'prefers_private':           'Privacy Preference',
    'preferred_dining_style':    'Dining Style',
    'wellness_importance':       'Wellness Importance',
    'luxury_level':              'Luxury Level',
    'guide_preference':          'Guide Preference',
    'supplier_preference':       'Supplier Preference',
    'experience_category':       'Preferred Experiences',
  };

  factory InferredPreferenceSignal.fromMap(Map<String, dynamic> r) =>
      InferredPreferenceSignal(
        id:              r['id'] as String,
        teamId:          r['team_id'] as String,
        dossierId:       r['dossier_id'] as String,
        signalKey:       r['signal_key'] as String,
        signalValue:     r['signal_value'] as String,
        confidence:      SignalConfidence.fromDb(r['confidence'] as String?),
        evidenceCount:   (r['evidence_count'] as num?)?.toInt() ?? 1,
        evidenceSummary: r['evidence_summary'] as String?,
        createdAt:       DateTime.parse(r['created_at'] as String),
        updatedAt:       DateTime.parse(r['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'team_id':          teamId,
        'dossier_id':       dossierId,
        'signal_key':       signalKey,
        'signal_value':     signalValue,
        'confidence':       confidence.dbValue,
        'evidence_count':   evidenceCount,
        if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
        'updated_at':       DateTime.now().toIso8601String(),
      };
}

// ── AiMemoryRecord ────────────────────────────────────────────────────────────

enum MemoryType {
  clientPreference,
  experiencePattern,
  supplierPattern,
  tripPattern,
  editPattern;

  String get dbValue => switch (this) {
        MemoryType.clientPreference => 'client_preference',
        MemoryType.experiencePattern => 'experience_pattern',
        MemoryType.supplierPattern  => 'supplier_pattern',
        MemoryType.tripPattern      => 'trip_pattern',
        MemoryType.editPattern      => 'edit_pattern',
      };

  static MemoryType fromDb(String? v) => switch (v) {
        'client_preference'  => MemoryType.clientPreference,
        'experience_pattern' => MemoryType.experiencePattern,
        'supplier_pattern'   => MemoryType.supplierPattern,
        'trip_pattern'       => MemoryType.tripPattern,
        'edit_pattern'       => MemoryType.editPattern,
        _                    => MemoryType.clientPreference,
      };
}

class AiMemoryRecord {
  final String id;
  final String teamId;
  final String? dossierId;
  final String? tripId;
  final MemoryType memoryType;
  final String sourceType;
  final String signalKey;
  final Map<String, dynamic> signalValue;
  final double confidence;
  final int evidenceCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiMemoryRecord({
    required this.id,
    required this.teamId,
    this.dossierId,
    this.tripId,
    required this.memoryType,
    required this.sourceType,
    required this.signalKey,
    required this.signalValue,
    this.confidence = 0.5,
    this.evidenceCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiMemoryRecord.fromMap(Map<String, dynamic> r) => AiMemoryRecord(
        id:            r['id'] as String,
        teamId:        r['team_id'] as String,
        dossierId:     r['dossier_id'] as String?,
        tripId:        r['trip_id'] as String?,
        memoryType:    MemoryType.fromDb(r['memory_type'] as String?),
        sourceType:    r['source_type'] as String,
        signalKey:     r['signal_key'] as String,
        signalValue:   (r['signal_value'] as Map<String, dynamic>?) ?? {},
        confidence:    (r['confidence'] as num?)?.toDouble() ?? 0.5,
        evidenceCount: (r['evidence_count'] as num?)?.toInt() ?? 1,
        createdAt:     DateTime.parse(r['created_at'] as String),
        updatedAt:     DateTime.parse(r['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'team_id':       teamId,
        if (dossierId != null) 'dossier_id': dossierId,
        if (tripId != null)    'trip_id':    tripId,
        'memory_type':   memoryType.dbValue,
        'source_type':   sourceType,
        'signal_key':    signalKey,
        'signal_value':  signalValue,
        'confidence':    confidence,
        'evidence_count': evidenceCount,
        'updated_at':    DateTime.now().toIso8601String(),
      };
}
