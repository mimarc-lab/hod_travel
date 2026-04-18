import '../../../data/models/ai_suggestion_model.dart';

// ── SuggestionRelevanceFilter ─────────────────────────────────────────────────
//
// Removes suggestions that are clearly low-quality or duplicates before
// they reach the ranker or the UI.
//
// Intentionally conservative — only removes obvious failures.
// Subtle quality differences are handled by the ranker, not this filter.

class SuggestionRelevanceFilter {
  const SuggestionRelevanceFilter();

  List<AiSuggestion> filter(List<AiSuggestion> suggestions) {
    final seen  = <String>{};
    final result = <AiSuggestion>[];

    for (final s in suggestions) {
      if (!_passes(s)) continue;

      // Deduplicate by normalised title (case/punctuation insensitive)
      final key = _normalise(s.title);
      if (seen.contains(key)) continue;
      seen.add(key);

      result.add(s);
    }

    return result;
  }

  // ── Pass criteria ──────────────────────────────────────────────────────────

  bool _passes(AiSuggestion s) {
    // Must have a meaningful title and description
    if (s.title.trim().length < 5) return false;
    if (s.description.trim().length < 12) return false;

    // Reject empty rationale on high-stakes types where it matters most
    if (s.type == AiSuggestionType.signatureExperience &&
        (s.rationale == null || s.rationale!.trim().isEmpty)) {
      return false;
    }

    return true;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Strips punctuation + case for deduplication comparison.
  String _normalise(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
}
