// ─────────────────────────────────────────────────────────────────────────────
// InstructionsSource — how instructions were produced
// ─────────────────────────────────────────────────────────────────────────────

enum InstructionsSource {
  manual,
  suggested,
  editedAfterSuggestion;

  String get dbValue => switch (this) {
        InstructionsSource.manual                => 'manual',
        InstructionsSource.suggested             => 'suggested',
        InstructionsSource.editedAfterSuggestion => 'edited_after_suggestion',
      };

  static InstructionsSource? fromDb(String? raw) => switch (raw) {
        'manual'                  => InstructionsSource.manual,
        'suggested'               => InstructionsSource.suggested,
        'edited_after_suggestion' => InstructionsSource.editedAfterSuggestion,
        _                         => null,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// InstructionType — which of the three instruction slots
// ─────────────────────────────────────────────────────────────────────────────

enum InstructionType {
  operational,
  contingency,
  escalation;

  String get label => switch (this) {
        InstructionType.operational => 'Operational',
        InstructionType.contingency => 'Contingency',
        InstructionType.escalation  => 'Escalation',
      };

  String get dbValue => switch (this) {
        InstructionType.operational => 'operational',
        InstructionType.contingency => 'contingency',
        InstructionType.escalation  => 'escalation',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetInstructionTemplate — DB row model
//
// SQL (run once in Supabase SQL editor):
//
//   create table if not exists run_sheet_instruction_templates (
//     id               uuid primary key default gen_random_uuid(),
//     team_id          uuid references teams(id) on delete cascade,
//     component_type   text not null,
//     instruction_type text not null
//       check (instruction_type in ('operational','contingency','escalation')),
//     template_text    text not null,
//     sort_order       int  not null default 0,
//     is_active        boolean not null default true,
//     created_at       timestamptz not null default now()
//   );
//   create index if not exists idx_rs_instr_tpl_type
//     on run_sheet_instruction_templates(component_type, instruction_type)
//     where is_active = true;
//
//   -- Add instruction columns to run_sheet_items:
//   alter table run_sheet_items
//     add column if not exists operational_instructions  text,
//     add column if not exists contingency_instructions  text,
//     add column if not exists escalation_instructions   text,
//     add column if not exists instructions_source       text
//       check (instructions_source in
//         ('manual','suggested','edited_after_suggestion')),
//     add column if not exists instructions_approved_by  uuid
//       references profiles(id),
//     add column if not exists instructions_approved_at  timestamptz;
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetInstructionTemplate {
  final String          id;
  final String?         teamId;
  final String          componentType;
  final InstructionType instructionType;
  final String          templateText;
  final int             sortOrder;

  const RunSheetInstructionTemplate({
    required this.id,
    this.teamId,
    required this.componentType,
    required this.instructionType,
    required this.templateText,
    this.sortOrder = 0,
  });

  factory RunSheetInstructionTemplate.fromJson(Map<String, dynamic> r) =>
      RunSheetInstructionTemplate(
        id:              r['id']             as String,
        teamId:          r['team_id']        as String?,
        componentType:   r['component_type'] as String,
        instructionType: _parseType(r['instruction_type'] as String? ?? 'operational'),
        templateText:    r['template_text']  as String,
        sortOrder:       r['sort_order']     as int? ?? 0,
      );

  static InstructionType _parseType(String raw) => switch (raw) {
        'contingency' => InstructionType.contingency,
        'escalation'  => InstructionType.escalation,
        _             => InstructionType.operational,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SuggestedInstructions — resolved text for all three slots
// ─────────────────────────────────────────────────────────────────────────────

class SuggestedInstructions {
  final String operational;
  final String contingency;
  final String escalation;

  const SuggestedInstructions({
    required this.operational,
    required this.contingency,
    required this.escalation,
  });

  bool get isEmpty =>
      operational.isEmpty && contingency.isEmpty && escalation.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// DefaultInstructionTemplates — hardcoded defaults by component/item type
// ─────────────────────────────────────────────────────────────────────────────

class DefaultInstructionTemplates {
  DefaultInstructionTemplates._();

  static const Map<String, Map<InstructionType, List<String>>> _data = {
    'hotel': {
      InstructionType.operational: [
        'Reconfirm early check-in request 24 hours prior',
        'Verify accessible room setup',
        'Confirm connecting rooms blocked correctly',
        'Reconfirm VIP amenities placement',
      ],
      InstructionType.contingency: [
        'If room not ready, escalate to hotel manager',
        'Activate alternate arrival holding plan',
      ],
      InstructionType.escalation: [
        'Contact Trip Director if rooming issue unresolved',
      ],
    },
    'transport': {
      InstructionType.operational: [
        'Driver arrive 15 minutes early',
        'Reconfirm pickup point day prior',
        'Carry guest name board if airport arrival',
      ],
      InstructionType.contingency: [
        'If delay exceeds 20 minutes notify Trip Director',
        'Activate backup provider if no-show',
      ],
      InstructionType.escalation: [
        'Escalate transport failure immediately to Trip Director',
      ],
    },
    'flight': {
      InstructionType.operational: [
        'Driver arrive 15 minutes early',
        'Reconfirm pickup point day prior',
        'Carry guest name board for airport arrival',
      ],
      InstructionType.contingency: [
        'If delay exceeds 20 minutes notify Trip Director',
        'Activate backup transport if no-show',
      ],
      InstructionType.escalation: [
        'Escalate transport failure immediately to Trip Director',
      ],
    },
    'dining': {
      InstructionType.operational: [
        'Reconfirm reservation at 3pm day prior',
        'Confirm dietary notes with restaurant',
        'Verify seating arrangement request',
      ],
      InstructionType.contingency: [
        'If reservation issue, activate backup restaurant',
      ],
      InstructionType.escalation: [
        'Notify Trip Lead if service issue affects timing',
      ],
    },
    'experience': {
      InstructionType.operational: [
        'Reconfirm supplier start time day prior',
        'Verify equipment requirements',
        'Brief guide on guest preferences',
      ],
      InstructionType.contingency: [
        'If weather issue, activate backup option',
      ],
      InstructionType.escalation: [
        'Escalate if supplier unable to deliver',
      ],
    },
    'guide': {
      InstructionType.operational: [
        'Confirm guide meet location',
        'Verify briefing is complete',
      ],
      InstructionType.contingency: [
        'Backup guide protocol if unavailable',
      ],
      InstructionType.escalation: [
        'Notify Trip Director if guide changes required',
      ],
    },
  };

  static String textFor(String componentType, InstructionType iType) {
    final bullets = _data[componentType]?[iType];
    if (bullets == null || bullets.isEmpty) return '';
    return bullets.map((b) => '• $b').join('\n');
  }

  static bool hasTemplatesFor(String componentType) =>
      _data.containsKey(componentType);

  static SuggestedInstructions? buildFor(String componentType) {
    if (!hasTemplatesFor(componentType)) return null;
    return SuggestedInstructions(
      operational: textFor(componentType, InstructionType.operational),
      contingency:  textFor(componentType, InstructionType.contingency),
      escalation:   textFor(componentType, InstructionType.escalation),
    );
  }
}
