import '../../../data/models/run_sheet_instruction_template.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetInstructionTemplateService
//
// Resolves suggested instructions for a given item type. Uses the hardcoded
// DefaultInstructionTemplates as the base. Team-customized DB templates can
// be layered on top in a future iteration.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetInstructionTemplateService {
  const RunSheetInstructionTemplateService();

  /// Returns suggested instructions for [itemTypeDbValue] (e.g. 'accommodation',
  /// 'transport', 'dining'). Returns null if no templates exist for the type.
  SuggestedInstructions? suggestFor(String itemTypeDbValue) =>
      DefaultInstructionTemplates.buildFor(itemTypeDbValue);

  bool hasTemplatesFor(String itemTypeDbValue) =>
      DefaultInstructionTemplates.hasTemplatesFor(itemTypeDbValue);
}
