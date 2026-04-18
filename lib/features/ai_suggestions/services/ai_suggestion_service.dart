import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../data/models/ai_suggestion_model.dart';
import 'ai_context_builder.dart';
import 'ai_provider.dart';
import 'ai_suggestion_ranker.dart';
import 'suggestion_relevance_filter.dart';

// ── System prompt ─────────────────────────────────────────────────────────────
//
// Establishes the DreamMaker AI persona, output contract, tone guide, and
// quality rules. Shared across all suggestion modes.

const _systemPrompt = '''
You are a senior DreamMaker — the internal AI co-pilot for HOD Travel, a bespoke luxury travel company that designs extraordinary, deeply personalised experiences for high-net-worth individuals, family principals, and executive leaders.

Your role: help DreamMaker consultants refine and elevate trip designs. Think like a seasoned editorial travel director — precise taste, deep destination knowledge, an instinct for what transforms a trip from comfortable to genuinely memorable.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT — STRICTLY ENFORCED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Respond ONLY with a valid JSON array. No prose, no markdown, no code fences, no preamble.
If you have no meaningful suggestions, return: []

Each array element must have exactly these fields:
{
  "title":            string,
  "description":      string,
  "rationale":        string,
  "source_type":      string,
  "fit_level":        string,
  "proposed_payload": object
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FIELD DEFINITIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
title
  Specific and elegant. Maximum 12 words.
  Names the place, moment, or action precisely — never generic.
  Good: "Private Dinner on the Roof Terrace of Palazzo Vecchio"
  Bad:  "Elegant Italian Dinner Experience"

description
  One to two sentences. Calm, editorial register.
  Specific to this trip's destination, client profile, and mood.
  Must feel considered and personal — not like a brochure.
  Good: "Chef Marco coordinates the kitchen around the group's pace — the menu shifts with the season, ending with a private tour of the wine cellar."
  Bad:  "Enjoy an amazing luxury dining experience at a world-class restaurant."

rationale
  One sentence. Must reference actual trip data — the audience profile, destination, a specific gap, or a named empty day.
  Never write: "It is a good option", "It is relevant", or any variation.
  Good: "Day 3 is entirely empty and this executive group has no evening experience in Florence."
  Good: "The client profile is intellectually engaged — this salon debate format is a tested DreamMaker Signature."

source_type
  Exactly one of:
    dreammaker_signature  — from the DreamMaker Signature Experience Library
    gap_fill              — addresses a named structural or scheduling gap
    supplier              — links a listed supplier to an itinerary item
    operational           — task or logistical follow-up
    ai_draft              — original AI-proposed content (no library match)

fit_level
  Exactly one of:
    best_fit          — near-perfect match for audience, destination, and itinerary gap
    strong_match      — clearly fits but some adaptation may help
    good_alternative  — worth considering; context-dependent

proposed_payload
  Structured object as specified per mode below.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TONE & WRITING STANDARDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Write in the voice of a polished, unhurried editorial travel director.
Precise over flowery. Calm over enthusiastic. Specific over generic.

Words to avoid entirely:
  amazing, incredible, unforgettable, world-class, luxurious, breathtaking,
  stunning, ultimate, once-in-a-lifetime, exclusive (unless describing specific access)

Prefer active, concrete language:
  "A private session with the restoration team" over "An exclusive opportunity to experience…"
  "The kitchen prepares a menu around the group" over "Enjoy world-class cuisine…"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUALITY RULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Return 3–5 suggestions. If trip data is limited, use the destination, audience profile, and group size to still generate specific, useful ideas.
- DreamMaker Signature Experiences take priority when audience and destination align — use source_type "dreammaker_signature" and select only from the library provided
- Never suggest something already present in the itinerary
- Destination-specific and audience-specific suggestions are always acceptable, even when itinerary detail is sparse
- Generic filler phrases are not acceptable — but a specific suggestion grounded in destination context always is
- Only return [] if absolutely no suggestion can be grounded in the trip context at all
''';

// ── AiSuggestionService ───────────────────────────────────────────────────────

