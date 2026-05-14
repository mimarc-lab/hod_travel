import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier_media.dart';
import '../../core/errors/app_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SupplierMediaRepository {
  /// Active media for a supplier, ordered by display_order then created_at.
  Future<List<SupplierMedia>> fetchForSupplier(String supplierId);

  Future<SupplierMedia> create(SupplierMedia media, String teamId);
  Future<SupplierMedia> update(SupplierMedia media);

  /// Soft-deletes by setting is_active = false.
  Future<void> deactivate(String id);

  /// Hard-deletes. Prefer [deactivate] unless storage cleanup is also needed.
  Future<void> delete(String id);

  /// Sets [mediaId] as the hero for its supplier; clears any previous hero.
  Future<void> setHero(String supplierId, String mediaId);

  /// Clears the hero flag for all media belonging to [supplierId].
  Future<void> clearHero(String supplierId);

  /// Batch-updates display_order. [orderedIds] is the desired sequence.
  Future<void> reorder(String supplierId, List<String> orderedIds);

  /// Uploads [bytes] to Supabase Storage. Returns the storage path.
  Future<String> uploadToStorage({
    required String   teamId,
    required String   supplierId,
    required String   mediaId,
    required String   fileName,
    required Uint8List bytes,
    String?           contentType,
  });

  /// Deletes a file from Supabase Storage by its path.
  Future<void> deleteFromStorage(String storagePath);

  /// Returns a public URL for a given storage path.
  String getPublicUrl(String storagePath);
}

// ─────────────────────────────────────────────────────────────────────────────
// Row mappers
// ─────────────────────────────────────────────────────────────────────────────

SupplierMedia _fromRow(Map<String, dynamic> r) => SupplierMedia(
      id:           r['id']           as String,
      teamId:       r['team_id']      as String,
      supplierId:   r['supplier_id']  as String,
      mediaType:    SupplierMediaType.fromDb(r['media_type'] as String? ?? 'image'),
      fileUrl:      r['file_url']     as String,
      thumbnailUrl: r['thumbnail_url'] as String?,
      storagePath:  r['storage_path'] as String? ?? '',
      mimeType:     r['mime_type']    as String?,
      videoUrl:     r['video_url']    as String?,
      title:        r['title']        as String? ?? '',
      description:  r['description']  as String?,
      caption:      r['caption']      as String?,
      isHero:       r['is_hero']      as bool? ?? false,
      isActive:     r['is_active']    as bool? ?? true,
      displayOrder: r['display_order'] as int?,
      tags: (r['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      createdAt:  DateTime.parse(r['created_at'] as String),
      uploadedBy: r['uploaded_by'] as String?,
    );

Map<String, dynamic> _toRow(SupplierMedia m, {String? teamId}) => {
      'team_id': ?teamId,
      'supplier_id':   m.supplierId,
      'media_type':    m.mediaType.dbValue,
      'file_url':      m.fileUrl,
      'thumbnail_url': m.thumbnailUrl,
      'storage_path':  m.storagePath,
      'mime_type':     m.mimeType,
      'video_url':     m.videoUrl,
      'title':         m.title,
      'description':   m.description,
      'caption':       m.caption,
      'is_hero':       m.isHero,
      'is_active':     m.isActive,
      'display_order': m.displayOrder,
      'tags':          m.tags,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseSupplierMediaRepository implements SupplierMediaRepository {
  final SupabaseClient _client;
  SupabaseSupplierMediaRepository(this._client);

  static const _kTable  = 'supplier_media';
  static const _kBucket = 'supplier-media';

  @override
  Future<List<SupplierMedia>> fetchForSupplier(String supplierId) =>
      guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select()
            .eq('supplier_id', supplierId)
            .eq('is_active', true)
            .order('display_order', ascending: true, nullsFirst: false)
            .order('created_at',    ascending: true);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<SupplierMedia> create(SupplierMedia media, String teamId) =>
      guardDb(() async {
        final row = await _client
            .from(_kTable)
            .insert({
              ..._toRow(media, teamId: teamId),
              'uploaded_by': _client.auth.currentUser?.id,
            })
            .select()
            .single();
        return _fromRow(row);
      });

  @override
  Future<SupplierMedia> update(SupplierMedia media) => guardDb(() async {
        final row = await _client
            .from(_kTable)
            .update(_toRow(media))
            .eq('id', media.id)
            .select()
            .single();
        return _fromRow(row);
      });

  @override
  Future<void> deactivate(String id) => guardDb(() async {
        await _client
            .from(_kTable)
            .update({'is_active': false, 'is_hero': false})
            .eq('id', id);
      });

  @override
  Future<void> delete(String id) => guardDb(() async {
        await _client.from(_kTable).delete().eq('id', id);
      });

  @override
  Future<void> setHero(String supplierId, String mediaId) =>
      guardDb(() async {
        // Clear all heroes for this supplier, then set the new one.
        // Done in two steps because the partial unique index prevents
        // having two rows with is_hero = true simultaneously.
        await _client
            .from(_kTable)
            .update({'is_hero': false})
            .eq('supplier_id', supplierId)
            .eq('is_hero', true);
        await _client
            .from(_kTable)
            .update({'is_hero': true})
            .eq('id', mediaId);
      });

  @override
  Future<void> clearHero(String supplierId) => guardDb(() async {
        await _client
            .from(_kTable)
            .update({'is_hero': false})
            .eq('supplier_id', supplierId);
      });

  @override
  Future<void> reorder(String supplierId, List<String> orderedIds) =>
      guardDb(() async {
        for (int i = 0; i < orderedIds.length; i++) {
          await _client
              .from(_kTable)
              .update({'display_order': i})
              .eq('id', orderedIds[i]);
        }
      });

  @override
  Future<String> uploadToStorage({
    required String    teamId,
    required String    supplierId,
    required String    mediaId,
    required String    fileName,
    required Uint8List bytes,
    String?            contentType,
  }) =>
      guardDb(() async {
        final path = '$teamId/$supplierId/$mediaId/$fileName';
        await _client.storage.from(_kBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert:      true,
              ),
            );
        return path;
      });

  @override
  Future<void> deleteFromStorage(String storagePath) => guardDb(() async {
        await _client.storage.from(_kBucket).remove([storagePath]);
      });

  @override
  String getPublicUrl(String storagePath) =>
      _client.storage.from(_kBucket).getPublicUrl(storagePath);
}
