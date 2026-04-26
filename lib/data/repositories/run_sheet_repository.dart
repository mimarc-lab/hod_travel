import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/run_sheet_item.dart';
import '../models/run_sheet_share_token.dart';
import '../models/run_sheet_view_mode.dart';

// RunSheetRow DTO is defined in run_sheet_item.dart alongside the model.

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetRepository — execution overlay CRUD
// ─────────────────────────────────────────────────────────────────────────────

abstract class RunSheetRepository {
  Future<List<RunSheetRow>> fetchForTrip(String tripId);

  /// Insert a new row; returns the DB-assigned id.
  Future<String> insert(RunSheetRow row, String teamId);

  /// Upsert a full row. If [row.id] is empty or starts with '_synth_', inserts
  /// and returns the DB-assigned id. Otherwise updates and returns the same id.
  Future<String> upsertRow(RunSheetRow row, String teamId);

  Future<void> updateStatus(String runSheetItemId, RunSheetStatus status);
}

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetShareRepository — share token CRUD
// ─────────────────────────────────────────────────────────────────────────────

abstract class RunSheetShareRepository {
  /// Create a new share token; returns the full persisted token.
  Future<RunSheetShareToken> createToken({
    required String            tripId,
    required String            teamId,
    required RunSheetViewMode  viewMode,
    required String            createdBy,
    String?                    label,
    DateTime?                  expiresAt,
  });

  /// Resolve a token string → token record (null if not found / revoked).
  Future<RunSheetShareToken?> fetchByToken(String token);

  /// All active tokens for a trip (for management UI).
  Future<List<RunSheetShareToken>> fetchForTrip(String tripId);

  /// Soft-delete a token (sets revoked_at).
  Future<void> revokeToken(String id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation — RunSheetRepository
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseRunSheetRepository implements RunSheetRepository {
  final SupabaseClient _client;
  SupabaseRunSheetRepository(this._client);

  @override
  Future<List<RunSheetRow>> fetchForTrip(String tripId) async {
    try {
      final rows = await _client
          .from('run_sheet_items')
          .select()
          .eq('trip_id', tripId)
          .order('sort_order');
      return (rows as List)
          .map((r) => RunSheetRow.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> insert(RunSheetRow row, String teamId) async {
    final payload = Map<String, dynamic>.from(row.toJson(teamId: teamId))
      ..remove('id'); // let Supabase generate it
    final result = await _client
        .from('run_sheet_items')
        .insert(payload)
        .select('id')
        .single();
    return result['id'] as String;
  }

  @override
  Future<String> upsertRow(RunSheetRow row, String teamId) async {
    final isSynthetic = row.id.isEmpty || row.id.startsWith('_synth_');
    if (isSynthetic) {
      return insert(row, teamId);
    }
    final payload = Map<String, dynamic>.from(row.toJson(teamId: teamId))
      ..['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('run_sheet_items').update(payload).eq('id', row.id);
    return row.id;
  }

  @override
  Future<void> updateStatus(
      String runSheetItemId, RunSheetStatus status) async {
    await _client.from('run_sheet_items').update({
      'status':     status.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', runSheetItemId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation — RunSheetShareRepository
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseRunSheetShareRepository implements RunSheetShareRepository {
  final SupabaseClient _client;
  SupabaseRunSheetShareRepository(this._client);

  static const _table = 'run_sheet_share_tokens';

  @override
  Future<RunSheetShareToken> createToken({
    required String            tripId,
    required String            teamId,
    required RunSheetViewMode  viewMode,
    required String            createdBy,
    String?                    label,
    DateTime?                  expiresAt,
  }) async {
    final payload = RunSheetShareToken(
      id:        '', // ignored — DB generates
      tripId:    tripId,
      teamId:    teamId,
      token:     '', // ignored — DB generates via default
      viewMode:  viewMode,
      label:     label,
      expiresAt: expiresAt,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    ).toInsertJson();

    final result = await _client
        .from(_table)
        .insert(payload)
        .select()
        .single();
    return RunSheetShareToken.fromJson(result);
  }

  @override
  Future<RunSheetShareToken?> fetchByToken(String token) async {
    try {
      final result = await _client
          .from(_table)
          .select()
          .eq('token', token)
          .isFilter('revoked_at', null)
          .maybeSingle();
      if (result == null) return null;
      return RunSheetShareToken.fromJson(result);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RunSheetShareToken>> fetchForTrip(String tripId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('trip_id', tripId)
          .isFilter('revoked_at', null)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => RunSheetShareToken.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> revokeToken(String id) async {
    await _client.from(_table).update({
      'revoked_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
