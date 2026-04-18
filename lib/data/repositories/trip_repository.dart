import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TripRepository {
  Future<List<Trip>> fetchAll(String teamId);
  Future<Trip?> fetchById(String id);
  Future<Trip> create(Trip trip, String teamId);
  Future<Trip> update(Trip trip);
  Future<void> delete(String id);
  /// Insert destination rows for [tripId]. Existing rows are deleted first.
  Future<void> saveDestinations(String tripId, List<String> cities);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mappers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a Trip from a trips row + pre-loaded profiles map.
/// `destinations` is assembled from a separate trip_destinations fetch
/// or passed in directly when already resolved.
Trip tripFromRow(
  Map<String, dynamic> row,
  Map<String, AppUser> profilesById, {
  List<String> destinations = const [],
}) {
  final leadId = row['trip_lead_id'] as String?;
  final lead =
      (leadId != null ? profilesById[leadId] : null) ??
      AppUser(
        id: leadId ?? 'unknown',
        name: 'Unknown',
        initials: '?',
        avatarColor: avatarColorFor(0),
        role: 'Staff',
        appRole: AppRole.staff,
      );

  return Trip(
    id: row['id'] as String,
    teamId: row['team_id'] as String?,
    name: row['trip_name'] as String,
    clientName: row['client_name'] as String? ?? '',
    startDate: row['start_date'] != null
        ? DateTime.parse(row['start_date'] as String)
        : null,
    endDate: row['end_date'] != null
        ? DateTime.parse(row['end_date'] as String)
        : null,
    destinations: destinations,
    guestCount: row['number_of_guests'] as int? ?? 1,
    tripLead: lead,
    status: TripStatusLabel.fromDb(row['status'] as String? ?? 'planning'),
    notes: row['notes'] as String?,
  );
}

Map<String, dynamic> _tripToRow(Trip t, String? teamId) => {
  'team_id': ?teamId,
  'trip_name': t.name,
  'client_name': t.clientName,
  'start_date': t.startDate?.toIso8601String().substring(0, 10),
  'end_date': t.endDate?.toIso8601String().substring(0, 10),
  'number_of_guests': t.guestCount,
  'trip_lead_id': t.tripLead.id == 'unknown' ? null : t.tripLead.id,
  'status': t.status.dbValue,
  'notes': t.notes,
};

// ─────────────────────────────────────────────────────────────────────────────
// Supabase implementation
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseTripRepository implements TripRepository {
  final SupabaseClient _client;
  SupabaseTripRepository(this._client);

  Future<Map<String, List<String>>> _loadDestinations(
    List<String> tripIds,
  ) async {
    if (tripIds.isEmpty) return {};
    final rows = await _client
        .from('trip_destinations')
        .select('trip_id, city, country, sort_order')
        .inFilter('trip_id', tripIds)
        .order('sort_order');
    final result = <String, List<String>>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final tripId = row['trip_id'] as String;
      final city = row['city'] as String? ?? '';
      result.putIfAbsent(tripId, () => []).add(city);
    }
    return result;
  }

  @override
  Future<List<Trip>> fetchAll(String teamId) async {
    final rows = await _client
        .from('trips')
        .select()
        .eq('team_id', teamId)
        .order('created_at', ascending: false);
    final list = rows as List;
    final profiles = await loadProfilesAsMap(_client);
    final tripIds = list
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toList();
    final destinations = await _loadDestinations(tripIds);

    return list.map((r) {
      final row = r as Map<String, dynamic>;
      return tripFromRow(
        row,
        profiles,
        destinations: destinations[row['id'] as String] ?? [],
      );
    }).toList();
  }

  @override
  Future<Trip?> fetchById(String id) async {
    final row = await _client.from('trips').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final profiles = await loadProfilesAsMap(_client);
    final destinations = await _loadDestinations([id]);
    return tripFromRow(row, profiles, destinations: destinations[id] ?? []);
  }

  @override
  Future<Trip> create(Trip trip, String teamId) async {
    final inserted = await _client
        .from('trips')
        .insert({
          ..._tripToRow(trip, teamId),
          'created_by': _client.auth.currentUser?.id,
        })
        .select()
        .single();

    // Insert destinations
    if (trip.destinations.isNotEmpty) {
      final tripId = inserted['id'] as String;
      await _saveDestinations(tripId, trip.destinations);
    }

    final profiles = await loadProfilesAsMap(_client);
    final tripId = inserted['id'] as String;
    final destinations = await _loadDestinations([tripId]);
    return tripFromRow(
      inserted,
      profiles,
      destinations: destinations[tripId] ?? [],
    );
  }

  @override
  Future<Trip> update(Trip trip) async {
    final updated = await _client
        .from('trips')
        .update(_tripToRow(trip, null))
        .eq('id', trip.id)
        .select()
        .single();

    // Replace destinations
    await _client.from('trip_destinations').delete().eq('trip_id', trip.id);
    if (trip.destinations.isNotEmpty) {
      await _saveDestinations(trip.id, trip.destinations);
    }

    final profiles = await loadProfilesAsMap(_client);
    final destinations = await _loadDestinations([trip.id]);
    return tripFromRow(
      updated,
      profiles,
      destinations: destinations[trip.id] ?? [],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('trips').delete().eq('id', id);
  }

  @override
  Future<void> saveDestinations(String tripId, List<String> cities) =>
      _saveDestinations(tripId, cities);

  Future<void> _saveDestinations(String tripId, List<String> cities) async {
    final rows = cities
        .asMap()
        .entries
        .map((e) => {'trip_id': tripId, 'city': e.value, 'sort_order': e.key})
        .toList();
    await _client.from('trip_destinations').insert(rows);
  }
}