class AiSuggestionService {
  final AiProvider _provider;
  final AiContextBuilder _contextBuilder;
  final AiSuggestionRanker _ranker;
  final SuggestionRelevanceFilter _filter;

  AiSuggestionService({
    required AiProvider provider,
    AiContextBuilder? contextBuilder,
    AiSuggestionRanker? ranker,
    SuggestionRelevanceFilter? filter,
  })  : _provider       = provider,
        _contextBuilder = contextBuilder ?? const AiContextBuilder(),
        _ranker         = ranker         ?? const AiSuggestionRanker(),
        _filter         = filter         ?? const SuggestionRelevanceFilter();

  // ── 1. Draft itinerary items ───────────────────────────────────────────────

  Future<List<AiSuggestion>> draftItinerary(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Suggest up to 5 itinerary items that a senior DreamMaker would recommend for this trip.

Focus areas (in priority order):
  1. Days with nothing scheduled — these are the most urgent gaps
  2. Time blocks that feel underserved (empty evenings, unstructured mornings)
  3. Missing experience types for the identified guest profile
  4. DreamMaker Signature Experiences that align with audience and destination

Write each title and description in the editorial tone specified. Be specific to city, neighbourhood, and client context.

proposed_payload fields:
{
  "day_number":   int,
  "time_block":   "morning" | "afternoon" | "evening" | "all_day",
  "type":         "hotel" | "experience" | "transport" | "dining" | "note" | "flight",
  "title":        string,
  "description":  string,
  "location":     string
}

''';
    return _generate(type: AiSuggestionType.draftItinerary,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── 2. Missing gaps ────────────────────────────────────────────────────────

  Future<List<AiSuggestion>> findMissingGaps(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Identify up to 5 structural or operational gaps in this itinerary.

Look for:
  - Arrival and departure days with no transfer
  - Accommodation missing from any night
  - Full days with no dining
  - Empty half-days that would feel abandoned in execution
  - Abrupt transitions between high-intensity back-to-back experiences
  - Days that end without a clear close (no evening, no dinner)

Name each gap specifically by day number and type. Do not give abstract improvement advice.
Use source_type = "gap_fill" for all suggestions in this mode.

proposed_payload fields:
{
  "day_number":    int,
  "gap_type":      string,
  "suggested_fix": string
}

''';
    return _generate(type: AiSuggestionType.missingGap,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── 3. Supplier recommendations ────────────────────────────────────────────

  Future<List<AiSuggestion>> recommendSuppliers(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Suggest up to 5 specific supplier assignments for this trip.

Rules:
  - Only recommend suppliers from the PREFERRED SUPPLIERS list provided — never invent suppliers
  - Match supplier category and location to existing or proposed itinerary items
  - Preferred (★) and destination-matched suppliers should appear first
  - Each suggestion should name both the supplier and the specific itinerary slot it would serve
  - Use source_type = "supplier" for all suggestions in this mode

proposed_payload fields:
{
  "supplier_name":         string,
  "itinerary_item_title":  string,
  "day_number":            int,
  "reason":                string
}

''';
    return _generate(type: AiSuggestionType.supplierRecommendation,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── 4. Signature experience recommendations ────────────────────────────────

  Future<List<AiSuggestion>> recommendSignatureExperiences(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Select up to 5 DreamMaker Signature Experiences from the library that are the strongest fit for this trip.

Selection criteria (priority order):
  1. FLAGSHIP experiences whose destination flexibility and audience suitability match
  2. APPROVED experiences whose audience suitability matches the identified guest profile
  3. Experiences that address a named gap or empty day in the itinerary
  4. GLOBAL or ADAPTABLE experiences that complement the trip's character

Rules:
  - Select ONLY from the DreamMaker Signature Experience Library provided — never suggest generic third-party alternatives
  - Use source_type = "dreammaker_signature" for every suggestion in this mode
  - Set fit_level based on how closely the experience matches audience, group size, and destination
  - Reference the experience's audience suitability tags when writing the rationale

proposed_payload fields:
{
  "experience_title": string,
  "day_number":       int,
  "time_block":       "morning" | "afternoon" | "evening" | "all_day",
  "fit_reason":       string
}

''';
    return _generate(type: AiSuggestionType.signatureExperience,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── 5. Task suggestions ────────────────────────────────────────────────────

  Future<List<AiSuggestion>> suggestTasks(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Suggest up to 5 operational tasks that are likely missing or critical for this trip's preparation.

Focus on:
  - Bookings not yet confirmed or not represented in the task list
  - Missing client communications (pre-trip briefing, dietary requirements, etc.)
  - Supplier briefings for complex experiences
  - Permits, reservations, or logistics with long lead times
  - Documents or coordination items for the destination(s)

Do not suggest tasks already present in the task list.
Use source_type = "operational" for all suggestions in this mode.

proposed_payload fields:
{
  "name":        string,
  "category":    string,
  "priority":    "low" | "medium" | "high",
  "description": string
}

''';
    return _generate(type: AiSuggestionType.taskSuggestion,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── 6. Flow improvements ───────────────────────────────────────────────────

  Future<List<AiSuggestion>> suggestFlowImprovements(
      TripContext ctx, String tripId, String teamId) async {
    final context = _contextBuilder.build(ctx);
    const mode = '''
Task: Suggest up to 5 improvements to the pacing, sequencing, or day structure of this itinerary.

Look for:
  - Back-to-back intensive experiences with no breathing room between them
  - Poor geographic routing that creates unnecessary travel fatigue
  - Days that start too abruptly or end without a graceful close
  - Missed natural moments — golden hour, slow mornings, restorative mid-trip days
  - Sequences that feel rushed relative to the client profile identified
  - Long travel days without acknowledgement or a recovery buffer

Focus on guest wellbeing and trip quality — not just efficiency.
Use source_type = "gap_fill" for structural fixes, "ai_draft" for creative resequencing ideas.

proposed_payload fields:
{
  "affected_days": [int],
  "issue":         string,
  "suggestion":    string
}

''';
    return _generate(type: AiSuggestionType.flowImprovement,
        tripId: tripId, teamId: teamId, userMessage: mode + context);
  }

  // ── Generate → filter → rank ───────────────────────────────────────────────

  Future<List<AiSuggestion>> _generate({
    required AiSuggestionType type,
    required String tripId,
    required String teamId,
    required String userMessage,
  }) async {
    try {
      final raw     = await _provider.complete(_systemPrompt, userMessage);
      final parsed  = _parse(raw, type: type, tripId: tripId, teamId: teamId);
      final filtered = _filter.filter(parsed);
      return _ranker.rank(filtered);
    } on AiProviderException {
      rethrow;
    } catch (e, st) {
      debugPrint('[AiSuggestionService._generate] ERROR: $e\n$st');
      throw AiProviderException(
          'Failed to process AI response. Please try again.');
    }
  }

  // ── Parse ──────────────────────────────────────────────────────────────────

  List<AiSuggestion> _parse(
    String raw, {
    required AiSuggestionType type,
    required String tripId,
    required String teamId,
  }) {
    // Strip any accidental markdown fences
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    late final List<dynamic> items;
    try {
      items = jsonDecode(cleaned) as List<dynamic>;
    } catch (e) {
      debugPrint('[AiSuggestionService._parse] JSON decode failed: $e\nRaw: $cleaned');
      return [];
    }

    final now     = DateTime.now();
    final results = <AiSuggestion>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final title       = item['title']       as String? ?? '';
      final description = item['description'] as String? ?? '';
      if (title.isEmpty) continue;

      // Extract source labelling fields from AI response
      final sourceType = item['source_type'] as String? ?? 'ai_draft';
      final fitLevel   = item['fit_level']   as String? ?? 'good_alternative';

      results.add(AiSuggestion(
        id:             '',
        tripId:         tripId,
        teamId:         teamId,
        type:           type,
        title:          title,
        description:    description,
        rationale:      item['rationale'] as String?,
        proposedPayload:
            (item['proposed_payload'] as Map<String, dynamic>?) ?? {},
        sourceContext: {
          'source_type': sourceType,
          'fit_level':   fitLevel,
        },
        status:    AiSuggestionStatus.pending,
        createdAt: now,
      ));
    }

    return results;
  }
}
