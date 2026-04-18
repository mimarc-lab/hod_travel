import 'approval_model.dart';

// =============================================================================
// ApprovalRecord — immutable audit trail entry for an approval decision.
// Append-only: one row per transition, never updated or deleted.
// Covers tasks, itinerary_items, and cost_items.
// =============================================================================

enum ApprovalEntityType { task, itineraryItem, costItem }

extension ApprovalEntityTypeX on ApprovalEntityType {
  String get dbValue => switch (this) {
        ApprovalEntityType.task          => 'task',
        ApprovalEntityType.itineraryItem => 'itinerary_item',
        ApprovalEntityType.costItem      => 'cost_item',
      };
}

ApprovalEntityType approvalEntityTypeFromDb(String s) => switch (s) {
      'itinerary_item' => ApprovalEntityType.itineraryItem,
      'cost_item'      => ApprovalEntityType.costItem,
      _                => ApprovalEntityType.task,
    };

// -----------------------------------------------------------------------------

class ApprovalRecord {
  final String id;
  final String teamId;
  final ApprovalEntityType entityType;
  final String entityId;
  final ApprovalStatus status;
  final String? actorId;
  final String? actorName; // resolved from profiles join
  final String? notes;
  final DateTime createdAt;

  const ApprovalRecord({
    required this.id,
    required this.teamId,
    required this.entityType,
    required this.entityId,
    required this.status,
    this.actorId,
    this.actorName,
    this.notes,
    required this.createdAt,
  });

  factory ApprovalRecord.fromMap(Map<String, dynamic> m) {
    final profileMap = m['profiles'] as Map<String, dynamic>?;
    return ApprovalRecord(
      id:         m['id'] as String,
      teamId:     m['team_id'] as String,
      entityType: approvalEntityTypeFromDb(m['entity_type'] as String? ?? 'task'),
      entityId:   m['entity_id'] as String,
      status:     _parseStatus(m['status'] as String? ?? 'draft'),
      actorId:    m['actor_id'] as String?,
      actorName:  profileMap?['full_name'] as String?,
      notes:      m['notes'] as String?,
      createdAt:  DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'team_id':     teamId,
        'entity_type': entityType.dbValue,
        'entity_id':   entityId,
        'status':      status.dbValue,
        'actor_id':    actorId,
        'notes':       notes,
      };

  static ApprovalStatus _parseStatus(String s) => switch (s) {
        'ready_for_review' => ApprovalStatus.pendingReview,
        'approved'         => ApprovalStatus.approved,
        'rejected'         => ApprovalStatus.rejected,
        _                  => ApprovalStatus.draft,
      };
}
