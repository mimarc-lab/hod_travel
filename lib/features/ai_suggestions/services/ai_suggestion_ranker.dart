import '../../../data/models/ai_suggestion_model.dart';

// ── AiSuggestionRanker ────────────────────────────────────────────────────────
//
// Ranks a batch of AI suggestions by quality signals so the strongest
// suggestions surface at the top of the review list.
//
// Scoring axes:
//   source_type — DreamMaker Signature > gap_fill > operational > supplier > ai_draft
//   fit_level   — best_fit > strong_match > good_alternative
//   type bonus  — signatureExperience and missingGap get small boosts
//
// Score is purely ordinal — it determines sort order, not a displayed value.

class AiSuggestionRanker {
  const AiSuggestionRanker();

  List<AiSuggestion> rank(List<AiSuggestion> suggestions) {
    if (suggestions.length <= 1) return suggestions;
    final scored = suggestions.map((s) => (s, _score(s))).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  int _score(AiSuggestion s) {
    var score = 0;

    // Source type — DreamMaker Signature is highest priority
    score += switch (s.sourceContext['source_type'] as String? ?? 'ai_draft') {
      'dreammaker_signature' => 30,
      'gap_fill'             => 20,
      'operational'          => 15,
      'supplier'             => 10,
      _                      => 0, // ai_draft: baseline
    };

    // Fit level declared by the AI
    score += switch (s.sourceContext['fit_level'] as String? ?? 'good_alternative') {
      'best_fit'     => 20,
      'strong_match' => 10,
      _              => 0,
    };

    // Suggestion type bonus
    score += switch (s.type) {
      AiSuggestionType.signatureExperience => 10,
      AiSuggestionType.missingGap          => 5,
      _                                    => 0,
    };

    return score;
  }
}
