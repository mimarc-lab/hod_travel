import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_component_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TripComponentRepository {
  Future<List<TripComponent>> fetchForTrip(String tripId);
  Future<TripComponent> create(TripComponent component, String teamId);
  Future<TripComponent> update(TripComponent component);
  Future<void> delete(String id);
  Stream<List<TripComponent>> watchForTrip(String tripId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapper
// ─────────────────────────────────────────────────────────────────────────────

TripComponent _fromRow(Map<String, dynamic> r) {
  final supplier = r['suppliers'] as Map<String, dynamic>?;
  return TripComponent(
    id:              r['id'] as String,
    tripId:          r['trip_id'] as String,
    teamId:          r['team_id'] as String,
    componentType:   componentTypeFromDb(r['component_type'] as String? ?? 'other'),
    status:          componentStatusFromDb(r['status'] as String? ?? 'proposed'),
    title:           r['title'] as String,
    supplierId:      r['supplier_id'] as String?,
    supplierName:    supplier?['name'] as String?,
    startDate:       r['start_date'] != null ? DateTime.parse(r['start_date'] as String) : null,
    endDate:         r['end_date'] != null ? DateTime.parse(r['end_date'] as String) : null,
    startTime:       r['start_time'] as String?,
    endTime:         r['end_time'] as String?,
    locationName:    r['location_name'] as String?,
    address:         r['address'] as String?,
    notesInternal:   r['notes_internal'] as String?,
    notesClient:     r['notes_client'] as String?,
    costItemId:      r['cost_item_id'] as String?,
    itineraryItemId: r['itinerary_item_id'] as String?,
    runSheetItemId:  r['run_sheet_item_id'] as String?,
    createdBy:       r['created_by'] as String?,
    createdAt:       DateTime.parse(r['created_at'] as String),
    updatedAt:       DateTime.parse(r['updated_at'] as String),
  );
}

Map<String, dynamic> _toRow(TripComponent c, {String? teamId}) => {
  if (teamId != null) 'team_id': teamId,
  'trip_id':          c.tripId,
  'component_type':   c.componentType.dbValue,
  'status':           c.status.dbValue,
  'title':            c.title,
  'supplier_id':      c.supplierId,
  'start_date':       c.startDate?.toIso8601String().substring(0, 10),
  'end_date':         c.endDate?.toIso8601String().substring(0, 10),
  'start_time':       c.startTime,
  'end_time':         c.endTime,
  'location_name':    c.locationName,
  'address':          c.address,
  'notes_internal':   c.notesInternal,
  'notes_client':     c.notesClient,
  'cost_item_id':     c.costItemId,
  'itinerary_item_id': c.itineraryItemId,
  'run_sheet_item_id': c.runSheetItemId,
};

const _kSelect = '*, suppliers(id, name)';

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseTripComponentRepository implements TripComponentRepository {
  final SupabaseClient _client;
  SupabaseTripComponentRepository(this._client);

  @override
  Future<List<TripComponent>> fetchForTrip(String tripId) async {
    final rows = await _client
        .from('trip_components')
        .select(_kSelect)
        .eq('trip_id', tripId)
        .order('created_at');
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<TripComponent> create(TripComponent component, String teamId) async {
    final row = await _client
        .from('trip_components')
        .insert({
          ..._toRow(component, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select(_kSelect)
        .single();
    return _fromRow(row);
  }

  @override
  Future<TripComponent> update(TripComponent component) async {
    final row = await _client
        .from('trip_components')
        .update(_toRow(component))
        .eq('id', component.id)
        .select(_kSelect)
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('trip_components').delete().eq('id', id);
  }

  @override
  Stream<List<TripComponent>> watchForTrip(String tripId) {
    final controller = StreamController<List<TripComponent>>.broadcast();

    Future<void> emit() async {
      try {
        final items = await fetchForTrip(tripId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {}
    }

    emit();

    final channel = _client
        .channel('trip_components:trip:$tripId:${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_components',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
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
}
