import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import 'trip_templates.dart';

// =============================================================================
// TripCreationService
//
// Orchestrates the multi-step trip creation flow:
//   1. Insert the trips row
//   2. Insert trip_destinations rows (city names, ordered)
//   3. Default board_groups are created automatically by the DB trigger
//   4. If a template is selected, fetch board groups and insert template tasks
//
// Returns the fully created Trip.
// =============================================================================

class TripCreationService {
  final TripRepository _trips;
  final SupabaseClient _client;

  TripCreationService(this._trips, this._client);

  Future<Trip> createTrip({
    required Trip trip,
    required String teamId,
    List<String> destinationCities = const [],
    String? templateId,
  }) async {
    // 1. Create the trip row (board groups created by DB trigger)
    final created = await _trips.create(trip, teamId);

    // 2. Save destination rows if provided
    if (destinationCities.isNotEmpty) {
      await _trips.saveDestinations(created.id, destinationCities);
    }

    // 3. Seed template tasks if a template was selected
    final tasks = templateTasks(templateId);
    if (tasks.isNotEmpty) {
      await _insertTemplateTasks(
        tripId: created.id,
        teamId: teamId,
        userId: _client.auth.currentUser?.id ?? '',
        tasks:  tasks,
      );
    }

    return created;
  }

  /// Fetches the board groups for [tripId] (created by DB trigger),
  /// then bulk-inserts template tasks assigned to the correct group.
  Future<void> _insertTemplateTasks({
    required String tripId,
    required String teamId,
    required String userId,
    required List<Map<String, String>> tasks,
  }) async {
    // Fetch groups — the DB trigger should have already created them.
    // Retry once with a short delay if the trigger hasn't fired yet.
    var groupRows = await _client
        .from('board_groups')
        .select('id, name')
        .eq('trip_id', tripId) as List;

    if (groupRows.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      groupRows = await _client
          .from('board_groups')
          .select('id, name')
          .eq('trip_id', tripId) as List;
    }

    if (groupRows.isEmpty) return; // Can't assign tasks without groups

    // Build name → id map
    final groupIdByName = <String, String>{};
    for (final r in groupRows) {
      final row = r as Map<String, dynamic>;
      groupIdByName[row['name'] as String] = row['id'] as String;
    }

    // Build task rows, skipping any whose group name isn't found
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < tasks.length; i++) {
      final t       = tasks[i];
      final groupId = groupIdByName[t['group']];
      if (groupId == null) continue;
      rows.add({
        'trip_id':        tripId,
        'team_id':        teamId,
        'created_by':     userId,
        'board_group_id': groupId,
        'title':          t['title'],
        'status':         'not_started',
        'priority':       t['priority'] ?? 'medium',
        'cost_status':    'pending',
        'approval_status':'draft',
        'is_client_visible': false,
        'sort_order':     i,
      });
    }

    if (rows.isNotEmpty) {
      await _client.from('tasks').insert(rows);
    }
  }
}
