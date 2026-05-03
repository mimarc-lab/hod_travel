import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/component_media.dart';
import '../models/supplier_media.dart';
import '../../core/errors/app_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class ComponentMediaRepository {
  /// All component_media rows for [componentId], ordered by display_order.
  /// Includes a join on supplier_media so [ComponentMedia.media] is populated.
  Future<List<ComponentMedia>> fetchForComponent(String componentId);

  /// Links a supplier media item to a component.
  Future<ComponentMedia> add({
    required String teamId,
    required String componentId,
    required String supplierMediaId,
  });

  Future<ComponentMedia> update(ComponentMedia item);

  /// Removes the link (hard-delete — the underlying supplier_media is untouched).
  Future<void> remove(String id);

  /// Sets [id] as the hero for [componentId]; clears any previous hero.
  Future<void> setHero(String componentId, String id);

  /// Clears the hero flag for all links belonging to [componentId].
  Future<void> clearHero(String componentId);

  /// Batch-updates display_order. [orderedIds] is the desired sequence.
  Future<void> reorder(String componentId, List<String> orderedIds);

  /// Fetches all client-visible media for a set of component IDs in one query.
  /// Used by ClientMediaPresenter to load the full trip's media efficiently.
  Future<List<ComponentMedia>> fetchClientVisibleForComponents(
      List<String> componentIds);
}

// ─────────────────────────────────────────────────────────────────────────────
// Row mappers
// ─────────────────────────────────────────────────────────────────────────────

SupplierMedia? _mediaFromNested(dynamic nested) {
  if (nested == null) return null;
  final r = nested as Map<String, dynamic>;
  return SupplierMedia(
    id:           r['id']            as String,
    teamId:       r['team_id']       as String,
    supplierId:   r['supplier_id']   as String,
    mediaType:    SupplierMediaType.fromDb(r['media_type'] as String? ?? 'image'),
    fileUrl:      r['file_url']      as String,
    thumbnailUrl: r['thumbnail_url'] as String?,
    storagePath:  r['storage_path']  as String? ?? '',
    mimeType:     r['mime_type']     as String?,
    videoUrl:     r['video_url']     as String?,
    title:        r['title']         as String? ?? '',
    description:  r['description']   as String?,
    caption:      r['caption']       as String?,
    isHero:       r['is_hero']       as bool? ?? false,
    isActive:     r['is_active']     as bool? ?? true,
    displayOrder: r['display_order'] as int?,
    tags: (r['tags'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [],
    createdAt:  DateTime.parse(r['created_at'] as String),
    uploadedBy: r['uploaded_by'] as String?,
  );
}

ComponentMedia _fromRow(Map<String, dynamic> r) => ComponentMedia(
      id:              r['id']               as String,
      teamId:          r['team_id']          as String,
      componentId:     r['component_id']     as String,
      supplierMediaId: r['supplier_media_id'] as String,
      isHero:          r['is_hero']          as bool? ?? false,
      isVisible:       r['is_visible']       as bool? ?? true,
      captionOverride: r['caption_override'] as String?,
      displayOrder:    r['display_order']    as int?,
      createdAt:       DateTime.parse(r['created_at'] as String),
      createdBy:       r['created_by']       as String?,
      media:           _mediaFromNested(r['supplier_media']),
    );

Map<String, dynamic> _toRow(ComponentMedia m) => {
      'is_hero':          m.isHero,
      'is_visible':       m.isVisible,
      'caption_override': m.captionOverride,
      'display_order':    m.displayOrder,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseComponentMediaRepository implements ComponentMediaRepository {
  final SupabaseClient _client;
  SupabaseComponentMediaRepository(this._client);

  static const _kTable = 'component_media';

  @override
  Future<List<ComponentMedia>> fetchForComponent(String componentId) =>
      guardDb(() async {
        final rows = await _client
            .from(_kTable)
            .select('*, supplier_media(*)')
            .eq('component_id', componentId)
            .order('display_order', ascending: true, nullsFirst: false)
            .order('created_at',    ascending: true);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<ComponentMedia> add({
    required String teamId,
    required String componentId,
    required String supplierMediaId,
  }) =>
      guardDb(() async {
        final row = await _client
            .from(_kTable)
            .insert({
              'team_id':           teamId,
              'component_id':      componentId,
              'supplier_media_id': supplierMediaId,
              'created_by':        _client.auth.currentUser?.id,
            })
            .select('*, supplier_media(*)')
            .single();
        return _fromRow(row);
      });

  @override
  Future<ComponentMedia> update(ComponentMedia item) => guardDb(() async {
        final row = await _client
            .from(_kTable)
            .update(_toRow(item))
            .eq('id', item.id)
            .select('*, supplier_media(*)')
            .single();
        return _fromRow(row);
      });

  @override
  Future<void> remove(String id) => guardDb(() async {
        await _client.from(_kTable).delete().eq('id', id);
      });

  @override
  Future<void> setHero(String componentId, String id) => guardDb(() async {
        await _client
            .from(_kTable)
            .update({'is_hero': false})
            .eq('component_id', componentId)
            .eq('is_hero', true);
        await _client
            .from(_kTable)
            .update({'is_hero': true})
            .eq('id', id);
      });

  @override
  Future<void> clearHero(String componentId) => guardDb(() async {
        await _client
            .from(_kTable)
            .update({'is_hero': false})
            .eq('component_id', componentId);
      });

  @override
  Future<void> reorder(String componentId, List<String> orderedIds) =>
      guardDb(() async {
        for (int i = 0; i < orderedIds.length; i++) {
          await _client
              .from(_kTable)
              .update({'display_order': i})
              .eq('id', orderedIds[i]);
        }
      });

  @override
  Future<List<ComponentMedia>> fetchClientVisibleForComponents(
      List<String> componentIds) =>
      guardDb(() async {
        if (componentIds.isEmpty) return <ComponentMedia>[];
        final rows = await _client
            .from(_kTable)
            .select('*, supplier_media(*)')
            .inFilter('component_id', componentIds)
            .eq('is_visible', true)
            .order('is_hero',       ascending: false)
            .order('display_order', ascending: true, nullsFirst: false)
            .order('created_at',    ascending: true);
        return (rows as List)
            .map((r) => _fromRow(r as Map<String, dynamic>))
            .where((cm) => cm.media?.isActive ?? false)
            .toList();
      });
}
