import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_document.dart';
import '../../core/errors/app_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TripDocumentRepository {
  Future<List<TripDocument>> fetchForTrip(String tripId);
  Future<List<TripDocument>> fetchForComponent(String componentId);
  Future<List<TripDocument>> fetchForCostItem(String costItemId);
  Future<List<TripDocument>> fetchForRunSheetItem(String runSheetItemId);

  Future<TripDocument> create(TripDocument doc, String teamId);
  Future<TripDocument> update(TripDocument doc);

  /// Soft-delete: sets status to archived.
  Future<TripDocument> archive(String id);

  /// Hard-delete — prefer archive.
  Future<void> delete(String id);

  /// Upload bytes to Supabase Storage bucket 'trip-documents'.
  /// Returns the storage path to store on the document record.
  Future<String> uploadToStorage({
    required String teamId,
    required String tripId,
    required String docId,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  });

  /// Returns a public (or signed) URL for the given storage path.
  String getPublicUrl(String storagePath);
}

// ─────────────────────────────────────────────────────────────────────────────
// Row mappers
// ─────────────────────────────────────────────────────────────────────────────

TripDocument _fromRow(Map<String, dynamic> r) => TripDocument(
      id:              r['id']               as String,
      teamId:          r['team_id']           as String,
      tripId:          r['trip_id']           as String,
      componentId:     r['component_id']      as String?,
      costItemId:      r['cost_item_id']      as String?,
      runSheetItemId:  r['run_sheet_item_id'] as String?,
      supplierId:      r['supplier_id']       as String?,
      itineraryItemId: r['itinerary_item_id'] as String?,
      documentType:    DocumentType.fromDb(r['document_type'] as String? ?? 'other'),
      title:           r['title']             as String,
      fileUrl:         r['file_url']          as String,
      fileName:        r['file_name']         as String?,
      fileSize:        r['file_size']         as int?,
      mimeType:        r['mime_type']         as String?,
      storagePath:     r['storage_path']      as String?,
      status:          DocumentStatus.fromDb(r['status'] as String? ?? 'uploaded'),
      isClientVisible: r['is_client_visible'] as bool? ?? false,
      issueDate:  r['issue_date']  != null ? DateTime.parse(r['issue_date']  as String) : null,
      expiryDate: r['expiry_date'] != null ? DateTime.parse(r['expiry_date'] as String) : null,
      uploadedAt: DateTime.parse(r['uploaded_at'] as String),
      reviewedAt: r['reviewed_at'] != null ? DateTime.parse(r['reviewed_at'] as String) : null,
      approvedAt: r['approved_at'] != null ? DateTime.parse(r['approved_at'] as String) : null,
      uploadedBy:  r['uploaded_by']  as String? ?? '',
      reviewedBy:  r['reviewed_by']  as String?,
      approvedBy:  r['approved_by']  as String?,
      notesInternal: r['notes_internal'] as String?,
      notesClient:   r['notes_client']   as String?,
    );

Map<String, dynamic> _toRow(TripDocument d, {String? teamId}) => {
      'team_id': teamId,
      'trip_id':           d.tripId,
      'component_id':      d.componentId,
      'cost_item_id':      d.costItemId,
      'run_sheet_item_id': d.runSheetItemId,
      'supplier_id':       d.supplierId,
      'itinerary_item_id': d.itineraryItemId,
      'document_type':     d.documentType.dbValue,
      'title':             d.title,
      'file_url':          d.fileUrl,
      'file_name':         d.fileName,
      'file_size':         d.fileSize,
      'mime_type':         d.mimeType,
      'storage_path':      d.storagePath,
      'status':            d.status.dbValue,
      'is_client_visible': d.isClientVisible,
      'issue_date':  d.issueDate?.toIso8601String().substring(0, 10),
      'expiry_date': d.expiryDate?.toIso8601String().substring(0, 10),
      'reviewed_at': d.reviewedAt?.toIso8601String(),
      'approved_at': d.approvedAt?.toIso8601String(),
      'reviewed_by': d.reviewedBy,
      'approved_by': d.approvedBy,
      'notes_internal': d.notesInternal,
      'notes_client':   d.notesClient,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseTripDocumentRepository implements TripDocumentRepository {
  final SupabaseClient _client;
  SupabaseTripDocumentRepository(this._client);

  static const _kTable   = 'trip_documents';
  static const _kBucket  = 'trip-documents';

  @override
  Future<List<TripDocument>> fetchForTrip(String tripId) => guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select()
            .eq('trip_id', tripId)
            .neq('status', DocumentStatus.archived.dbValue)
            .order('uploaded_at', ascending: false);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<TripDocument>> fetchForComponent(String componentId) =>
      guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select()
            .eq('component_id', componentId)
            .neq('status', DocumentStatus.archived.dbValue)
            .order('uploaded_at', ascending: false);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<TripDocument>> fetchForCostItem(String costItemId) =>
      guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select()
            .eq('cost_item_id', costItemId)
            .neq('status', DocumentStatus.archived.dbValue)
            .order('uploaded_at', ascending: false);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<TripDocument>> fetchForRunSheetItem(String runSheetItemId) =>
      guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select()
            .eq('run_sheet_item_id', runSheetItemId)
            .neq('status', DocumentStatus.archived.dbValue)
            .order('uploaded_at', ascending: false);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<TripDocument> create(TripDocument doc, String teamId) =>
      guardDb(() async {
        final row = await _client
            .from(_kTable)
            .insert({
              ..._toRow(doc, teamId: teamId),
              'uploaded_by': _client.auth.currentUser?.id,
            })
            .select()
            .single();
        return _fromRow(row);
      });

  @override
  Future<TripDocument> update(TripDocument doc) => guardDb(() async {
        final row = await _client
            .from(_kTable)
            .update(_toRow(doc))
            .eq('id', doc.id)
            .select()
            .single();
        return _fromRow(row);
      });

  @override
  Future<TripDocument> archive(String id) => guardDb(() async {
        final row = await _client
            .from(_kTable)
            .update({'status': DocumentStatus.archived.dbValue})
            .eq('id', id)
            .select()
            .single();
        return _fromRow(row);
      });

  @override
  Future<void> delete(String id) => guardDb(() async {
        await _client.from(_kTable).delete().eq('id', id);
      });

  @override
  Future<String> uploadToStorage({
    required String teamId,
    required String tripId,
    required String docId,
    required String fileName,
    required List<int> bytes,
    String? contentType,
  }) =>
      guardDb(() async {
        final path = '$teamId/$tripId/$docId/$fileName';
        await _client.storage.from(_kBucket).uploadBinary(
              path,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(
                contentType: contentType,
                upsert:      true,
              ),
            );
        return path;
      });

  @override
  String getPublicUrl(String storagePath) =>
      _client.storage.from(_kBucket).getPublicUrl(storagePath);
}
