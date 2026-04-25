import 'package:flutter/foundation.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/board_group_model.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/milestone_status.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_exception.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/itinerary_repository.dart';
import '../../../data/repositories/run_sheet_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/trip_component_repository.dart';
import '../../../data/services/critical_path_engine.dart';
import '../../../data/services/exception_engine.dart';
import '../../../data/services/milestone_engine.dart';
import '../../../data/services/readiness_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripHealthProvider
//
// Loads all data for a single trip, runs all health engines, and exposes
// computed results to the Health tab UI.
// ─────────────────────────────────────────────────────────────────────────────

class TripHealthProvider extends ChangeNotifier {
  final Trip                      _trip;
  final TaskRepository?           _tasks;
  final TripComponentRepository?  _components;
  final BudgetRepository?         _budget;
  final ItineraryRepository?      _itinerary;
  final RunSheetRepository?       _runSheets;

  bool                   _isLoading  = false;
  String?                _error;
  ReadinessResult        _readiness  = ReadinessResult.zero;
  CriticalPathResult     _critPath   = CriticalPathResult.healthy;
  List<MilestoneStatus>  _milestones = const [];
  List<TripException>    _exceptions = const [];

  TripHealthProvider({
    required Trip                     trip,
    TaskRepository?          tasks,
    TripComponentRepository? components,
    BudgetRepository?        budget,
    ItineraryRepository?     itinerary,
    RunSheetRepository?      runSheets,
  })  : _trip       = trip,
        _tasks      = tasks,
        _components = components,
        _budget     = budget,
        _itinerary  = itinerary,
        _runSheets  = runSheets {
    reload();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool                  get isLoading      => _isLoading;
  String?               get error          => _error;
  ReadinessResult       get readiness      => _readiness;
  CriticalPathResult    get criticalPath   => _critPath;
  List<MilestoneStatus> get milestones     => _milestones;
  List<TripException>   get exceptions     => _exceptions;

  int get totalExceptionCount =>
      _exceptions.length;
  int get highExceptionCount =>
      _exceptions.where((e) => e.severity == TripExceptionSeverity.high).length;
  int get supplierRiskCount =>
      _exceptions.where((e) =>
          e.type == TripExceptionType.supplier ||
          (e.type == TripExceptionType.component &&
           e.severity == TripExceptionSeverity.high)).length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> reload() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _fetchTasks(),
        _fetchComponents(),
        _fetchCostItems(),
        _fetchItinerary(),
        _fetchRunSheetRows(),
      ]);

      final tasks        = results[0] as List<Task>;
      final components   = results[1] as List<TripComponent>;
      final costItems    = results[2] as List<CostItem>;
      final itin         = results[3] as _ItinData;
      final runSheetRows = results[4] as List<RunSheetRow>;

      final exceptions = ExceptionEngine.detect(
        tasks:        tasks,
        components:   components,
        costItems:    costItems,
        itemsByDayId: itin.itemsByDayId,
        runSheetRows: runSheetRows,
      );

      final milestones = MilestoneEngine.evaluate(
        tasks:        tasks,
        components:   components,
        days:         itin.days,
        itemsByDayId: itin.itemsByDayId,
        costItems:    costItems,
        runSheetRows: runSheetRows,
      );

      _critPath   = CriticalPathEngine.evaluate(tasks);
      _readiness  = ReadinessEngine.compute(
        tasks:      tasks,
        milestones: milestones,
        components: components,
        exceptions: exceptions,
      );
      _milestones = milestones;
      _exceptions = exceptions;
    } catch (e, st) {
      debugPrint('[TripHealthProvider] $e\n$st');
      _error = 'Could not compute trip health. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Private data fetchers ──────────────────────────────────────────────────

  Future<List<Task>> _fetchTasks() async {
    if (_tasks == null) return const [];
    try {
      final groups = await _tasks.fetchGroupsForTrip(_trip.id);
      return groups.expand((g) => g.tasks).toList();
    } catch (_) { return const []; }
  }

  Future<List<TripComponent>> _fetchComponents() async {
    if (_components == null) return const [];
    try { return await _components.fetchForTrip(_trip.id); }
    catch (_) { return const []; }
  }

  Future<List<CostItem>> _fetchCostItems() async {
    if (_budget == null) return const [];
    try { return await _budget.fetchForTrip(_trip.id); }
    catch (_) { return const []; }
  }

  Future<_ItinData> _fetchItinerary() async {
    if (_itinerary == null) return _ItinData(const [], const {});
    try {
      final days  = await _itinerary.fetchDaysForTrip(_trip.id);
      final items = await _itinerary.fetchItemsForTrip(_trip.id);
      return _ItinData(days, items);
    } catch (_) { return _ItinData(const [], const {}); }
  }

  Future<List<RunSheetRow>> _fetchRunSheetRows() async {
    if (_runSheets == null) return const [];
    try { return await _runSheets.fetchForTrip(_trip.id); }
    catch (_) { return const []; }
  }
}

class _ItinData {
  final List<TripDay>                      days;
  final Map<String, List<ItineraryItem>>   itemsByDayId;
  _ItinData(this.days, this.itemsByDayId);
}
