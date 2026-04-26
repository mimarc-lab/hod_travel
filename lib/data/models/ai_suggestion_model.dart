import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AiSuggestionType {
  draftItinerary,
  missingGap,
  supplierRecommendation,
  signatureExperience,
  taskSuggestion,
  flowImprovement,
  itinerarySequence;

  String get label => switch (this) {
        AiSuggestionType.draftItinerary      => 'Draft Itinerary',
        AiSuggestionType.missingGap          => 'Missing Gap',
        AiSuggestionType.supplierRecommendation => 'Supplier',
        AiSuggestionType.signatureExperience => 'Experience',
        AiSuggestionType.taskSuggestion      => 'Task',
        AiSuggestionType.flowImprovement     => 'Flow',
        AiSuggestionType.itinerarySequence   => 'Sequence Draft',
      };

  String get dbValue => switch (this) {
        AiSuggestionType.draftItinerary      => 'draft_itinerary',
        AiSuggestionType.missingGap          => 'missing_gap',
        AiSuggestionType.supplierRecommendation => 'supplier_recommendation',
        AiSuggestionType.signatureExperience => 'signature_experience',
        AiSuggestionType.taskSuggestion      => 'task_suggestion',
        AiSuggestionType.flowImprovement     => 'flow_improvement',
        AiSuggestionType.itinerarySequence   => 'itinerary_sequence',
      };

  static AiSuggestionType fromDb(String v) => switch (v) {
        'draft_itinerary'        => AiSuggestionType.draftItinerary,
        'missing_gap'            => AiSuggestionType.missingGap,
        'supplier_recommendation'=> AiSuggestionType.supplierRecommendation,
        'signature_experience'   => AiSuggestionType.signatureExperience,
        'task_suggestion'        => AiSuggestionType.taskSuggestion,
        'flow_improvement'       => AiSuggestionType.flowImprovement,
        'itinerary_sequence'     => AiSuggestionType.itinerarySequence,
        _                        => AiSuggestionType.flowImprovement,
      };

  IconData get icon => switch (this) {
        AiSuggestionType.draftItinerary      => Icons.auto_fix_high_rounded,
        AiSuggestionType.missingGap          => Icons.warning_amber_rounded,
        AiSuggestionType.supplierRecommendation => Icons.storefront_rounded,
        AiSuggestionType.signatureExperience => Icons.auto_awesome_rounded,
        AiSuggestionType.taskSuggestion      => Icons.task_alt_rounded,
        AiSuggestionType.flowImprovement     => Icons.route_rounded,
        AiSuggestionType.itinerarySequence   => Icons.view_timeline_rounded,
      };

  Color get color => switch (this) {
        AiSuggestionType.draftItinerary      => const Color(0xFF7C3AED),
        AiSuggestionType.missingGap          => const Color(0xFFD97706),
        AiSuggestionType.supplierRecommendation => const Color(0xFF0891B2),
        AiSuggestionType.signatureExperience => const Color(0xFF7C3AED),
        AiSuggestionType.taskSuggestion      => const Color(0xFF059669),
        AiSuggestionType.flowImprovement     => const Color(0xFF2563EB),
        AiSuggestionType.itinerarySequence   => const Color(0xFF0F766E),
      };

  Color get backgroundColor => switch (this) {
        AiSuggestionType.draftItinerary      => const Color(0xFFF5F3FF),
        AiSuggestionType.missingGap          => const Color(0xFFFFFBEB),
        AiSuggestionType.supplierRecommendation => const Color(0xFFECFEFF),
        AiSuggestionType.signatureExperience => const Color(0xFFF5F3FF),
        AiSuggestionType.taskSuggestion      => const Color(0xFFF0FDF4),
        AiSuggestionType.flowImprovement     => const Color(0xFFEFF6FF),
        AiSuggestionType.itinerarySequence   => const Color(0xFFF0FDFA),
      };
}

