import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/board_group_model.dart';
import '../../data/models/cost_item_model.dart';
import '../../data/models/itinerary_models.dart';
import '../../data/models/task_model.dart';
import '../../data/models/operational_alert.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/trip_readiness.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/itinerary_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/services/intelligence_notification_bridge.dart';
import 'budget_gap_detector.dart';
import 'itinerary_gap_detector.dart';
import 'missing_task_detector.dart';
import 'next_action/next_action_model.dart';
import 'next_action/next_action_rule_engine.dart';
import 'overdue_detector.dart';
import 'readiness_service.dart';
import 'supplier_response_detector.dart';
import 'trip_health/trip_health_model.dart';
import 'trip_health/trip_health_rule_engine.dart';
import 'warning_priority_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripIntelligenceProvider
//
// Computes full operational intelligence for a single trip.
// Used by the Intelligence tab inside TripBoardScreen.
//
// Data loaded:
//   - All tasks (via board groups, includes all statuses/assignees)
//   - Itinerary days + items
//   - Cost items
// ─────────────────────────────────────────────────────────────────────────────

class TripIntelligenceProvider extends ChangeNotifier {
  final Trip _trip;
  final TaskRepository? _tasks;
  final ItineraryRepository? _itinerary;
  final BudgetRepository? _budget;
  final NotificationRepository? _notifications;
  final TeamRepository? _teams;
  final AppRole? _currentUserRole;

  List<OperationalAlert> _alerts   = [];
  TripReadiness _readiness         = TripReadiness.empty;
  TripHealth? _health;
  List<NextAction> _nextActions    = [];
  bool _isLoading                  = false;
  String? _error;

  // ── Cached trip context for AI suggestions ─────────────────────────────────
  List<Task> _cachedTasks               = [];
  List<TripDay> _cachedDays             = [];
  Map<String, List<ItineraryItem>> _cachedItemsByDay = {};

  TripIntelligenceProvider({
    required Trip trip,
    required TaskRepository? tasks,
    required ItineraryRepository? itinerary,
    required BudgetRepository? budget,
    NotificationRepository? notifications,
    TeamRepository? teams,
    AppRole? currentUserRole,
  })  : _trip            = trip,
        _tasks           = tasks,
        _itinerary       = itinerary,
        _budget          = budget,
        _notifications   = notifications,
        _teams           = teams,
        _currentUserRole = currentUserRole {
    reload();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading                   => _isLoading;
  String? get error                    => _error;
  TripReadiness get readiness          => _readiness;
  TripHealth? get health               => _health;
  List<NextAction> get nextActions     => _nextActions;
  List<OperationalAlert> get alerts    => _alerts;
  int get alertCount                   => _alerts.length;

  // Trip context cache (available after first load)
  List<Task> get cachedTasks                       => List.unmodifiable(_cachedTasks);
  List<TripDay> get cachedDays                     => List.unmodifiable(_cachedDays);
  Map<String, List<ItineraryItem>> get cachedItemsByDay => Map.unmodifiable(_cachedItemsByDay);

  List<OperationalAlert> get criticalAndHigh => _alerts
      .where((a) =>
          a.severity == AlertSeverity.critical ||
          a.severity == AlertSeverity.high)
      .toList();

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> reload() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      // All tasks for this trip (fetched through board groups).
      final groups = _tasks != null
          ? await _tasks.fetchGroupsForTrip(_trip.id)
          : <BoardGroup>[];
      final tasks = groups.expand((g) => g.tasks).toList();

      final days = _itinerary != null
          ? await _itinerary.fetchDaysForTrip(_trip.id)
          : <TripDay>[];
      final itemsByDayId = _itinerary != null
          ? await _itinerary.fetchItemsForTrip(_trip.id)
          : <String, List<ItineraryItem>>{};

      final costItems = _budget != null
          ? await _budget.fetchForTrip(_trip.id)
          : <CostItem>[];

      // Cache for AI suggestions context
      _cachedTasks      = tasks;
      _cachedDays       = days;
      _cachedItemsByDay = itemsByDayId;

      // Run detectors — MissingTaskDetector runs exactly once.
      final missingAlerts = MissingTaskDetector.detect(_trip, tasks);

      final raw = <OperationalAlert>[
        ...OverdueDetector.detect(_trip, tasks),
        ...missingAlerts,
        ...SupplierResponseDetector.detect(_trip, tasks),
        ...ItineraryGapDetector.detect(_trip, days, itemsByDayId),
        ...BudgetGapDetector.detect(_trip, tasks, costItems),
      ];

      _alerts = WarningPriorityHelper.sort(raw, tripStartDate: _trip.startDate);

      // Bridge alerts to the notification system (fire-and-forget).
      // Severity filtering and dedup are handled inside the bridge.
      final teamId = _trip.teamId;
      if (_alerts.isNotEmpty && teamId != null &&
          _notifications != null && _teams != null) {
        unawaited(IntelligenceNotificationBridge.bridge(
          alerts:        _alerts,
          tripId:        _trip.id,
          teamId:        teamId,
          notifications: _notifications,
          teams:         _teams,
        ));
      }

      // Pass missing count directly — avoids re-running the detector.
      _readiness = ReadinessService.compute(
        trip:             _trip,
        tasks:            tasks,
        days:             days,
        itemsByDayId:     itemsByDayId,
        costItems:        costItems,
        missingTaskCount: missingAlerts.length,
      );

      // Compute health score and next best actions from alerts + readiness.
      _health = TripHealthRuleEngine.compute(
        trip:      _trip,
        alerts:    _alerts,
        readiness: _readiness,
      );
      _nextActions = NextActionRuleEngine.compute(
        alerts: _alerts,
        role:   _currentUserRole,
      );
    } catch (_) {
      _error = 'Could not compute trip intelligence.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
