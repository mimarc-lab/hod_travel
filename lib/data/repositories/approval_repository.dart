import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_record_model.dart';
import '../models/approval_model.dart';
import '../../core/errors/app_exception.dart';

// =============================================================================
// ApprovalRepository
// Reads the append-only approval_records audit trail.
// Write path: approval records are created automatically by DB triggers on
// tasks/itinerary_items/cost_items approval_status updates.
// Direct inserts are supported for manual overrides.
// =============================================================================

abstract class ApprovalRepository {
  /// Full approval history for one entity, newest first.
  Future<List<ApprovalRecord>> fetchHistory({
    required String entityId,
    required ApprovalEntityType entityType,
  });

  /// All approval records for a team, optionally filtered by status.
  Future<List<ApprovalRecord>> fetchForTeam(
    String teamId, {
    ApprovalStatus? status,
  });

  /// Manually insert an approval record (rare — usually done by DB trigger).
  Future<ApprovalRecord> create(ApprovalRecord record);
}

// =============================================================================
// Supabase implementation
// =============================================================================

class SupabaseApprovalRepository implements ApprovalRepository {
  final SupabaseClient _client;
  SupabaseApprovalRepository(this._client);

  @override
  Future<List<ApprovalRecord>> fetchHistory({
    required String entityId,
    required ApprovalEntityType entityType,
  }) =>
      guardDb(() async {
        final rows = await _client
            .from('approval_records')
            .select('*, profiles(full_name)')
            .eq('entity_id', entityId)
            .eq('entity_type', entityType.dbValue)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => ApprovalRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<ApprovalRecord>> fetchForTeam(
    String teamId, {
    ApprovalStatus? status,
  }) =>
      guardDb(() async {
        var query = _client
            .from('approval_records')
            .select('*, profiles(full_name)')
            .eq('team_id', teamId);

        if (status != null) {
          query = query.eq('status', status.dbValue);
        }

        final rows = await query.order('created_at', ascending: false);
        return (rows as List)
            .map((r) => ApprovalRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<ApprovalRecord> create(ApprovalRecord record) => guardDb(() async {
        final row = await _client
            .from('approval_records')
            .insert(record.toMap())
            .select('*, profiles(full_name)')
            .single();
        return ApprovalRecord.fromMap(row);
      });
}