enum AiSuggestionStatus {
  pending,
  approved,
  dismissed,
  applied;

  String get dbValue => switch (this) {
        AiSuggestionStatus.pending => 'pending',
        AiSuggestionStatus.approved => 'approved',
        AiSuggestionStatus.dismissed => 'dismissed',
        AiSuggestionStatus.applied => 'applied',
      };

  static AiSuggestionStatus fromDb(String v) => switch (v) {
        'approved' => AiSuggestionStatus.approved,
        'dismissed' => AiSuggestionStatus.dismissed,
        'applied' => AiSuggestionStatus.applied,
        _ => AiSuggestionStatus.pending,
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

class AiSuggestion {
  final String id;
  final String tripId;
  final String teamId;
  final AiSuggestionType type;
  final String title;
  final String description;
  final String? rationale;
  final String? targetEntityType;
  final String? targetEntityId;

  /// Flexible payload: for itinerary suggestions this holds day/item fields;
  /// for task suggestions it holds task fields; etc.
  final Map<String, dynamic> proposedPayload;

  /// Snapshot of the trip context used to generate this suggestion.
  final Map<String, dynamic> sourceContext;

  final AiSuggestionStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const AiSuggestion({
    required this.id,
    required this.tripId,
    required this.teamId,
    required this.type,
    required this.title,
    required this.description,
    this.rationale,
    this.targetEntityType,
    this.targetEntityId,
    this.proposedPayload = const {},
    this.sourceContext = const {},
    this.status = AiSuggestionStatus.pending,
    required this.createdAt,
    this.reviewedAt,
  });

  // ── fromJson ────────────────────────────────────────────────────────────────

  factory AiSuggestion.fromJson(Map<String, dynamic> json) {
    return AiSuggestion(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      teamId: json['team_id'] as String,
      type: AiSuggestionType.fromDb(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      rationale: json['rationale'] as String?,
      targetEntityType: json['target_entity_type'] as String?,
      targetEntityId: json['target_entity_id'] as String?,
      proposedPayload:
          (json['proposed_payload'] as Map<String, dynamic>?) ?? {},
      sourceContext: (json['source_context'] as Map<String, dynamic>?) ?? {},
      status: AiSuggestionStatus.fromDb(json['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
    );
  }

  // ── toJson ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'trip_id': tripId,
        'team_id': teamId,
        'type': type.dbValue,
        'title': title,
        'description': description,
        if (rationale != null) 'rationale': rationale,
        if (targetEntityType != null) 'target_entity_type': targetEntityType,
        if (targetEntityId != null) 'target_entity_id': targetEntityId,
        'proposed_payload': proposedPayload,
        'source_context': sourceContext,
        'status': status.dbValue,
      };

  // ── copyWith ─────────────────────────────────────────────────────────────────

  AiSuggestion copyWith({
    String? id,
    String? tripId,
    String? teamId,
    AiSuggestionType? type,
    String? title,
    String? description,
    String? rationale,
    bool clearRationale = false,
    String? targetEntityType,
    bool clearTargetEntityType = false,
    String? targetEntityId,
    bool clearTargetEntityId = false,
    Map<String, dynamic>? proposedPayload,
    Map<String, dynamic>? sourceContext,
    AiSuggestionStatus? status,
    DateTime? createdAt,
    DateTime? reviewedAt,
    bool clearReviewedAt = false,
  }) {
    return AiSuggestion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      teamId: teamId ?? this.teamId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      rationale: clearRationale ? null : (rationale ?? this.rationale),
      targetEntityType: clearTargetEntityType
          ? null
          : (targetEntityType ?? this.targetEntityType),
      targetEntityId:
          clearTargetEntityId ? null : (targetEntityId ?? this.targetEntityId),
      proposedPayload: proposedPayload ?? this.proposedPayload,
      sourceContext: sourceContext ?? this.sourceContext,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: clearReviewedAt ? null : (reviewedAt ?? this.reviewedAt),
    );
  }
}
