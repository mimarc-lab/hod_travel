import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_suggestion_model.dart';

// ── Abstract interface ────────────────────────────────────────────────────────

abstract class AiSuggestionRepository {
  Future<List<AiSuggestion>> fetchForTrip(String tripId);
  Future<AiSuggestion> create(AiSuggestion suggestion);
  Future<AiSuggestion> updateStatus(
    String id,
    AiSuggestionStatus status, {
    DateTime? reviewedAt,
  });
  Future<AiSuggestion> updatePayload(
    String id,
    Map<String, dynamic> proposedPayload,
  );
  Future<void> delete(String id);
  Future<void> deleteForTrip(String tripId);
}

// ── Supabase implementation ───────────────────────────────────────────────────

class SupabaseAiSuggestionRepository implements AiSuggestionRepository {
  final SupabaseClient _client;
  static const _table = 'ai_suggestions';

  const SupabaseAiSuggestionRepository(this._client);

  // ── Fetch ──────────────────────────────────────────────────────────────────

  @override
  Future<List<AiSuggestion>> fetchForTrip(String tripId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return rows.map((r) => AiSuggestion.fromJson(r)).toList();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  @override
  Future<AiSuggestion> create(AiSuggestion suggestion) async {
    final row = suggestion.toJson()..remove('id');
    final result = await _client.from(_table).insert(row).select().single();
    return AiSuggestion.fromJson(result);
  }

  // ── Update status ──────────────────────────────────────────────────────────

  @override
  Future<AiSuggestion> updateStatus(
    String id,
    AiSuggestionStatus status, {
    DateTime? reviewedAt,
  }) async {
    final result = await _client
        .from(_table)
        .update({
          'status': status.dbValue,
          'reviewed_at': (reviewedAt ?? DateTime.now()).toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return AiSuggestion.fromJson(result);
  }

  // ── Update payload ─────────────────────────────────────────────────────────

  @override
  Future<AiSuggestion> updatePayload(
    String id,
    Map<String, dynamic> proposedPayload,
  ) async {
    final result = await _client
        .from(_table)
        .update({'proposed_payload': proposedPayload})
        .eq('id', id)
        .select()
        .single();
    return AiSuggestion.fromJson(result);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  @override
  Future<void> deleteForTrip(String tripId) async {
    await _client.from(_table).delete().eq('trip_id', tripId);
  }
}
