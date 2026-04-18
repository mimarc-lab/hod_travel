import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_model.dart';
import '../models/itinerary_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot emitted by [ItineraryRepository.watchForTrip].
typedef ItinerarySnapshot = ({
  List<TripDay> days,
  Map<String, List<ItineraryItem>> items,
});

abstract class ItineraryRepository {
  Future<List<TripDay>> fetchDaysForTrip(String tripId);
  Future<Map<String, List<ItineraryItem>>> fetchItemsForTrip(String tripId);
  /// Insert a new day — DB generates the UUID.
  Future<TripDay> createDay(TripDay day, String teamId);
  /// Upsert an existing day by its known UUID (for edits).
  Future<TripDay> upsertDay(TripDay day, String teamId);
  Future<ItineraryItem> createItem(ItineraryItem item, String teamId);
  Future<ItineraryItem> updateItem(ItineraryItem item);
  Future<void> deleteItem(String id);

  /// Persists the display order of [items] by writing a new `sort_order` to
  /// each row. [items] should be the full ordered list for one trip day so that
  /// sort_order values are unique within the day (UNIQUE constraint on
  /// (trip_day_id, sort_order)).
  Future<void> updateSortOrders(List<ItineraryItem> items);

  /// Realtime stream — emits a full snapshot whenever trip_days or
  /// itinerary_items change for [tripId]. Uses [teamId] to scope the
  /// itinerary_items channel (trip_days are filtered by trip_id directly).
  Stream<ItinerarySnapshot> watchForTrip(String tripId, String teamId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

TripDay _dayFromRow(Map<String, dynamic> r) => TripDay(
  id: r['id'] as String,
  tripId: r['trip_id'] as String,
  teamId: r['team_id'] as String?,
  dayNumber: r['day_number'] as int,
  date: r['date'] != null ? DateTime.parse(r['date'] as String) : null,
  city: r['city'] as String? ?? '',
  title: r['title'] as String?,
  label: r['title'] as String?, // alias for back-compat
);

Map<String, dynamic> _dayToRow(TripDay d, {String? teamId}) => {
  'team_id': ?teamId,
  'trip_id': d.tripId,
  'day_number': d.dayNumber,
  'date': d.date?.toIso8601String().substring(0, 10),
  'city': d.city,
  'title': d.title ?? d.label,
};

ItineraryItem _itemFromRow(Map<String, dynamic> r) {
  TimeOfDay? parseTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    final parts = s.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  return ItineraryItem(
    id: r['id'] as String,
    tripDayId: r['trip_day_id'] as String,
    teamId: r['team_id'] as String?,
    type: ItemTypeLabel.fromDb(r['type'] as String? ?? 'note'),
    title: r['title'] as String,
    description: r['description'] as String?,
    startTime: parseTime(r['start_time']),
    endTime: parseTime(r['end_time']),
    timeBlock: TimeBlockLabel.fromDb(r['time_block'] as String? ?? 'morning'),
    location: r['location'] as String?,
    supplierId: r['supplier_id'] as String?,
    status: ItemStatusLabel.fromDb(r['status'] as String? ?? 'draft'),
    approvalStatus: approvalStatusFromDb(r['approval_status'] as String? ?? 'draft'),
    linkedTaskId: r['linked_task_id'] as String?,
    notes: r['notes'] as String?,
  );
}

Map<String, dynamic> _itemToRow(ItineraryItem i, {String? teamId}) {
  String? fmtTime(TimeOfDay? t) => t != null
      ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
      : null;

  return {
    'team_id': ?teamId,
    'trip_day_id': i.tripDayId,
    'type': i.type.dbValue,
    'title': i.title,
    'description': i.description,
    'start_time': fmtTime(i.startTime),
    'end_time': fmtTime(i.endTime),
    'time_block': i.timeBlock.dbValue,
    'location': i.location,
    'supplier_id': i.supplierId,
    'status': i.status.dbValue,
    'approval_status': i.approvalStatus.dbValue,
    'linked_task_id': i.linkedTaskId,
    'notes': i.notes,
    // Use epoch-seconds so each insert gets a unique sort_order even if the
    // column has a UNIQUE constraint on (trip_day_id, sort_order).
    'sort_order': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseItineraryRepository implements ItineraryRepository {
  final SupabaseClient _client;
  SupabaseItineraryRepository(this._client);

  @override
  Future<List<TripDay>> fetchDaysForTrip(String tripId) async {
    final rows = await _client
        .from('trip_days')
        .select()
        .eq('trip_id', tripId)
        .order('day_number', ascending: true);
    return (rows as List)
        .map((r) => _dayFromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, List<ItineraryItem>>> fetchItemsForTrip(
    String tripId,
  ) async {
    final days = await fetchDaysForTrip(tripId);
    if (days.isEmpty) return {};

    final dayIds = days.map((d) => d.id).toList();
    final rows = await _client
        .from('itinerary_items')
        .select()
        .inFilter('trip_day_id', dayIds)
        .order('sort_order');

    final result = <String, List<ItineraryItem>>{};
    for (final r in rows as List) {
      final item = _itemFromRow(r as Map<String, dynamic>);
      result.putIfAbsent(item.tripDayId, () => []).add(item);
    }
    return result;
  }

  @override
  Future<TripDay> createDay(TripDay day, String teamId) async {
    // No 'id' — DB generates a UUID via gen_random_uuid().
    final row = await _client
        .from('trip_days')
        .insert(_dayToRow(day, teamId: teamId))
        .select()
        .single();
    return _dayFromRow(row);
  }

  @override
  Future<TripDay> upsertDay(TripDay day, String teamId) async {
    final row = await _client
        .from('trip_days')
        .upsert({'id': day.id, ..._dayToRow(day, teamId: teamId)})
        .select()
        .single();
    return _dayFromRow(row);
  }

  @override
  Future<ItineraryItem> createItem(ItineraryItem item, String teamId) async {
    final row = await _client
        .from('itinerary_items')
        .insert({
          ..._itemToRow(item, teamId: teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return _itemFromRow(row);
  }

  @override
  Future<ItineraryItem> updateItem(ItineraryItem item) async {
    final row = await _client
        .from('itinerary_items')
        .update(_itemToRow(item))
        .eq('id', item.id)
        .select()
        .single();
    return _itemFromRow(row);
  }

  @override
  Future<void> deleteItem(String id) async {
    await _client.from('itinerary_items').delete().eq('id', id);
  }

  @override
  Future<void> updateSortOrders(List<ItineraryItem> items) async {
    if (items.isEmpty) return;
    // Run all updates in parallel; multiply index by 100 to leave gaps for
    // future inserts without needing to renumber every time.
    await Future.wait([
      for (int i = 0; i < items.length; i++)
        _client
            .from('itinerary_items')
            .update({'sort_order': (i + 1) * 100})
            .eq('id', items[i].id),
    ]);
  }

  @override
  Stream<ItinerarySnapshot> watchForTrip(String tripId, String teamId) {
    final controller = StreamController<ItinerarySnapshot>.broadcast();

    Future<void> emit() async {
      try {
        final days  = await fetchDaysForTrip(tripId);
        final items = await fetchItemsForTrip(tripId);
        if (!controller.isClosed) controller.add((days: days, items: items));
      } catch (_) {}
    }

    // Seed immediately
    emit();

    // Channel 1: trip_days changes for this trip
    final ts = DateTime.now().microsecondsSinceEpoch;
    final daysChannel = _client
        .channel('itinerary_days:$tripId:$ts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_days',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    // Channel 2: itinerary_items for the team (closest available filter
    // since itinerary_items has no direct trip_id column).
    final itemsChannel = _client
        .channel('itinerary_items:$teamId:$ts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'itinerary_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => emit(),
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(daysChannel);
      _client.removeChannel(itemsChannel);
      controller.close();
    };

    return controller.stream;
  }
}
