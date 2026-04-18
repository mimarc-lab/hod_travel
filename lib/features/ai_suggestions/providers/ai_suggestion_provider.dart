import 'package:flutter/foundation.dart';
import '../../../data/models/ai_memory_record.dart';
import '../../../data/models/ai_suggestion_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/signature_experience.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/ai_suggestion_repository.dart';
import '../services/ai_context_builder.dart';
import '../services/ai_provider.dart';
import '../services/ai_suggestion_service.dart';
import '../services/suggestion_apply_service.dart';
import '../../ai_memory/suggestion_feedback_tracker.dart';

class AiSuggestionProvider extends ChangeNotifier {
  // ── Static in-memory cache ─────────────────────────────────────────────────
  // Survives provider disposal (e.g. when the user navigates away and back).
  // Keyed by trip ID. Cleared only when the app restarts.
  static final Map<String, List<AiSuggestion>> _cache = {};

  final AiSuggestionRepository? _repo;
  final AiSuggestionService? _service;
  final SuggestionApplyService _applyService;
  final SuggestionFeedbackTracker? _feedbackTracker;

  final String _tripId;
  final String _teamId;

  // Optional dossier context for memory tracking
  String? dossierId;

  List<AiSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;

  AiSuggestionProvider({
    AiSuggestionRepository? repository,
    AiProvider? aiProvider,
    required String tripId,
    required String teamId,
    SuggestionFeedbackTracker? feedbackTracker,
    this.dossierId,
  })  : _repo = repository,
        _service = aiProvider != null
            ? AiSuggestionService(provider: aiProvider)
            : null,
        _applyService = const SuggestionApplyService(),
        _feedbackTracker = feedbackTracker,
        _tripId = tripId,
        _teamId = teamId {
    // Seed from cache immediately so the UI shows prior results instantly.
    if (_cache.containsKey(tripId)) {
      _suggestions = List.of(_cache[tripId]!);
    }
    _loadForTrip();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<AiSuggestion> get suggestions => List.unmodifiable(_suggestions);
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;

  List<AiSuggestion> get pendingSuggestions =>
      _suggestions.where((s) => s.status == AiSuggestionStatus.pending).toList();

  List<AiSuggestion> get approvedSuggestions =>
      _suggestions.where((s) => s.status == AiSuggestionStatus.approved).toList();

  int get pendingCount => pendingSuggestions.length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadForTrip() async {
    if (_repo == null || _tripId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final loaded = await _repo.fetchForTrip(_tripId);
      // Merge DB results with any locally-generated suggestions that haven't
      // been saved yet (id is empty means DB save failed).
      final unsaved = _suggestions.where((s) => s.id.isEmpty).toList();
      _suggestions = [
        ...unsaved,
        ...loaded.where((s) => !unsaved.any((u) => u.title == s.title)),
      ];
      _cache[_tripId] = List.of(_suggestions);
    } catch (e, st) {
      // Silently degrade — show cached/local suggestions instead of an error.
      // The ai_suggestions table may not exist yet; this is non-fatal.
      debugPrint('[AiSuggestionProvider._loadForTrip] ERROR: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => _loadForTrip();

  // ── Generate ───────────────────────────────────────────────────────────────

  /// Runs a specific generation mode, saves all results, notifies listeners.
  Future<void> generate({
    required AiSuggestionType type,
    required Trip trip,
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDay,
    required List<Task> tasks,
    required List<Supplier> suppliers,
    required List<SignatureExperience> signatureExperiences,
  }) async {
    if (_service == null) {
      _error =
          'AI is not configured. Please add your Anthropic API key in Settings → AI.';
      notifyListeners();
      return;
    }
    if (_tripId.isEmpty || _teamId.isEmpty) return;

    _isGenerating = true;
    _error = null;
    notifyListeners();

    final ctx = TripContext(
      trip: trip,
      days: days,
      itemsByDay: itemsByDay,
      tasks: tasks,
      suppliers: suppliers,
      signatureExperiences: signatureExperiences,
    );

    try {
      final fresh = await _callService(type, ctx);
      final saved = await _saveAll(fresh);
      _suggestions = [...saved, ..._suggestions];
      _cache[_tripId] = List.of(_suggestions);  // persist across navigation
      notifyListeners();
    } on AiProviderException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AiSuggestionProvider.generate] ERROR: $e\n$st');
      _error = 'Generation failed. Please try again.';
      notifyListeners();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<List<AiSuggestion>> _callService(
      AiSuggestionType type, TripContext ctx) async {
    return switch (type) {
      AiSuggestionType.draftItinerary =>
        _service!.draftItinerary(ctx, _tripId, _teamId),
      AiSuggestionType.missingGap =>
        _service!.findMissingGaps(ctx, _tripId, _teamId),
      AiSuggestionType.supplierRecommendation =>
        _service!.recommendSuppliers(ctx, _tripId, _teamId),
      AiSuggestionType.signatureExperience =>
        _service!.recommendSignatureExperiences(ctx, _tripId, _teamId),
      AiSuggestionType.taskSuggestion =>
        _service!.suggestTasks(ctx, _tripId, _teamId),
      AiSuggestionType.flowImprovement =>
        _service!.suggestFlowImprovements(ctx, _tripId, _teamId),
    };
  }

  Future<List<AiSuggestion>> _saveAll(List<AiSuggestion> items) async {
    if (_repo == null) return items;
    final saved = <AiSuggestion>[];
    for (final item in items) {
      try {
        saved.add(await _repo.create(item));
      } catch (e, st) {
        debugPrint('[AiSuggestionProvider._saveAll] ERROR saving item: $e\n$st');
        // Still surface the suggestion locally even if DB save fails
        saved.add(item);
      }
    }
    return saved;
  }

  // ── Approve / Dismiss ──────────────────────────────────────────────────────

  Future<void> approve(String id) async {
    await _updateStatus(id, AiSuggestionStatus.approved);
    _trackFeedback(id, FeedbackAction.approved);
  }

  Future<void> dismiss(String id) async {
    await _updateStatus(id, AiSuggestionStatus.dismissed);
    _trackFeedback(id, FeedbackAction.dismissed);
  }

  Future<void> markApplied(String id) async {
    await _updateStatus(id, AiSuggestionStatus.applied);
    _trackFeedback(id, FeedbackAction.applied);
  }

  Future<void> _updateStatus(String id, AiSuggestionStatus status) async {
    final idx = _suggestions.indexWhere((s) => s.id == id);
    if (idx == -1) return;

    // Optimistic update
    _suggestions[idx] = _suggestions[idx].copyWith(
      status: status,
      reviewedAt: DateTime.now(),
    );
    _cache[_tripId] = List.of(_suggestions);
    notifyListeners();

    if (_repo == null) return;
    try {
      final updated = await _repo.updateStatus(id, status,
          reviewedAt: DateTime.now());
      _suggestions[idx] = updated;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AiSuggestionProvider._updateStatus] ERROR: $e\n$st');
    }
  }

  // ── Edit payload ───────────────────────────────────────────────────────────

  Future<void> updatePayload(
      String id, Map<String, dynamic> proposedPayload) async {
    final idx = _suggestions.indexWhere((s) => s.id == id);
    if (idx == -1) return;

    final original = _suggestions[idx].proposedPayload;

    _suggestions[idx] =
        _suggestions[idx].copyWith(proposedPayload: proposedPayload);
    notifyListeners();

    _trackFeedback(id, FeedbackAction.edited,
        originalValue: original, finalValue: proposedPayload);

    if (_repo == null || _suggestions[idx].id.isEmpty) return;
    try {
      final updated = await _repo.updatePayload(id, proposedPayload);
      _suggestions[idx] = updated;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AiSuggestionProvider.updatePayload] ERROR: $e\n$st');
    }
  }

  // ── Apply ──────────────────────────────────────────────────────────────────

  /// Returns what the UI should do. Never writes data directly.
  SuggestionApplyResult apply(String id) {
    final suggestion = _suggestions.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Suggestion $id not found'),
    );
    return _applyService.apply(suggestion);
  }

  // ── Feedback tracking (fire-and-forget) ───────────────────────────────────

  void _trackFeedback(
    String suggestionId,
    FeedbackAction action, {
    Map<String, dynamic>? originalValue,
    Map<String, dynamic>? finalValue,
  }) {
    if (_feedbackTracker == null) return;
    final idx = _suggestions.indexWhere((s) => s.id == suggestionId);
    if (idx == -1) return;
    final suggestion = _suggestions[idx];
    _feedbackTracker.track(
      suggestionType: suggestion.type.name,
      action:         action,
      dossierId:      dossierId,
      tripId:         _tripId,
      suggestionId:   suggestionId,
      originalValue:  originalValue ?? suggestion.proposedPayload,
      finalValue:     finalValue,
    ).catchError((e) {
      debugPrint('[AiSuggestionProvider._trackFeedback] ERROR: $e');
    });
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteDismissed() async {
    final toDelete =
        _suggestions.where((s) => s.status == AiSuggestionStatus.dismissed).toList();
    _suggestions.removeWhere((s) => s.status == AiSuggestionStatus.dismissed);
    _cache[_tripId] = List.of(_suggestions);
    notifyListeners();

    if (_repo == null) return;
    for (final s in toDelete) {
      if (s.id.isNotEmpty) {
        try {
          await _repo.delete(s.id);
        } catch (e, st) {
          debugPrint('[AiSuggestionProvider.deleteDismissed] ERROR: $e\n$st');
        }
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
