import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/repositories/run_sheet_instruction_template_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetInstructionTemplateService
//
// Resolves suggested instructions for a given item type.
// Prefers team-customized DB templates; falls back to hardcoded defaults.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetInstructionTemplateService {
  final RunSheetInstructionTemplateRepository? _repo;
  final String? _teamId;

  const RunSheetInstructionTemplateService({
    RunSheetInstructionTemplateRepository? repo,
    String? teamId,
  })  : _repo   = repo,
        _teamId = teamId;

  Future<SuggestedInstructions?> suggestFor(String itemTypeDbValue) async {
    if (_repo != null && _teamId != null && _teamId!.isNotEmpty) {
      try {
        final all     = await _repo!.fetchForTeam(_teamId!);
        final forType = all.where((t) => t.componentType == itemTypeDbValue).toList();
        if (forType.isNotEmpty) {
          String combine(InstructionType type) => forType
              .where((r) => r.instructionType == type)
              .map((r) => r.templateText)
              .join('\n');
          final s = SuggestedInstructions(
            operational: combine(InstructionType.operational),
            contingency:  combine(InstructionType.contingency),
            escalation:   combine(InstructionType.escalation),
          );
          if (!s.isEmpty) return s;
        }
      } catch (_) {}
    }
    return DefaultInstructionTemplates.buildFor(itemTypeDbValue);
  }

  bool hasTemplatesFor(String itemTypeDbValue) =>
      DefaultInstructionTemplates.hasTemplatesFor(itemTypeDbValue);
}
