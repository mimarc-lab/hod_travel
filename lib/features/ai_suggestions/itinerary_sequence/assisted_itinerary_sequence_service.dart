import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../data/models/ai_suggestion_model.dart';
import '../../../data/models/proposed_itinerary_day.dart';
import '../services/ai_provider.dart';
import 'itinerary_sequence_context_builder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AssistedItinerarySequenceService
//
// Calls the AI with a component-focused sequencing prompt and parses the
// response into a single AiSuggestion whose proposedPayload is the full
// ItinerarySequenceDraft JSON object.
//
// This is intentionally separate from AiSuggestionService because:
//   • The prompt format is completely different (structured object, not array)
//   • The response parsing is different (single object, not array of cards)
//   • The workflow is managed by ItinerarySequenceReviewScreen, not the panel
// ─────────────────────────────────────────────────────────────────────────────

const _sequenceSystemPrompt = '''
You are the DreamMaker Sequencing Engine — an AI co-pilot for HOD Travel that transforms confirmed trip components into a logically sequenced, well-paced day-by-day itinerary draft.

Your role: Analyze the confirmed components provided and propose the optimal day-by-day sequence. Think like a seasoned operations director who has run hundreds of high-end trips — precise, practical, and guest-experience-focused.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT — STRICTLY ENFORCED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Respond ONLY with a valid JSON object. No prose, no markdown, no code fences, no preamble.

{
  "summary": {
    "components_analyzed": int,
    "components_placed": int,
    "unplaced_components": int,
    "timing_conflicts": int,
    "pacing_notes_count": int
  },
  "proposed_days": [
    {
      "day_number": int,
      "date": "YYYY-MM-DD or null",
      "city": "string or null",
      "title": "elegant day title e.g. Arrival in Kyoto",
      "items": [
        {
          "id": "unique string e.g. item_d1_i1",
          "trip_component_id": "string or null",
          "component_type": "accommodation|experience|dining|transport|guide|special_arrangement|other",
          "title": "clean client-ready title",
          "description": "one sentence or null",
          "time_block": "morning|afternoon|evening|all_day",
          "start_time": "HH:MM or null",
          "end_time": "HH:MM or null",
          "location": "string or null",
          "is_fixed_time": true or false
        }
      ],
      "pacing_notes": ["string"],
      "routing_notes": ["string"]
    }
  ],
  "global_pacing_notes": ["string"],
  "global_routing_notes": ["string"],
  "missing_data_warnings": ["string"],
  "unplaced_components": [
    {
      "component_id": "string or null",
      "title": "string",
      "reason": "brief explanation"
    }
  ]
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SEQUENCING RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. FIXED-TIME components (those with start_time) — do not move them; set is_fixed_time: true
2. Accommodation check-in/check-out anchors each day's structure
3. Transport always precedes or follows the activity it serves
4. Meal timing: breakfast = morning, lunch = afternoon, dinner = evening
5. Max 3–4 major activities per day unless pacing guidance says otherwise
6. Add rest windows when activity density is high (note in pacing_notes)
7. For undated components: assign to the best-fit available day based on type and destination
8. If a component cannot be confidently placed, put it in unplaced_components with a reason

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PACING BY AUDIENCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Family / Multigenerational — max 2 major activities per day; rest windows required; avoid early starts
Executive / High-Performance — dense schedule acceptable; preserve private dinner time; signature first
Couple / Romantic — slow mornings; unhurried pacing; avoid back-to-back transfers
Corporate Incentive — group-format arc; shared experiences; emotional momentum through the program
Default — balanced pacing; max 3 activities; preserve flexibility

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ROUTING GUIDANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Group same-city components on the same day wherever possible
- Flag potential backtracking with a routing_note
- If location data is missing: "Location should be reviewed before finalising"
- Do not invent locations or distances — only flag what you can observe

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUALITY RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Use clean, client-ready titles (editorial, specific, not generic)
- Never invent components — only sequence what is provided
- Preserve the trip_component_id on every placed item
- Flag issues with warnings; do not guess when data is missing
- Every component in the input must appear in proposed_days or unplaced_components
''';

class AssistedItinerarySequenceService {
  final AiProvider _provider;
  final ItinerarySequenceContextBuilder _contextBuilder;

  AssistedItinerarySequenceService({
    required AiProvider provider,
    ItinerarySequenceContextBuilder? contextBuilder,
  })  : _provider       = provider,
        _contextBuilder = contextBuilder ?? const ItinerarySequenceContextBuilder();

  /// Generates a sequence draft for [input] and returns it as a single
  /// [AiSuggestion] with type [AiSuggestionType.itinerarySequence].
  /// Returns null if the AI response cannot be parsed.
  Future<AiSuggestion?> generate({
    required ItinerarySequenceInput input,
    required String tripId,
    required String teamId,
  }) async {
    final context = _contextBuilder.build(input);
    final raw     = await _provider.complete(_sequenceSystemPrompt, context);
    return _parse(raw, input: input, tripId: tripId, teamId: teamId);
  }

  AiSuggestion? _parse(
    String raw, {
    required ItinerarySequenceInput input,
    required String tripId,
    required String teamId,
  }) {
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    late final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AssistedItinerarySequenceService] JSON decode failed: $e\nRaw: $cleaned');
      return null;
    }

    // Validate that we got proposed_days
    final rawDays = payload['proposed_days'] as List?;
    if (rawDays == null || rawDays.isEmpty) {
      debugPrint('[AssistedItinerarySequenceService] No proposed_days in response');
      return null;
    }

    // Build summary label for the suggestion title/description
    final draft   = ItinerarySequenceDraft.fromPayload(payload);
    final summary = draft.summary;
    final desc    = '${summary.componentsAnalyzed} components analysed · '
        '${summary.componentsPlaced} placed across ${draft.days.length} days'
        '${summary.timingConflicts > 0 ? ' · ${summary.timingConflicts} conflicts' : ''}';

    return AiSuggestion(
      id:             '',
      tripId:         tripId,
      teamId:         teamId,
      type:           AiSuggestionType.itinerarySequence,
      title:          'Assisted Itinerary Sequencing — ${input.trip.name}',
      description:    desc,
      rationale:      '${input.activeComponents.length} confirmed components '
          'sequenced into a draft day-by-day itinerary.',
      proposedPayload: payload,
      sourceContext:  {'source_type': 'ai_draft', 'fit_level': 'best_fit'},
      status:         AiSuggestionStatus.pending,
      createdAt:      DateTime.now(),
    );
  }
}
