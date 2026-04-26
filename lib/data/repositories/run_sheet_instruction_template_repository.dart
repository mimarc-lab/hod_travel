import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/run_sheet_instruction_template.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetInstructionTemplateRepository
// ─────────────────────────────────────────────────────────────────────────────

abstract class RunSheetInstructionTemplateRepository {
  Future<List<RunSheetInstructionTemplate>> fetchForTeam(String teamId);

  Future<RunSheetInstructionTemplate> create({
    required String          teamId,
    required String          componentType,
    required InstructionType instructionType,
    required String          templateText,
    int                      sortOrder = 0,
  });

  Future<void> update(RunSheetInstructionTemplate template);

  Future<void> delete(String id);
}

// ─────────────────────────────────────────────────────────────────────────────
// SupabaseRunSheetInstructionTemplateRepository
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseRunSheetInstructionTemplateRepository
    implements RunSheetInstructionTemplateRepository {
  final SupabaseClient _client;
  SupabaseRunSheetInstructionTemplateRepository(this._client);

  static const _table = 'run_sheet_instruction_templates';

  @override
  Future<List<RunSheetInstructionTemplate>> fetchForTeam(String teamId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('team_id', teamId)
          .eq('is_active', true)
          .order('component_type')
          .order('sort_order');
      return (rows as List)
          .map((r) => RunSheetInstructionTemplate.fromJson(
                r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RunSheetInstructionTemplate> create({
    required String          teamId,
    required String          componentType,
    required InstructionType instructionType,
    required String          templateText,
    int                      sortOrder = 0,
  }) async {
    final row = await _client.from(_table).insert({
      'team_id':        teamId,
      'component_type': componentType,
      'instruction_type': instructionType.dbValue,
      'template_text':  templateText,
      'sort_order':     sortOrder,
      'is_active':      true,
    }).select().single();
    return RunSheetInstructionTemplate.fromJson(row);
  }

  @override
  Future<void> update(RunSheetInstructionTemplate template) async {
    await _client.from(_table).update({
      'template_text':    template.templateText,
      'instruction_type': template.instructionType.dbValue,
      'sort_order':       template.sortOrder,
    }).eq('id', template.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
