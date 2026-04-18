import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/signature_experience.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SignatureExperienceRepository {
  Future<List<SignatureExperience>> fetchAll(String teamId);
  Future<SignatureExperience?> fetchById(String id);
  Future<SignatureExperience> create(SignatureExperience experience, String teamId);
  Future<SignatureExperience> update(SignatureExperience experience);
  Future<void> delete(String id);

  /// Realtime stream — emits the full list whenever any row in [teamId] changes.
  Stream<List<SignatureExperience>> watchForTeam(String teamId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

SignatureExperience _fromRow(Map<String, dynamic> r) {
  List<String> strList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  return SignatureExperience(
    id:                           r['id'] as String,
    teamId:                       r['team_id'] as String?,
    title:                        r['title'] as String,
    status:                       ExperienceStatusX.fromDb(r['status'] as String? ?? 'draft'),
    category:                     ExperienceCategoryX.fromDb(r['category'] as String? ?? 'other'),
    experienceType:               ExperienceTypeX.fromDb(r['experience_type'] as String? ?? 'private'),
    shortDescriptionClient:       r['short_description_client'] as String?,
    longDescriptionInternal:      r['long_description_internal'] as String?,
    conceptSummary:               r['concept_summary'] as String?,
    audienceSuitability:          strList(r['audience_suitability']),
    destinationFlexibility:       ExperienceFlexibilityX.fromDb(r['destination_flexibility'] as String? ?? 'adaptable'),
    tags:                         strList(r['tags']),
    durationLabel:                r['duration_label'] as String?,
    idealGroupSizeMin:            r['ideal_group_size_min'] as int?,
    idealGroupSizeMax:            r['ideal_group_size_max'] as int?,
    indoorOutdoorType:            r['indoor_outdoor_type'] as String?,
    locationNotes:                r['location_notes'] as String?,
    productionNotes:              r['production_notes'] as String?,
    setupRequirements:            r['setup_requirements'] as String?,
    executionComplexity:          r['execution_complexity'] as String?,
    requiredStaffRoles:           strList(r['required_staff_roles']),
    requiredSuppliers:            strList(r['required_suppliers']),
    costingNotes:                 r['costing_notes'] as String?,
    pricingNotes:                 r['pricing_notes'] as String?,
    culturalSensitivityNotes:     r['cultural_sensitivity_notes'] as String?,
    politicalSensitivityNotes:    r['political_sensitivity_notes'] as String?,
    securityNotes:                r['security_notes'] as String?,
    mediaLinks:                   strList(r['media_links']),
    briefingNotes:                r['briefing_notes'] as String?,
    createdBy:                    r['created_by'] as String?,
    createdAt:                    r['created_at'] != null ? DateTime.parse(r['created_at'] as String) : null,
    updatedAt:                    r['updated_at'] != null ? DateTime.parse(r['updated_at'] as String) : null,
  );
}

Map<String, dynamic> _toRow(SignatureExperience e, {String? teamId}) => {
  'team_id': ?teamId,
  'title':                        e.title,
  'status':                       e.status.dbValue,
  'category':                     e.category.dbValue,
  'experience_type':              e.experienceType.dbValue,
  'short_description_client':     e.shortDescriptionClient,
  'long_description_internal':    e.longDescriptionInternal,
  'concept_summary':              e.conceptSummary,
  'audience_suitability':         e.audienceSuitability,
  'destination_flexibility':      e.destinationFlexibility.dbValue,
  'tags':                         e.tags,
  'duration_label':               e.durationLabel,
  'ideal_group_size_min':         e.idealGroupSizeMin,
  'ideal_group_size_max':         e.idealGroupSizeMax,
  'indoor_outdoor_type':          e.indoorOutdoorType,
  'location_notes':               e.locationNotes,
  'production_notes':             e.productionNotes,
  'setup_requirements':           e.setupRequirements,
  'execution_complexity':         e.executionComplexity,
  'required_staff_roles':         e.requiredStaffRoles,
  'required_suppliers':           e.requiredSuppliers,
  'costing_notes':                e.costingNotes,
  'pricing_notes':                e.pricingNotes,
  'cultural_sensitivity_notes':   e.culturalSensitivityNotes,
  'political_sensitivity_notes':  e.politicalSensitivityNotes,
  'security_notes':               e.securityNotes,
  'media_links':                  e.mediaLinks,
  'briefing_notes':               e.briefingNotes,
};

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseSignatureExperienceRepository
    implements SignatureExperienceRepository {
  final SupabaseClient _client;
  SupabaseSignatureExperienceRepository(this._client);

  @override
  Future<List<SignatureExperience>> fetchAll(String teamId) async {
    final rows = await _client
        .from('signature_experiences')
        .select()
        .eq('team_id', teamId)
        .order('title');
    return (rows as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SignatureExperience?> fetchById(String id) async {
    final row = await _client
        .from('signature_experiences')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row != null ? _fromRow(row) : null;
  }

  @override
  Future<SignatureExperience> create(
    SignatureExperience experience,
    String teamId,
  ) async {
    final row = await _client
        .from('signature_experiences')
        .insert({
          ..._toRow(experience, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  @override
  Future<SignatureExperience> update(SignatureExperience experience) async {
    final row = await _client
        .from('signature_experiences')
        .update(_toRow(experience))
        .eq('id', experience.id)
        .select()
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('signature_experiences').delete().eq('id', id);
  }

  @override
  Stream<List<SignatureExperience>> watchForTeam(String teamId) {
    final controller = StreamController<List<SignatureExperience>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchAll(teamId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('signature_experiences:$teamId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'signature_experiences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
