import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_dossier_model.dart';
import '../models/client_traveler_model.dart';
import '../models/client_questionnaire_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class ClientDossierRepository {
  // Dossiers
  Future<List<ClientDossier>> fetchAll(String teamId);
  Future<ClientDossier?> fetchById(String id);
  Future<ClientDossier> create(ClientDossier dossier, String teamId);
  Future<ClientDossier> update(ClientDossier dossier);
  Future<void> delete(String id);
  Stream<List<ClientDossier>> watchForTeam(String teamId);

  // Travelers
  Future<ClientTraveler> addTraveler(ClientTraveler traveler);
  Future<ClientTraveler> updateTraveler(ClientTraveler traveler);
  Future<void> deleteTraveler(String id);

  // Questionnaire
  Future<ClientQuestionnaireResponse> saveQuestionnaireResponse(
      ClientQuestionnaireResponse response, String dossierId, String teamId);
  Future<List<ClientQuestionnaireResponse>> fetchQuestionnaireResponses(
      String dossierId);
  Future<ClientQuestionnaireResponse> upsertDraft(
      ClientQuestionnaireResponse response, String dossierId, String teamId);
  Future<ClientQuestionnaireResponse> submitResponse(
      ClientQuestionnaireResponse response, String dossierId, String teamId);
  Future<ClientQuestionnaireResponse?> fetchLatestDraft(String dossierId);
  Future<ClientQuestionnaireResponse?> fetchResponseById(String id);
  Future<void> markApplied(String id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseClientDossierRepository implements ClientDossierRepository {
  final SupabaseClient _client;
  SupabaseClientDossierRepository(this._client);

  // ── Travelers loader ───────────────────────────────────────────────────────

  Future<Map<String, List<ClientTraveler>>> _loadTravelers(
      List<String> dossierIds) async {
    if (dossierIds.isEmpty) return {};
    final rows = await _client
        .from('client_travelers')
        .select()
        .inFilter('dossier_id', dossierIds)
        .order('sort_order');
    final result = <String, List<ClientTraveler>>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final did = row['dossier_id'] as String;
      result.putIfAbsent(did, () => []).add(ClientTraveler.fromMap(row));
    }
    return result;
  }

  // ── Dossiers ───────────────────────────────────────────────────────────────

  @override
  Future<List<ClientDossier>> fetchAll(String teamId) async {
    final rows = await _client
        .from('client_dossiers')
        .select()
        .eq('team_id', teamId)
        .order('primary_client_name');
    final list = rows as List;
    final ids  = list.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
    final travelers = await _loadTravelers(ids);
    return list.map((r) {
      final row = r as Map<String, dynamic>;
      return ClientDossier.fromMap(row, travelers: travelers[row['id']] ?? []);
    }).toList();
  }

  @override
  Future<ClientDossier?> fetchById(String id) async {
    final row = await _client
        .from('client_dossiers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final travelers = await _loadTravelers([id]);
    return ClientDossier.fromMap(row, travelers: travelers[id] ?? []);
  }

  @override
  Future<ClientDossier> create(ClientDossier dossier, String teamId) async {
    final row = await _client
        .from('client_dossiers')
        .insert({
          ...dossier.toMap(teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return ClientDossier.fromMap(row);
  }

  @override
  Future<ClientDossier> update(ClientDossier dossier) async {
    final row = await _client
        .from('client_dossiers')
        .update({
          ...dossier.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', dossier.id)
        .select()
        .single();
    final travelers = await _loadTravelers([dossier.id]);
    return ClientDossier.fromMap(row, travelers: travelers[dossier.id] ?? []);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('client_dossiers').delete().eq('id', id);
  }

  @override
  Stream<List<ClientDossier>> watchForTeam(String teamId) {
    final controller = StreamController<List<ClientDossier>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchAll(teamId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('client_dossiers:$teamId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_dossiers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'client_travelers',
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ── Travelers ──────────────────────────────────────────────────────────────

  @override
  Future<ClientTraveler> addTraveler(ClientTraveler traveler) async {
    final row = await _client
        .from('client_travelers')
        .insert(traveler.toMap(dossierId: traveler.dossierId))
        .select()
        .single();
    return ClientTraveler.fromMap(row);
  }

  @override
  Future<ClientTraveler> updateTraveler(ClientTraveler traveler) async {
    final row = await _client
        .from('client_travelers')
        .update(traveler.toMap())
        .eq('id', traveler.id)
        .select()
        .single();
    return ClientTraveler.fromMap(row);
  }

  @override
  Future<void> deleteTraveler(String id) async {
    await _client.from('client_travelers').delete().eq('id', id);
  }

  // ── Questionnaire ──────────────────────────────────────────────────────────

  @override
  Future<ClientQuestionnaireResponse> saveQuestionnaireResponse(
    ClientQuestionnaireResponse response,
    String dossierId,
    String teamId,
  ) async {
    final row = await _client
        .from('client_questionnaire_responses')
        .insert({
          ...response.toMap(dossierId: dossierId, teamId: teamId),
          'completed_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return ClientQuestionnaireResponse.fromMap(row);
  }

  @override
  Future<List<ClientQuestionnaireResponse>> fetchQuestionnaireResponses(
      String dossierId) async {
    final rows = await _client
        .from('client_questionnaire_responses')
        .select()
        .eq('dossier_id', dossierId)
        .order('completed_at', ascending: false);
    return (rows as List)
        .map((r) => ClientQuestionnaireResponse.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  static const _qTable = 'client_questionnaire_responses';

  @override
  Future<ClientQuestionnaireResponse> upsertDraft(
    ClientQuestionnaireResponse response,
    String dossierId,
    String teamId,
  ) async {
    final data = {
      ...response.toMap(dossierId: dossierId, teamId: teamId),
      'status': 'draft',
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (response.id.isNotEmpty) {
      final row = await _client
          .from(_qTable)
          .update(data)
          .eq('id', response.id)
          .select()
          .single();
      return ClientQuestionnaireResponse.fromMap(row);
    }
    data['completed_by'] = _client.auth.currentUser?.id;
    final row = await _client.from(_qTable).insert(data).select().single();
    return ClientQuestionnaireResponse.fromMap(row);
  }

  @override
  Future<ClientQuestionnaireResponse> submitResponse(
    ClientQuestionnaireResponse response,
    String dossierId,
    String teamId,
  ) async {
    final now = DateTime.now().toIso8601String();
    final data = {
      ...response.toMap(dossierId: dossierId, teamId: teamId),
      'status': 'submitted',
      'completed_at': now,
      'updated_at': now,
      'completed_by': _client.auth.currentUser?.id,
    };
    if (response.id.isNotEmpty) {
      final row = await _client
          .from(_qTable)
          .update(data)
          .eq('id', response.id)
          .select()
          .single();
      return ClientQuestionnaireResponse.fromMap(row);
    }
    final row = await _client.from(_qTable).insert(data).select().single();
    return ClientQuestionnaireResponse.fromMap(row);
  }

  @override
  Future<ClientQuestionnaireResponse?> fetchLatestDraft(
      String dossierId) async {
    try {
      final row = await _client
          .from(_qTable)
          .select()
          .eq('dossier_id', dossierId)
          .eq('status', 'draft')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return ClientQuestionnaireResponse.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ClientQuestionnaireResponse?> fetchResponseById(String id) async {
    try {
      final row = await _client
          .from(_qTable)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return ClientQuestionnaireResponse.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markApplied(String id) async {
    await _client.from(_qTable).update({
      'status': 'applied',
      'applied_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
