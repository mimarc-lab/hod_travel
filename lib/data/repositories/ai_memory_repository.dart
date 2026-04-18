import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_memory_record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiMemoryRepository — abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class AiMemoryRepository {
  // Feedback events
  Future<void> recordFeedback(SuggestionFeedbackEvent event);
  Future<List<SuggestionFeedbackEvent>> fetchFeedbackForDossier(
      String dossierId, {int limit = 200});
  Future<List<SuggestionFeedbackEvent>> fetchFeedbackByType(
      String teamId, String suggestionType, {int limit = 200});

  // Inferred preference signals
  Future<void> upsertSignal(InferredPreferenceSignal signal);
  Future<List<InferredPreferenceSignal>> fetchSignalsForDossier(String dossierId);
  Future<void> deleteSignal(String signalId);

  // General memory records
  Future<void> upsertMemoryRecord(AiMemoryRecord record);
  Future<List<AiMemoryRecord>> fetchMemoryForDossier(String dossierId);
  Future<List<AiMemoryRecord>> fetchMemoryForTeam(String teamId,
      {MemoryType? type, int limit = 100});
  Future<void> deleteMemoryRecord(String recordId);
}

// ─────────────────────────────────────────────────────────────────────────────
// SupabaseAiMemoryRepository
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseAiMemoryRepository implements AiMemoryRepository {
  final SupabaseClient _client;

  const SupabaseAiMemoryRepository(this._client);

  static const _feedbackTable  = 'suggestion_feedback_events';
  static const _signalsTable   = 'inferred_preference_signals';
  static const _memoryTable    = 'ai_memory_records';

  // ── Feedback events ────────────────────────────────────────────────────────

  @override
  Future<void> recordFeedback(SuggestionFeedbackEvent event) async {
    await _client.from(_feedbackTable).insert(event.toMap());
  }

  @override
  Future<List<SuggestionFeedbackEvent>> fetchFeedbackForDossier(
      String dossierId, {int limit = 200}) async {
    final rows = await _client
        .from(_feedbackTable)
        .select()
        .eq('dossier_id', dossierId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(SuggestionFeedbackEvent.fromMap).toList();
  }

  @override
  Future<List<SuggestionFeedbackEvent>> fetchFeedbackByType(
      String teamId, String suggestionType, {int limit = 200}) async {
    final rows = await _client
        .from(_feedbackTable)
        .select()
        .eq('team_id', teamId)
        .eq('suggestion_type', suggestionType)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(SuggestionFeedbackEvent.fromMap).toList();
  }

  // ── Inferred preference signals ────────────────────────────────────────────

  @override
  Future<void> upsertSignal(InferredPreferenceSignal signal) async {
    await _client
        .from(_signalsTable)
        .upsert(signal.toMap(), onConflict: 'dossier_id,signal_key');
  }

  @override
  Future<List<InferredPreferenceSignal>> fetchSignalsForDossier(
      String dossierId) async {
    final rows = await _client
        .from(_signalsTable)
        .select()
        .eq('dossier_id', dossierId)
        .order('updated_at', ascending: false);
    return rows.map(InferredPreferenceSignal.fromMap).toList();
  }

  @override
  Future<void> deleteSignal(String signalId) async {
    await _client.from(_signalsTable).delete().eq('id', signalId);
  }

  // ── General memory records ─────────────────────────────────────────────────

  @override
  Future<void> upsertMemoryRecord(AiMemoryRecord record) async {
    await _client.from(_memoryTable).upsert(record.toMap());
  }

  @override
  Future<List<AiMemoryRecord>> fetchMemoryForDossier(String dossierId) async {
    final rows = await _client
        .from(_memoryTable)
        .select()
        .eq('dossier_id', dossierId)
        .order('updated_at', ascending: false);
    return rows.map(AiMemoryRecord.fromMap).toList();
  }

  @override
  Future<List<AiMemoryRecord>> fetchMemoryForTeam(String teamId,
      {MemoryType? type, int limit = 100}) async {
    var query = _client
        .from(_memoryTable)
        .select()
        .eq('team_id', teamId);
    if (type != null) {
      query = query.eq('memory_type', type.dbValue);
    }
    final rows = await query
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows.map(AiMemoryRecord.fromMap).toList();
  }

  @override
  Future<void> deleteMemoryRecord(String recordId) async {
    await _client.from(_memoryTable).delete().eq('id', recordId);
  }
}
