import '../../data/models/ai_memory_record.dart';
import '../../data/repositories/ai_memory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierPreferenceLearningService
//
// Tracks which suppliers are consistently selected or rejected.
// Upserts AiMemoryRecords with memoryType = supplierPattern.
// ─────────────────────────────────────────────────────────────────────────────

class SupplierPreferenceLearningService {
  final AiMemoryRepository _repo;

  const SupplierPreferenceLearningService(this._repo);

  Future<void> learn({
    required String teamId,
    String? dossierId,
  }) async {
    final events = dossierId != null
        ? await _repo.fetchFeedbackForDossier(dossierId)
        : await _repo.fetchFeedbackByType(teamId, 'supplier');

    final supplierEvents = events.where(
      (e) => e.suggestionType.contains('supplier') ||
             e.suggestionType.contains('hotel') ||
             e.suggestionType.contains('transfer'),
    ).toList();

    if (supplierEvents.isEmpty) return;

    // Tally per supplier name
    final tally = <String, (int approved, int rejected, String? category)>{};

    for (final e in supplierEvents) {
      final payload = e.finalValue ?? e.originalValue;
      final name     = payload?['supplier_name'] as String?;
      final category = payload?['supplier_type'] as String?;
      if (name == null || name.isEmpty) continue;

      final current = tally[name] ?? (0, 0, category);
      if (e.action == FeedbackAction.approved || e.action == FeedbackAction.applied) {
        tally[name] = (current.$1 + 1, current.$2, current.$3);
      } else if (e.action == FeedbackAction.rejected) {
        tally[name] = (current.$1, current.$2 + 1, current.$3);
      }
    }

    for (final entry in tally.entries) {
      final name = entry.key;
      final (approved, rejected, category) = entry.value;
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
        memoryType:   MemoryType.supplierPattern,
        sourceType:   'suggestion_feedback',
        signalKey:    'supplier_preference',
        signalValue:  {
          'supplier_name': name,
          'supplier_type': category,
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
