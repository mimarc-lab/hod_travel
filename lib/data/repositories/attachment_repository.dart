import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attachment_model.dart';
import '../../core/errors/app_exception.dart';

// =============================================================================
// AttachmentRepository
// Manages attachment metadata rows in public.attachments.
// Actual file upload/download via Supabase Storage is intentionally out of
// scope here — add a StorageService when the upload UI is built.
// =============================================================================

abstract class AttachmentRepository {
  /// All attachments for a specific entity (e.g. a task or supplier).
  Future<List<AttachmentRecord>> fetchForEntity({
    required String relatedTable,
    required String relatedId,
  });

  /// All attachments for a team.
  Future<List<AttachmentRecord>> fetchForTeam(String teamId);

  /// Insert a metadata row after a file has been uploaded to Storage.
  Future<AttachmentRecord> create(AttachmentRecord record);

  /// Delete the metadata row.
  /// Note: deleting the actual file from Storage must be done separately.
  Future<void> delete(String id);
}

// =============================================================================
// Supabase implementation
// =============================================================================

class SupabaseAttachmentRepository implements AttachmentRepository {
  final SupabaseClient _client;
  SupabaseAttachmentRepository(this._client);

  @override
  Future<List<AttachmentRecord>> fetchForEntity({
    required String relatedTable,
    required String relatedId,
  }) =>
      guardDb(() async {
        final rows = await _client
            .from('attachments')
            .select()
            .eq('related_table', relatedTable)
            .eq('related_id', relatedId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => AttachmentRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<List<AttachmentRecord>> fetchForTeam(String teamId) =>
      guardDb(() async {
        final rows = await _client
            .from('attachments')
            .select()
            .eq('team_id', teamId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((r) => AttachmentRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<AttachmentRecord> create(AttachmentRecord record) =>
      guardDb(() async {
        final row = await _client
            .from('attachments')
            .insert(record.toMap())
            .select()
            .single();
        return AttachmentRecord.fromMap(row);
      });

  @override
  Future<void> delete(String id) => guardDb(() async {
        await _client.from('attachments').delete().eq('id', id);
      });
}
