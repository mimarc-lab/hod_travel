import 'dart:convert';
import '../../ai_suggestions/services/ai_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComponentTitleSuggestionService
//
// Calls the AI provider with component context and returns 3–5 short,
// operationally-clear title suggestions.  Parser is lenient — returns
// whatever valid strings it can extract even if the model adds prose.
// ─────────────────────────────────────────────────────────────────────────────

class ComponentTitleSuggestionService {
  final AiProvider _ai;

  const ComponentTitleSuggestionService(this._ai);

  static const _system = '''
You are an expert luxury travel planner who names trip components for internal run sheets.

Title rules:
- 2–6 words, strongly preferred
- Operationally clear: describe WHAT the component IS, not how great it is
- Elegant but never promotional ("Amazing", "Incredible", "World-class" are banned)
- Use supplier name when it adds clarity (e.g. "Aman Kyoto Stay")
- Avoid brochure language and generic phrases like "Unique Experience"
- Style: [Supplier] [Action] or [Activity] [Context] or [Place] [Event]

Examples by component type:
  Accommodation  → "Aman Kyoto Stay", "Park Hyatt Check-In", "Villa Arrival"
  Transport      → "Airport Arrival Transfer", "Shinkansen to Kyoto", "Private Car to Hotel"
  Dining         → "Dinner at Kikunoi", "Omakase at Sukiyabashi", "Riverside Lunch"
  Experience     → "Private Tea Ceremony", "Nishiki Market Walk", "Temple Tea with Former Monk"
  Guide          → "Cultural Guide – Kyoto", "Local Expert Half Day"
  Special        → "Welcome Amenity Setup", "Yin & Yang Debate", "Surprise Proposal Setup"

Return ONLY a JSON array of 3–5 title strings. No markdown, no explanation.
Example output: ["Aman Kyoto Stay", "Aman Kyoto Check-In", "Kyoto Luxury Retreat"]
''';

  Future<List<String>> suggestTitles({
    required String componentType,
    required String userInput,
    String? supplierName,
    String? destination,
  }) async {
    final parts = <String>[
      'Component type: $componentType',
      if (userInput.isNotEmpty) 'User draft title: "$userInput"',
      if (supplierName != null && supplierName.isNotEmpty)
        'Supplier / Venue: $supplierName',
      if (destination != null && destination.isNotEmpty)
        'Destination / Location: $destination',
    ];

    final userPrompt =
        '${parts.join('\n')}\n\nGenerate 3–5 title suggestions.';

    final raw = await _ai.complete(_system, userPrompt);
    return _parse(raw);
  }

  List<String> _parse(String raw) {
    try {
      final start = raw.indexOf('[');
      final end   = raw.lastIndexOf(']');
      if (start == -1 || end == -1 || end < start) return [];
      final list  = jsonDecode(raw.substring(start, end + 1)) as List<dynamic>;
      return list
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.length <= 80)
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
