import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart';

// =============================================================================
// SupplierEnrichmentRecord — DB model for public.supplier_enrichments rows.
// Separate from the Firecrawl-side SupplierEnrichment model in
// supplier_enrichment_model.dart (which is the extraction payload).
// This model represents what is stored/read from the database.
// =============================================================================

enum EnrichmentSourceType { firecrawlUrl, firecrawlSearch, manualImport }

extension EnrichmentSourceTypeX on EnrichmentSourceType {
  String get dbValue => switch (this) {
        EnrichmentSourceType.firecrawlUrl    => 'firecrawl_url',
        EnrichmentSourceType.firecrawlSearch => 'firecrawl_search',
        EnrichmentSourceType.manualImport    => 'manual_import',
      };

  String get label => switch (this) {
        EnrichmentSourceType.firecrawlUrl    => 'Firecrawl URL',
        EnrichmentSourceType.firecrawlSearch => 'Firecrawl Search',
        EnrichmentSourceType.manualImport    => 'Manual Import',
      };
}

EnrichmentSourceType enrichmentSourceTypeFromDb(String s) => switch (s) {
      'firecrawl_search' => EnrichmentSourceType.firecrawlSearch,
      'manual_import'    => EnrichmentSourceType.manualImport,
      _                  => EnrichmentSourceType.firecrawlUrl,
    };

enum EnrichmentActionTaken { created, merged, discarded, draftOnly }

extension EnrichmentActionTakenX on EnrichmentActionTaken {
  String get dbValue => switch (this) {
        EnrichmentActionTaken.created   => 'created',
        EnrichmentActionTaken.merged    => 'merged',
        EnrichmentActionTaken.discarded => 'discarded',
        EnrichmentActionTaken.draftOnly => 'draft_only',
      };

  String get label => switch (this) {
        EnrichmentActionTaken.created   => 'Created supplier',
        EnrichmentActionTaken.merged    => 'Merged into existing',
        EnrichmentActionTaken.discarded => 'Discarded',
        EnrichmentActionTaken.draftOnly => 'Draft only',
      };
}

EnrichmentActionTaken? enrichmentActionFromDb(String? s) => switch (s) {
      'created'    => EnrichmentActionTaken.created,
      'merged'     => EnrichmentActionTaken.merged,
      'discarded'  => EnrichmentActionTaken.discarded,
      'draft_only' => EnrichmentActionTaken.draftOnly,
      _            => null,
    };

// -----------------------------------------------------------------------------

class SupplierEnrichmentRecord {
  final String id;
  final String? supplierId;
  final String teamId;
  final EnrichmentSourceType sourceType;
  final String? sourceUrl;
  final String? sourceDomain;
  final Map<String, dynamic>? rawPayload;
  final Map<String, dynamic>? extractedPayload;
  final EnrichmentActionTaken? actionTaken;
  final String? createdBy;
  final DateTime createdAt;

  const SupplierEnrichmentRecord({
    required this.id,
    this.supplierId,
    required this.teamId,
    required this.sourceType,
    this.sourceUrl,
    this.sourceDomain,
    this.rawPayload,
    this.extractedPayload,
    this.actionTaken,
    this.createdBy,
    required this.createdAt,
  });

  factory SupplierEnrichmentRecord.fromMap(Map<String, dynamic> m) =>
      SupplierEnrichmentRecord(
        id:               m['id'] as String,
        supplierId:       m['supplier_id'] as String?,
        teamId:           m['team_id'] as String,
        sourceType:       enrichmentSourceTypeFromDb(m['source_type'] as String? ?? 'firecrawl_url'),
        sourceUrl:        m['source_url'] as String?,
        sourceDomain:     m['source_domain'] as String?,
        rawPayload:       m['raw_payload'] as Map<String, dynamic>?,
        extractedPayload: m['extracted_payload'] as Map<String, dynamic>?,
        actionTaken:      enrichmentActionFromDb(m['action_taken'] as String?),
        createdBy:        m['created_by'] as String?,
        createdAt:        DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'supplier_id':        supplierId,
        'team_id':            teamId,
        'source_type':        sourceType.dbValue,
        'source_url':         sourceUrl,
        'source_domain':      sourceDomain,
        'raw_payload':        rawPayload,
        'extracted_payload':  extractedPayload,
        'action_taken':       actionTaken?.dbValue,
        'created_by':         createdBy,
      };
}

// =============================================================================
// Abstract interface
// =============================================================================

abstract class EnrichmentRepository {
  Future<List<SupplierEnrichmentRecord>> fetchForTeam(String teamId);
  Future<List<SupplierEnrichmentRecord>> fetchForSupplier(String supplierId);
  Future<SupplierEnrichmentRecord> create(SupplierEnrichmentRecord record);
  Future<SupplierEnrichmentRecord> updateAction(
      String id, EnrichmentActionTaken action);
  Future<void> linkToSupplier(String enrichmentId, String supplierId);
}

// =============================================================================
// Supabase implementation
// =============================================================================

class SupabaseEnrichmentRepository implements EnrichmentRepository {
  final SupabaseClient _client;
  SupabaseEnrichmentRepository(this._client);

  @override
  Future<List<SupplierEnrichmentRecord>> fetchForTeam(String teamId) =>
      guardDb(() async {
        final rows = await _client
            .from('supplier_enrichments')
            .select()
            .eq('team_id', teamId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => SupplierEnrichmentRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<SupplierEnrichmentRecord>> fetchForSupplier(
      String supplierId) =>
      guardDb(() async {
        final rows = await _client
            .from('supplier_enrichments')
            .select()
            .eq('supplier_id', supplierId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => SupplierEnrichmentRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<SupplierEnrichmentRecord> create(
          SupplierEnrichmentRecord record) =>
      guardDb(() async {
        final row = await _client
            .from('supplier_enrichments')
            .insert(record.toMap())
            .select()
            .single();
        return SupplierEnrichmentRecord.fromMap(row);
      });

  @override
  Future<SupplierEnrichmentRecord> updateAction(
          String id, EnrichmentActionTaken action) =>
      guardDb(() async {
        final row = await _client
            .from('supplier_enrichments')
            .update({'action_taken': action.dbValue})
            .eq('id', id)
            .select()
            .single();
        return SupplierEnrichmentRecord.fromMap(row);
      });

  @override
  Future<void> linkToSupplier(
          String enrichmentId, String supplierId) =>
      guardDb(() async {
        await _client
            .from('supplier_enrichments')
            .update({'supplier_id': supplierId})
            .eq('id', enrichmentId);
      });
}
