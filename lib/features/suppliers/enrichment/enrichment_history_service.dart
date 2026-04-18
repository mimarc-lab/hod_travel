import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/repositories/enrichment_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentHistoryService — centralises creation, finalisation, and retrieval
// of SupplierEnrichmentRecords in the database.
//
// Previously this logic was scattered across EnrichmentProvider. Moving it here
// makes the provider thinner and keeps persistence rules in one place.
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentHistoryService {
  final EnrichmentRepository? _repo;
  final String _teamId;

  const EnrichmentHistoryService({
    required EnrichmentRepository? repo,
    required String teamId,
  })  : _repo = repo,
        _teamId = teamId;

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Creates a draft enrichment record immediately after a successful
  /// extraction. Returns the new record's id (used later to finalise).
  Future<String?> createDraft({
    required String sourceUrl,
    required Map<String, dynamic> extractedPayload,
    EnrichmentSourceType sourceType = EnrichmentSourceType.firecrawlUrl,
  }) async {
    final repo = _repo;
    if (repo == null || _teamId.isEmpty) return null;
    try {
      final record = SupplierEnrichmentRecord(
        id: '',
        teamId: _teamId,
        sourceType: sourceType,
        sourceUrl: sourceUrl,
        sourceDomain: _domainFrom(sourceUrl),
        extractedPayload: extractedPayload,
        createdAt: DateTime.now(),
      );
      final created = await repo.create(record);
      return created.id;
    } catch (_) {
      return null;
    }
  }

  /// Finalises a draft record once the user takes an action.
  /// Maps [EnrichmentEventType] → [EnrichmentActionTaken] and optionally
  /// links the record to the resulting supplier.
  Future<void> finalise({
    required String recordId,
    required EnrichmentEventType eventType,
    String? supplierId,
  }) async {
    final repo = _repo;
    if (repo == null || _teamId.isEmpty) return;
    final action = _actionFor(eventType);
    try {
      await repo.updateAction(recordId, action);
      if (supplierId != null) {
        await repo.linkToSupplier(recordId, supplierId);
      }
    } catch (_) {}
  }

  /// Marks a draft record as discarded (user closed without acting).
  Future<void> discard(String recordId) async {
    final repo = _repo;
    if (repo == null || _teamId.isEmpty) return;
    try {
      await repo.updateAction(recordId, EnrichmentActionTaken.discarded);
    } catch (_) {}
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns enrichment history for a specific supplier, newest first.
  Future<List<SupplierEnrichmentRecord>> historyForSupplier(
      String supplierId) async {
    final repo = _repo;
    if (repo == null || _teamId.isEmpty) return [];
    try {
      return await repo.fetchForSupplier(supplierId);
    } catch (_) {
      return [];
    }
  }

  /// Returns all enrichment records for the team, newest first.
  Future<List<SupplierEnrichmentRecord>> historyForTeam() async {
    final repo = _repo;
    if (repo == null || _teamId.isEmpty) return [];
    try {
      return await repo.fetchForTeam(_teamId);
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static EnrichmentActionTaken _actionFor(EnrichmentEventType type) =>
      switch (type) {
        EnrichmentEventType.importedFromUrl  => EnrichmentActionTaken.created,
        EnrichmentEventType.enrichedExisting => EnrichmentActionTaken.merged,
        EnrichmentEventType.discarded        => EnrichmentActionTaken.discarded,
        EnrichmentEventType.searchDiscovery  => EnrichmentActionTaken.draftOnly,
      };

  static String _domainFrom(String url) {
    try {
      return Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return '';
    }
  }
}
