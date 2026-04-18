import '../../data/models/ai_memory_record.dart';
import '../../data/repositories/ai_memory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SignatureExperienceLearningService
//
// Tracks which experience types are consistently approved or rejected for
// a dossier. Upserts AiMemoryRecords with memoryType = experiencePattern.
// ─────────────────────────────────────────────────────────────────────────────

class SignatureExperienceLearningService {
  final AiMemoryRepository _repo;

  const SignatureExperienceLearningService(this._repo);

  Future<void> learn({
    required String teamId,
    required String dossierId,
  }) async {
    final events = await _repo.fetchFeedbackForDossier(dossierId);
    final experienceEvents = events.where(
      (e) => e.suggestionType.contains('experience') ||
             e.suggestionType.contains('activity'),
    ).toList();

    if (experienceEvents.isEmpty) return;

    // Tally approval/rejection per experience category
    final tally = <String, (int approved, int rejected)>{};

    for (final e in experienceEvents) {
      final category = (e.finalValue ?? e.originalValue)?['category'] as String?;
      if (category == null || category.isEmpty) continue;

      final current = tally[category] ?? (0, 0);
      if (e.action == FeedbackAction.approved || e.action == FeedbackAction.applied) {
        tally[category] = (current.$1 + 1, current.$2);
      } else if (e.action == FeedbackAction.rejected) {
        tally[category] = (current.$1, current.$2 + 1);
      }
    }

    for (final entry in tally.entries) {
      final category = entry.key;
      final (approved, rejected) = entry.value;
      final total = approved + rejected;
      if (total < 2) continue;

      final approvalRate = approved / total;
      final isPreferred = approvalRate >= 0.65;
      final isAvoided   = approvalRate <= 0.3;

      if (!isPreferred && !isAvoided) continue;

      final record = AiMemoryRecord(
        id:           DateTime.now().microsecondsSinceEpoch.toString(),
        teamId:       teamId,
        dossierId:    dossierId,
        memoryType:   MemoryType.experiencePattern,
        sourceType:   'suggestion_feedback',
        signalKey:    'experience_category',
        signalValue:  {
          'category':      category,
          'preference':    isPreferred ? 'preferred' : 'avoided',
          'approval_rate': approvalRate.toStringAsFixed(2),
          'total_signals': total,
        },
        confidence:     approvalRate >= 0.8 || approvalRate <= 0.2 ? 0.9 : 0.7,
        evidenceCount:  total,
        createdAt:      DateTime.now(),
        updatedAt:      DateTime.now(),
      );

      await _repo.upsertMemoryRecord(record);
    }
  }
}
