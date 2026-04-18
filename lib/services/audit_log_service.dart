import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/audit_log.dart';
import '../core/supabase/app_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuditLogService
//
// Fire-and-forget client-side logging for SELECT/view events.
// Write events (INSERT, UPDATE, DELETE) are captured automatically by the
// fn_audit_dossier_write trigger on the Supabase side.
// ─────────────────────────────────────────────────────────────────────────────

class AuditLogService {
  final SupabaseClient _client;

  AuditLogService(this._client);

  // ── Logging ────────────────────────────────────────────────────────────────

  void log({
    required String actionType,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) {
    final userId = _client.auth.currentUser?.id;
    final teamId = AppRepositories.instance?.currentTeamId;
    if (userId == null || teamId == null || teamId.isEmpty) return;

    _client.from('audit_logs').insert({
      'user_id':       userId,
      'team_id':       teamId,
      'action_type':   actionType,
      'entity_type':   entityType,
      'entity_id':     entityId,
      'metadata_json': metadata ?? <String, dynamic>{},
    }).catchError((_) {}); // fire-and-forget, never throw
  }

  void logDossierView(String dossierId) => log(
    actionType: AuditActionType.view,
    entityType: AuditEntityType.clientDossier,
    entityId:   dossierId,
  );

  void logSensitiveNoteAccess(String dossierId) => log(
    actionType: AuditActionType.view,
    entityType: AuditEntityType.sensitiveNote,
    entityId:   dossierId,
    metadata:   {'context': 'internal_notes_section'},
  );

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Fetches recent audit logs for a specific dossier (admin use).
  Future<List<AuditLog>> fetchForDossier(String dossierId,
      {int limit = 50}) async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select()
          .eq('entity_id', dossierId)
          .order('created_at', ascending: false)
          .limit(limit) as List;
      return rows
          .map((r) => AuditLog.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches recent audit logs for the team (admin use).
  Future<List<AuditLog>> fetchForTeam(String teamId,
      {int limit = 100}) async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select()
          .eq('team_id', teamId)
          .order('created_at', ascending: false)
          .limit(limit) as List;
      return rows
          .map((r) => AuditLog.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
