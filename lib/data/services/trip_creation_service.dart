import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import 'trip_templates.dart';
import '../../features/workflow_scheduling/backward_planning_service.dart';
import '../../features/workflow_scheduling/planning_deadline_helper.dart';
import '../models/scheduled_task_result.dart';

// =============================================================================
// TripCreationService
//
// Orchestrates the multi-step trip creation flow:
//   1. Insert the trips row
//   2. Insert trip_destinations rows (city names, ordered)
//   3. Default board_groups are created automatically by the DB trigger
//   4. If a template is selected:
//      a. Run the backward planning engine to compute task dates
//      b. Fetch board groups and insert scheduled template tasks
//
// Returns the fully created Trip plus the ScheduleAnalysis (for UI warnings).
// =============================================================================

class TripCreationResult {
  final Trip trip;
  final ScheduleAnalysis? scheduleAnalysis;

  const TripCreationResult({required this.trip, this.scheduleAnalysis});
}

class TripCreationService {
  final TripRepository _trips;
  final SupabaseClient _client;

  TripCreationService(this._trips, this._client);

  Future<TripCreationResult> createTrip({
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

    // 3. Seed template tasks with backward-planned dates
    final tasks = templateTasks(templateId);
    ScheduleAnalysis? analysis;

    if (tasks.isNotEmpty) {
      // Compute schedule if trip has a start date
      if (created.startDate != null) {
        analysis = BackwardPlanningService.scheduleFromTemplateMaps(
          templateTasks:      tasks,
          tripStartDate:      created.startDate!,
          planningBufferDays: created.planningBufferDays,
        );
        await _insertScheduledTasks(
          tripId:   created.id,
          teamId:   teamId,
          userId:   _client.auth.currentUser?.id ?? '',
          analysis: analysis,
        );
      } else {
        // No start date — insert tasks without dates (legacy behaviour)
        await _insertTemplateTasks(
          tripId: created.id,
          teamId: teamId,
          userId: _client.auth.currentUser?.id ?? '',
          tasks:  tasks,
        );
      }
    }

    return TripCreationResult(trip: created, scheduleAnalysis: analysis);
  }

  // ── Scheduled insertion (with computed dates) ─────────────────────────────

  Future<void> _insertScheduledTasks({
    required String tripId,
    required String teamId,
    required String userId,
    required ScheduleAnalysis analysis,
  }) async {
    final groupRows = await _fetchGroupRows(tripId);
    if (groupRows.isEmpty) return;

    final groupIdByName = {
      for (final r in groupRows)
        (r as Map<String, dynamic>)['name'] as String:
            r['id'] as String,
    };

    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < analysis.tasks.length; i++) {
      final t       = analysis.tasks[i];
      final groupId = groupIdByName[t.groupName];
      if (groupId == null) continue;

      rows.add({
        'trip_id':                 tripId,
        'team_id':                 teamId,
        'created_by':              userId,
        'board_group_id':          groupId,
        'title':                   t.title,
        'status':                  'not_started',
        'priority':                t.priority,
        'cost_status':             'pending',
        'approval_status':         'draft',
        'is_client_visible':       false,
        'sort_order':              i,
        // Backward-planned dates:
        // travelDate is repurposed as scheduled_start_date for the timeline.
        'travel_date':             _dateStr(t.scheduledStartDate),
        'due_date':                _dateStr(t.dueDate),
        'estimated_duration_days': t.estimatedDurationDays,
      });
    }

    if (rows.isNotEmpty) {
      await _client.from('tasks').insert(rows);
    }
  }

  // ── Unscheduled insertion (no start date on trip) ─────────────────────────

  Future<void> _insertTemplateTasks({
    required String tripId,
    required String teamId,
    required String userId,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final groupRows = await _fetchGroupRows(tripId);
    if (groupRows.isEmpty) return;

    final groupIdByName = {
      for (final r in groupRows)
        (r as Map<String, dynamic>)['name'] as String:
            r['id'] as String,
    };

    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < tasks.length; i++) {
      final t       = tasks[i];
      final groupId = groupIdByName[t['group'] as String? ?? ''];
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> _fetchGroupRows(String tripId) async {
    var rows = await _client
        .from('board_groups')
        .select('id, name')
        .eq('trip_id', tripId) as List;

    if (rows.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      rows = await _client
          .from('board_groups')
          .select('id, name')
          .eq('trip_id', tripId) as List;
    }
    return rows;
  }

  static String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);
}

// ── Recalculation helper ──────────────────────────────────────────────────────
// Call this when a trip's start date changes. Returns a new ScheduleAnalysis
// that can be used to update task dates after user confirmation.

class ScheduleRecalculator {
  static ScheduleAnalysis recalculate({
    required Trip trip,
    required List<Map<String, dynamic>> templateTaskMaps,
  }) {
    if (trip.startDate == null) {
      return ScheduleAnalysis(
        tasks:            [],
        planningStart:    PlanningDeadlineHelper.planningStart(),
        planningDeadline: PlanningDeadlineHelper.planningStart(),
        isPossible:       false,
        isCompressed:     false,
        availableDays:    0,
        requiredDays:     0,
        warnings:         ['Trip has no start date — cannot recalculate schedule.'],
      );
    }

    return BackwardPlanningService.scheduleFromTemplateMaps(
      templateTasks:      templateTaskMaps,
      tripStartDate:      trip.startDate!,
      planningBufferDays: trip.planningBufferDays,
    );
  }
}
