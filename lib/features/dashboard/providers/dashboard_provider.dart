import 'package:flutter/foundation.dart';
import '../../../data/models/operational_alert.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../intelligence/overdue_detector.dart';
import '../../intelligence/supplier_response_detector.dart';
import '../../intelligence/warning_priority_helper.dart';

export '../../../data/repositories/task_repository.dart' show TeamActivityItem;

/// Lightweight provider that aggregates data needed by the Dashboard.
/// Derives stats and operational alerts from trips and tasks for the team.
class DashboardProvider extends ChangeNotifier {
  final TripRepository? _trips;
  final TaskRepository? _tasks;
  final String _teamId;
  final String? _userId;

  List<Trip> _allTrips = [];
  List<Task> _myTasks  = [];
  List<OperationalAlert> _alerts = [];
  List<TeamActivityItem> _teamActivity = [];
  bool _isLoading = false;
  String? _error;

  DashboardProvider({
    TripRepository? trips,
    TaskRepository? tasks,
    required String teamId,
    String? userId,
  })  : _trips  = trips,
        _tasks  = tasks,
        _teamId = teamId,
        _userId = userId {
    if (_teamId.isNotEmpty) reload();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading  => _isLoading;
  String? get error   => _error;

  List<Trip> get allTrips => _allTrips;

  List<Trip> get activeTrips => _allTrips
      .where((t) =>
          t.status == TripStatus.inProgress || t.status == TripStatus.confirmed)
      .toList();

  List<Trip> get upcomingTrips {
    final now = DateTime.now();
    return _allTrips
        .where((t) => t.startDate != null && t.startDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  }

  /// Trips departing within the next 30 days.
  int get upcomingDepartureCount {
    final now   = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    return _allTrips.where((t) =>
        t.startDate != null &&
        t.startDate!.isAfter(now) &&
        t.startDate!.isBefore(limit)).length;
  }

  List<Task> get myTasks => _myTasks;

  /// Tasks with a due date of today assigned to the current user.
  List<Task> get tasksDueToday {
    final today = DateTime.now();
    return _myTasks.where((t) =>
        t.dueDate != null &&
        t.dueDate!.year  == today.year &&
        t.dueDate!.month == today.month &&
        t.dueDate!.day   == today.day).toList();
  }

  // ── Intelligence getters ───────────────────────────────────────────────────

  /// All operational alerts, sorted by priority.
  List<OperationalAlert> get alerts => _alerts;

  /// Trips with at least one critical or high-severity alert.
  List<Trip> get tripsAtRisk {
    final riskIds = _alerts
        .where((a) =>
            a.tripId != null &&
            (a.severity == AlertSeverity.critical ||
             a.severity == AlertSeverity.high))
        .map((a) => a.tripId!)
        .toSet();
    return _allTrips.where((t) => riskIds.contains(t.id)).toList();
  }

  List<TeamActivityItem> get teamActivity => _teamActivity;

  int get overdueAlertCount =>
      _alerts.where((a) => a.type == AlertType.overdueTask).length;

  int get supplierAlertCount =>
      _alerts.where((a) => a.type == AlertType.supplierNonResponse).length;

  /// Alert counts grouped by trip ID, for the per-trip dashboard snapshot.
  /// Only includes trips that have at least one alert.
  Map<String, List<OperationalAlert>> get alertsByTrip {
    final map = <String, List<OperationalAlert>>{};
    for (final a in _alerts) {
      if (a.tripId == null) continue;
      (map[a.tripId!] ??= []).add(a);
    }
    return map;
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> reload() async {
    if (_teamId.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (_trips != null) {
        _allTrips = await _trips.fetchAll(_teamId);
      }

      if (_tasks != null && _userId != null && _teamId.isNotEmpty) {
        _myTasks = await _tasks.fetchTasksForUser(_teamId, _userId);
      }

      if (_tasks != null && _teamId.isNotEmpty) {
        _teamActivity = await _tasks.fetchRecentActivity(_teamId);
      }

      // Compute dashboard-level intelligence from available data.
      // Uses myTasks only — full trip-level intelligence is in TripIntelligenceProvider.
      _alerts = _computeAlerts();
    } catch (_) {
      _error = 'Could not load dashboard data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OperationalAlert> _computeAlerts() {
    final activeTrips = _allTrips.where((t) =>
        t.status != TripStatus.completed &&
        t.status != TripStatus.cancelled).toList();

    // Only detectors that produce correct results with partial task data
    // (myTasks = tasks assigned to the current user, not all trip tasks).
    // MissingTaskDetector requires all trip tasks — run it in TripIntelligenceProvider.
    final raw = <OperationalAlert>[];
    for (final trip in activeTrips) {
      raw.addAll(OverdueDetector.detect(trip, _myTasks));
      raw.addAll(SupplierResponseDetector.detect(trip, _myTasks));
    }
    return WarningPriorityHelper.sort(raw);
  }
}
