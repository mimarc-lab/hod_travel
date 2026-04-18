import 'package:flutter/foundation.dart';
import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/repositories/enrichment_repository.dart';
import '../../../features/suppliers/enrichment/enrichment_history_service.dart';
import '../../../integrations/firecrawl/extraction_mapper.dart';
import '../../../integrations/firecrawl/firecrawl_models.dart';
import '../../../integrations/firecrawl/firecrawl_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Extraction schema selector
// ─────────────────────────────────────────────────────────────────────────────

enum ExtractionSchema {
  /// Hotels, villas, lodges, resorts, safari camps, private homes.
  accommodation,

  /// Private tours, activities, classes, charters, safaris, etc.
  experience,
}

// ─────────────────────────────────────────────────────────────────────────────
// Enrichment state machine
// ─────────────────────────────────────────────────────────────────────────────

enum EnrichmentState { idle, loading, result, error }

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentProvider — UI state only.
//
// Delegates:
//   • HTTP calls       → FirecrawlService
//   • DB persistence   → EnrichmentHistoryService
//   • No merge logic   → SupplierMergeService (used directly in the merge sheet)
//   • No dup detection → DuplicateDetectionService (used in the review screen)
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentProvider extends ChangeNotifier {
  final FirecrawlService _service;
  final EnrichmentHistoryService _history;

  EnrichmentProvider({
    FirecrawlService? service,
    EnrichmentRepository? enrichmentRepository,
    String teamId = '',
  })  : _service = service ?? FirecrawlService(),
        _history = EnrichmentHistoryService(
          repo: enrichmentRepository,
          teamId: teamId,
        );

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // ── URL extraction state ───────────────────────────────────────────────────

  EnrichmentState _extractState = EnrichmentState.idle;
  SupplierEnrichment? _extractResult;
  FirecrawlError? _extractError;

  /// Id of the draft DB record created after a successful extraction.
  /// Finalised when the user acts; discarded if they close without acting.
  String? _pendingRecordId;

  EnrichmentState get extractState  => _extractState;
  SupplierEnrichment? get extractResult => _extractResult;
  FirecrawlError? get extractError  => _extractError;

  // ── Search state ──────────────────────────────────────────────────────────

  EnrichmentState _searchState = EnrichmentState.idle;
  List<FirecrawlSearchResult> _searchResults = [];
  FirecrawlError? _searchError;

  EnrichmentState get searchState => _searchState;
  List<FirecrawlSearchResult> get searchResults =>
      List.unmodifiable(_searchResults);
  FirecrawlError? get searchError => _searchError;

  // ── In-memory event log ───────────────────────────────────────────────────

  final List<EnrichmentEvent> _events = [];
  List<EnrichmentEvent> get history => List.unmodifiable(_events);

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Extract structured data from [url] using [schema].
  Future<void> extractFromUrl(
    String url, {
    ExtractionSchema schema = ExtractionSchema.accommodation,
  }) async {
    _extractState = EnrichmentState.loading;
    _extractResult = null;
    _extractError = null;
    notifyListeners();

    final result = schema == ExtractionSchema.experience
        ? await _service.extractExperienceData(url)
        : await _service.extractSupplierData(url);

    switch (result) {
      case FirecrawlSuccess<FirecrawlExtractResult>(:final data):
        _extractResult = schema == ExtractionSchema.experience
            ? ExtractionMapper.fromExperienceExtract(data)
            : ExtractionMapper.fromExtract(data);
        _extractState = EnrichmentState.result;
        // Persist draft record; store id for later finalisation.
        _history
            .createDraft(sourceUrl: url, extractedPayload: data.fields)
            .then((id) => _pendingRecordId = id);
      case FirecrawlFailure<FirecrawlExtractResult>(:final error):
        _extractError = error;
        _extractState = EnrichmentState.error;
    }
    notifyListeners();
  }

  /// Search for supplier candidates by text query.
  Future<void> searchSuppliers(String query) async {
    _searchState = EnrichmentState.loading;
    _searchResults = [];
    _searchError = null;
    notifyListeners();

    final result = await _service.searchSuppliers(query);

    switch (result) {
      case FirecrawlSuccess<List<FirecrawlSearchResult>>(:final data):
        _searchResults = data;
        _searchState = EnrichmentState.result;
      case FirecrawlFailure<List<FirecrawlSearchResult>>(:final error):
        _searchError = error;
        _searchState = EnrichmentState.error;
    }
    notifyListeners();
  }

  /// Record a completed enrichment action.
  ///
  /// Finalises the pending DB record with the action taken and links it to
  /// the supplier if one was created or enriched. Call before [clearExtract].
  void recordEvent({
    required EnrichmentEventType type,
    required String sourceUrl,
    required String sourceDomain,
    String? supplierName,
    String? supplierId,
  }) {
    _events.insert(
      0,
      EnrichmentEvent(
        id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        sourceUrl: sourceUrl,
        sourceDomain: sourceDomain,
        supplierName: supplierName,
        supplierId: supplierId,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();

    final recordId = _pendingRecordId;
    _pendingRecordId = null;
    if (recordId != null) {
      _history.finalise(
        recordId: recordId,
        eventType: type,
        supplierId: supplierId,
      );
    }
  }

  /// Reset the extract flow to idle.
  ///
  /// If a pending draft record exists (user closed without acting), it is
  /// automatically marked as discarded.
  void clearExtract() {
    final recordId = _pendingRecordId;
    _pendingRecordId = null;
    if (recordId != null) _history.discard(recordId);

    _extractState = EnrichmentState.idle;
    _extractResult = null;
    _extractError = null;
    notifyListeners();
  }

  /// Reset the search flow to idle.
  void clearSearch() {
    _searchState = EnrichmentState.idle;
    _searchResults = [];
    _searchError = null;
    notifyListeners();
  }
}
