import '../../data/models/ai_memory_record.dart';
import '../../data/repositories/ai_memory_repository.dart';
import 'preference_inference_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SuggestionFeedbackTracker
//
// Called by AiSuggestionProvider whenever a suggestion is acted on.
// Records the feedback event and triggers inference if a dossierId is known.
// ─────────────────────────────────────────────────────────────────────────────

class SuggestionFeedbackTracker {
  final AiMemoryRepository _repo;
  final PreferenceInferenceEngine _inferenceEngine;
  final String teamId;

  const SuggestionFeedbackTracker({
    required AiMemoryRepository repo,
    required PreferenceInferenceEngine inferenceEngine,
    required this.teamId,
  }) : _repo = repo,
       _inferenceEngine = inferenceEngine;

  Future<void> track({
    required String suggestionType,
    required FeedbackAction action,
    String? dossierId,
    String? tripId,
    String? suggestionId,
    Map<String, dynamic>? originalValue,
    Map<String, dynamic>? finalValue,
    String? editSummary,
  }) async {
    final event = SuggestionFeedbackEvent(
      id:             DateTime.now().microsecondsSinceEpoch.toString(),
      teamId:         teamId,
      dossierId:      dossierId,
      tripId:         tripId,
      suggestionId:   suggestionId,
      suggestionType: suggestionType,
      action:         action,
      originalValue:  originalValue,
      finalValue:     finalValue,
      editSummary:    editSummary,
      createdAt:      DateTime.now(),
    );

    await _repo.recordFeedback(event);

    // Trigger inference update for this dossier when we have context
    if (dossierId != null) {
      await _inferenceEngine.runForDossier(
        dossierId: dossierId,
        teamId:    teamId,
      );
    }
  }
}
