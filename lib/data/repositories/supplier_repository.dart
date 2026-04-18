import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SupplierRepository {
  Future<List<Supplier>> fetchAll(String teamId);
  Future<Supplier?> fetchById(String id);
  Future<Supplier> create(Supplier supplier, String teamId);
  Future<Supplier> update(Supplier supplier);
  Future<void> delete(String id);
  Future<void> setTags(String supplierId, String teamId, List<String> tagNames);

  /// Realtime stream — emits a refreshed supplier list whenever any supplier
  /// in [teamId] is inserted, updated, or deleted.
  Stream<List<Supplier>> watchForTeam(String teamId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

Supplier _fromRow(Map<String, dynamic> r, {List<String> tags = const []}) {
  final rating = r['internal_rating'];
  return Supplier(
    id: r['id'] as String,
    teamId: r['team_id'] as String?,
    name: r['name'] as String,
    category: SupplierCategoryDisplay.fromDb(
      r['category'] as String? ?? 'other',
    ),
    location: r['location'] as String?,
    city: r['city'] as String? ?? '',
    country: r['country'] as String? ?? '',
    contactName: r['contact_name'] as String?,
    contactEmail: r['contact_email'] as String?,
    contactPhone: r['contact_phone'] as String?,
    preferred: r['preferred'] as bool? ?? false,
    internalRating: rating != null ? (rating as num).toDouble() : 3.0,
    notes: r['notes'] as String?,
    website: r['website'] as String?,
    tags: tags,
  );
}

Map<String, dynamic> _toRow(Supplier s, {String? teamId}) => {
  'team_id': ?teamId,
  'name': s.name,
  'category': s.category.dbValue,
  'location': s.location,
  'city': s.city,
  'country': s.country,
  'contact_name': s.contactName,
  'contact_email': s.contactEmail,
  'contact_phone': s.contactPhone,
  'preferred': s.preferred,
  'internal_rating': s.internalRating,
  'notes': s.notes,
  'website': s.website,
};

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseSupplierRepository implements SupplierRepository {
  final SupabaseClient _client;
  SupabaseSupplierRepository(this._client);

  /// Load tag names for the given supplier IDs.
  Future<Map<String, List<String>>> _loadTags(List<String> supplierIds) async {
    if (supplierIds.isEmpty) return {};
    final rows = await _client
        .from('supplier_tag_links')
        .select('supplier_id, supplier_tags(name)')
        .inFilter('supplier_id', supplierIds);
    final result = <String, List<String>>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final sid = row['supplier_id'] as String;
      final name =
          (row['supplier_tags'] as Map<String, dynamic>?)?['name'] as String? ??
          '';
      result.putIfAbsent(sid, () => []).add(name);
    }
    return result;
  }

  @override
  Future<List<Supplier>> fetchAll(String teamId) async {
    final rows = await _client
        .from('suppliers')
        .select()
        .eq('team_id', teamId)
        .order('name');
    final list = rows as List;
    final supplierIds = list
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    final tags = await _loadTags(supplierIds);

    return list.map((r) {
      final row = r as Map<String, dynamic>;
      return _fromRow(row, tags: tags[row['id'] as String] ?? []);
    }).toList();
  }

  @override
  Future<Supplier?> fetchById(String id) async {
    final row = await _client
        .from('suppliers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final tags = await _loadTags([id]);
    return _fromRow(row, tags: tags[id] ?? []);
  }

  @override
  Future<Supplier> create(Supplier supplier, String teamId) async {
    final row = await _client
        .from('suppliers')
        .insert({
          ..._toRow(supplier, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    final id = row['id'] as String;
    if (supplier.tags.isNotEmpty) {
      await setTags(id, teamId, supplier.tags);
    }
    return _fromRow(row, tags: supplier.tags);
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    final row = await _client
        .from('suppliers')
        .update(_toRow(supplier))
        .eq('id', supplier.id)
        .select()
        .single();
    if (supplier.teamId != null) {
      await setTags(supplier.id, supplier.teamId!, supplier.tags);
    }
    return _fromRow(row, tags: supplier.tags);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }

  @override
  Stream<List<Supplier>> watchForTeam(String teamId) {
    final controller = StreamController<List<Supplier>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchAll(teamId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('suppliers:$teamId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'suppliers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> setTags(
    String supplierId,
    String teamId,
    List<String> tagNames,
  ) async {
    // Delete existing links
    await _client
        .from('supplier_tag_links')
        .delete()
        .eq('supplier_id', supplierId);

    if (tagNames.isEmpty) return;

    // Upsert tags and get their IDs
    final tagRows = await _client
        .from('supplier_tags')
        .upsert(
          tagNames.map((n) => {'team_id': teamId, 'name': n}).toList(),
          onConflict: 'team_id,name',
        )
        .select('id, name');

    // Insert links
    final links = (tagRows as List)
        .map(
          (r) => {
            'supplier_id': supplierId,
            'tag_id': (r as Map<String, dynamic>)['id'] as String,
          },
        )
        .toList();
    if (links.isNotEmpty) {
      await _client.from('supplier_tag_links').insert(links);
    }
  }
}
