abstract class AuditActionType {
  static const view   = 'view';
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
}

abstract class AuditEntityType {
  static const clientDossier   = 'client_dossiers';
  static const sensitiveNote   = 'client_sensitive_notes';
  static const questionnaire   = 'client_questionnaire_responses';
}

class AuditLog {
  final String id;
  final String userId;
  final String teamId;
  final String actionType;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> metadataJson;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.metadataJson,
    required this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
    id:           m['id'] as String,
    userId:       m['user_id'] as String,
    teamId:       m['team_id'] as String,
    actionType:   m['action_type'] as String,
    entityType:   m['entity_type'] as String,
    entityId:     m['entity_id'] as String,
    metadataJson: (m['metadata_json'] as Map?)?.cast<String, dynamic>() ?? {},
    createdAt:    DateTime.parse(m['created_at'] as String),
  );
}
