import '../../data/models/ai_memory_record.dart';
import '../../data/repositories/ai_memory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PreferenceInferenceEngine
//
// Rule-based (not ML) engine that reads feedback events for a dossier and
// upserts InferredPreferenceSignals.  Runs after each feedback event is saved.
//
// Rules:
//  - Count approvals vs rejections per suggestion type & payload key
//  - Emit a signal if a preference is consistently approved (≥60% approval
//    rate with at least 2 data points), or consistently rejected (≥60%)
//  - Confidence: emerging (1–2 pts), moderate (3–5), strong (6+)
// ─────────────────────────────────────────────────────────────────────────────

class PreferenceInferenceEngine {
  final AiMemoryRepository _repo;

  const PreferenceInferenceEngine(AiMemoryRepository repo) : _repo = repo;

  Future<void> runForDossier({
    required String dossierId,
    required String teamId,
  }) async {
    final events = await _repo.fetchFeedbackForDossier(dossierId);
    if (events.isEmpty) return;

    final signals = _infer(teamId, dossierId, events);
    for (final signal in signals) {
      await _repo.upsertSignal(signal);
    }
  }

  // ── Inference logic ────────────────────────────────────────────────────────

  List<InferredPreferenceSignal> _infer(
    String teamId,
    String dossierId,
    List<SuggestionFeedbackEvent> events,
  ) {
    final results = <InferredPreferenceSignal>[];

    // Pacing preference
    final pacingSignal = _inferFromKey(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'pacing_preference',
      extractFn: (e) => _extractValueKey(e, 'pacing'),
    );
    if (pacingSignal != null) results.add(pacingSignal);

    // Late starts
    final lateStartSignal = _inferBooleanPreference(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'prefers_late_starts',
      extractFn: (e) => _extractValueKey(e, 'start_time'),
      trueValues: const {'late', 'after_10am', 'flexible_late'},
    );
    if (lateStartSignal != null) results.add(lateStartSignal);

    // Accommodation preference
    final accomSignal = _inferFromKey(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'accommodation_preference',
      extractFn: (e) => _extractValueKey(e, 'accommodation_type'),
    );
    if (accomSignal != null) results.add(accomSignal);

    // Experience interests
    for (final interest in [
      'cultural_interest',
      'adventure_interest',
      'relaxation_interest',
      'intellectual_interest',
      'shopping_interest',
    ]) {
      final key = interest.replaceAll('_interest', '');
      final signal = _inferBooleanPreference(
        teamId:    teamId,
        dossierId: dossierId,
        events:    events,
        signalKey: interest,
        extractFn: (e) => _extractValueKey(e, key),
        trueValues: const {'high', 'yes', 'true', '1'},
      );
      if (signal != null) results.add(signal);
    }

    // Crowd sensitivity
    final crowdSignal = _inferBooleanPreference(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'dislikes_crowds',
      extractFn: (e) => _extractValueKey(e, 'crowd_sensitivity'),
      trueValues: const {'avoids', 'sensitive', 'true', 'high'},
    );
    if (crowdSignal != null) results.add(crowdSignal);

    // Privacy preference
    final privacySignal = _inferFromKey(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'prefers_private',
      extractFn: (e) => _extractValueKey(e, 'privacy_preference'),
    );
    if (privacySignal != null) results.add(privacySignal);

    // Dining style
    final diningSignal = _inferFromKey(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'preferred_dining_style',
      extractFn: (e) => _extractValueKey(e, 'dining_style'),
    );
    if (diningSignal != null) results.add(diningSignal);

    // Luxury level
    final luxurySignal = _inferFromKey(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'luxury_level',
      extractFn: (e) => _extractValueKey(e, 'luxury_level'),
    );
    if (luxurySignal != null) results.add(luxurySignal);

    // Wellness importance
    final wellnessSignal = _inferBooleanPreference(
      teamId:    teamId,
      dossierId: dossierId,
      events:    events,
      signalKey: 'wellness_importance',
      extractFn: (e) => _extractValueKey(e, 'wellness'),
      trueValues: const {'high', 'important', 'true', 'yes'},
    );
    if (wellnessSignal != null) results.add(wellnessSignal);

    return results;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  InferredPreferenceSignal? _inferFromKey({
    required String teamId,
    required String dossierId,
    required List<SuggestionFeedbackEvent> events,
    required String signalKey,
    required String? Function(SuggestionFeedbackEvent) extractFn,
  }) {
    final tally = <String, _Tally>{};

    for (final e in events) {
      final value = extractFn(e);
      if (value == null || value.isEmpty) continue;
      tally.putIfAbsent(value, () => _Tally()).record(e.action);
    }

    if (tally.isEmpty) return null;

    // Find the value with the highest approval rate (min 2 data points, ≥60%)
    String? bestValue;
    double bestRate = 0;
    int bestCount = 0;

    for (final entry in tally.entries) {
      final t = entry.value;
      if (t.total < 2) continue;
      final rate = t.approvals / t.total;
      if (rate >= 0.6 && rate > bestRate) {
        bestRate = rate;
        bestValue = entry.key;
        bestCount = t.total;
      }
    }

    if (bestValue == null) return null;

    return InferredPreferenceSignal(
      id:             DateTime.now().microsecondsSinceEpoch.toString(),
      teamId:         teamId,
      dossierId:      dossierId,
      signalKey:      signalKey,
      signalValue:    bestValue,
      confidence:     SignalConfidence.fromCount(bestCount),
      evidenceCount:  bestCount,
      evidenceSummary: 'Inferred from $bestCount feedback events '
          '(${(bestRate * 100).round()}% approval rate)',
      createdAt:      DateTime.now(),
      updatedAt:      DateTime.now(),
    );
  }

  InferredPreferenceSignal? _inferBooleanPreference({
    required String teamId,
    required String dossierId,
    required List<SuggestionFeedbackEvent> events,
    required String signalKey,
    required String? Function(SuggestionFeedbackEvent) extractFn,
    required Set<String> trueValues,
  }) {
    int trueApprovals = 0;
    int total = 0;

    for (final e in events) {
      final value = extractFn(e)?.toLowerCase();
      if (value == null) continue;
      final isTrue = trueValues.contains(value);
      if (!isTrue) continue;
      total++;
      if (e.action == FeedbackAction.approved || e.action == FeedbackAction.applied) {
        trueApprovals++;
      }
    }

    if (total < 2) return null;

    final approvalRate = trueApprovals / total;
    if (approvalRate < 0.6) return null;

    return InferredPreferenceSignal(
      id:             DateTime.now().microsecondsSinceEpoch.toString(),
      teamId:         teamId,
      dossierId:      dossierId,
      signalKey:      signalKey,
      signalValue:    'true',
      confidence:     SignalConfidence.fromCount(total),
      evidenceCount:  total,
      evidenceSummary: 'Inferred from $total approved suggestions '
          '(${(approvalRate * 100).round()}% rate)',
      createdAt:      DateTime.now(),
      updatedAt:      DateTime.now(),
    );
  }

  String? _extractValueKey(SuggestionFeedbackEvent e, String key) {
    final payload = e.finalValue ?? e.originalValue;
    final v = payload?[key];
    return v?.toString();
  }
}

class _Tally {
  int approvals = 0;
  int total = 0;

  void record(FeedbackAction action) {
    total++;
    if (action == FeedbackAction.approved || action == FeedbackAction.applied) {
      approvals++;
    }
  }
}
