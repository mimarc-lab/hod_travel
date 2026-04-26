import 'package:flutter/foundation.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_instruction_template.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/repositories/itinerary_repository.dart';
import '../../../data/repositories/run_sheet_repository.dart';
import '../services/run_sheet_mapper.dart';
import '../services/run_sheet_view_mode.dart';

export '../../../data/models/run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetFilter — UI-layer quick filter (search + status + type chips)
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetFilter {
  final RunSheetStatus? status;
  final ItemType?       type;
  final String          query;

  const RunSheetFilter({this.status, this.type, this.query = ''});

  bool get isActive => status != null || type != null || query.isNotEmpty;

  RunSheetFilter copyWith({
    RunSheetStatus? status,
    bool clearStatus = false,
    ItemType? type,
    bool clearType = false,
    String? query,
  }) =>
      RunSheetFilter(
        status: clearStatus ? null : (status ?? this.status),
        type:   clearType   ? null : (type   ?? this.type),
        query:  query ?? this.query,
      );

  bool matches(RunSheetItem item) {
    if (status != null && item.status != status) return false;
    if (type   != null && item.type   != type)   return false;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      if (!item.title.toLowerCase().contains(q) &&
          !(item.location?.toLowerCase().contains(q) ?? false) &&
          !(item.supplierName?.toLowerCase().contains(q) ?? false)) {
        return false;
      }
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetProvider
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetProvider extends ChangeNotifier {
  final String               _tripId;
  final ItineraryRepository? _itineraryRepo;
  final RunSheetRepository?  _runSheetRepo;
  final String?              _teamId;
  final RunSheetViewMode     _viewMode;
  final String?              _responsibleUserId; // for assignment-based filtering

  RunSheetProvider({
    required String tripId,
    ItineraryRepository? itineraryRepository,
    RunSheetRepository?  runSheetRepository,
    String?              teamId,
    RunSheetViewMode     viewMode = RunSheetViewMode.director,
    String?              responsibleUserId,
  })  : _tripId             = tripId,
        _itineraryRepo      = itineraryRepository,
        _runSheetRepo       = runSheetRepository,
        _teamId             = teamId,
        _viewMode           = viewMode,
        _responsibleUserId  = responsibleUserId {
    _load();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  List<TripDay>      _days     = [];
  List<RunSheetItem> _allItems = [];
  TripDay?           _selectedDay;
  RunSheetFilter     _filter   = const RunSheetFilter();
  bool               _isLoading = true;
  String?            _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool               get isLoading       => _isLoading;
  String?            get error           => _error;
  List<TripDay>      get days            => _days;
  TripDay?           get selectedDay     => _selectedDay;
  RunSheetFilter     get filter          => _filter;
  RunSheetViewMode   get viewMode        => _viewMode;
  List<RunSheetItem> get allItems        => _allItems;

  /// All items after role filtering (no day or UI filter applied yet).
  List<RunSheetItem> get roleFilteredItems => RunSheetRoleFilter.apply(
        _allItems,
        _viewMode,
        responsibleUserId: _responsibleUserId,
      );

  /// Items visible in the current list — role + day + UI filter applied.
  List<RunSheetItem> get visibleItems {
    final roleItems = roleFilteredItems;

    final dayItems = _selectedDay == null
        ? roleItems
        : roleItems.where((i) => i.dayId == _selectedDay!.id).toList();

    if (!_filter.isActive) return dayItems;
    return dayItems.where(_filter.matches).toList();
  }

  int get completedCount =>
      roleFilteredItems.where((i) => i.status == RunSheetStatus.completed).length;

  int get atRiskCount =>
      roleFilteredItems.where((i) =>
          i.status == RunSheetStatus.delayed ||
          i.status == RunSheetStatus.issueFlagged).length;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      List<TripDay> days = [];
      Map<String, List<ItineraryItem>> itemsByDay = {};
      List<RunSheetRow> rows = [];

      if (_itineraryRepo != null) {
        days       = await _itineraryRepo.fetchDaysForTrip(_tripId);
        itemsByDay = await _itineraryRepo.fetchItemsForTrip(_tripId);
        days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      }
      if (_runSheetRepo != null) {
        rows = await _runSheetRepo.fetchForTrip(_tripId);
      }

      _days     = days;
      _allItems = RunSheetMapper.mapAll(
        tripId:       _tripId,
        days:         days,
        itemsByDayId: itemsByDay,
        rows:         rows,
      );

      if (_selectedDay == null && days.isNotEmpty) {
        _selectedDay = _todayDay(days) ?? days.first;
      }
    } catch (_) {
      _error = 'Could not load run sheet.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => _load();

  // ── Day selection ──────────────────────────────────────────────────────────

  void selectDay(TripDay day) {
    _selectedDay = day;
    notifyListeners();
  }

  // ── Filter ─────────────────────────────────────────────────────────────────

  void setFilter(RunSheetFilter f) {
    _filter = f;
    notifyListeners();
  }

  void clearFilter() {
    _filter = const RunSheetFilter();
    notifyListeners();
  }

  // ── Status update ──────────────────────────────────────────────────────────

  Future<void> updateStatus(RunSheetItem item, RunSheetStatus status) async {
    // Optimistic update
    _patchLocal(item.id, status);
    notifyListeners();

    if (_runSheetRepo == null) return;

    try {
      if (item.isPersisted) {
        await _runSheetRepo.updateStatus(item.id, status);
      } else {
        // No DB record yet — insert and get back the generated id
        final row = RunSheetRow(
          id:                  '',
          tripId:              _tripId,
          dayId:               item.dayId,
          itineraryItemId:     item.itineraryItemId,
          status:              status,
          primaryContactName:  item.primaryContactName,
          primaryContactPhone: item.primaryContactPhone,
          backupContactName:   item.backupContactName,
          backupContactPhone:  item.backupContactPhone,
          responsibleName:          item.responsibleName,
          responsibleUserId:        item.responsibleUserId,
          opsNotes:                 item.opsNotes,
          logisticsNotes:           item.logisticsNotes,
          transportNotes:           item.transportNotes,
          guideNotes:               item.guideNotes,
          operationalInstructions:  item.operationalInstructions,
          contingencyInstructions:  item.contingencyInstructions,
          escalationInstructions:   item.escalationInstructions,
          instructionsSource:       item.instructionsSource,
          instructionsApprovedBy:   item.instructionsApprovedBy,
          instructionsApprovedAt:   item.instructionsApprovedAt,
        );
        final newId = await _runSheetRepo.insert(row, _teamId ?? '');
        _replaceId(item.id, newId, status);
        notifyListeners();
      }
    } catch (_) {
      // Revert
      _patchLocal(item.id, item.status);
      notifyListeners();
    }
  }

  // ── Local helpers ──────────────────────────────────────────────────────────

  void _patchLocal(String id, RunSheetStatus status) {
    _allItems = [
      for (final i in _allItems)
        if (i.id == id) i.copyWith(status: status) else i,
    ];
  }

  void _replaceId(String oldId, String newId, RunSheetStatus status) {
    _allItems = [
      for (final i in _allItems)
        if (i.id == oldId) i.copyWith(id: newId, status: status) else i,
    ];
  }

  // ── Instructions ───────────────────────────────────────────────────────────

  /// Persists operational, contingency, and escalation instructions for [item].
  /// If the item has no DB record yet, a new row is inserted first.
  Future<void> saveInstructions(
    RunSheetItem item, {
    required String?            operational,
    required String?            contingency,
    required String?            escalation,
    required InstructionsSource source,
    String?                     approvedBy,
  }) async {
    if (_runSheetRepo == null) return;

    final approvedAt = (source == InstructionsSource.suggested ||
            source == InstructionsSource.editedAfterSuggestion)
        ? DateTime.now()
        : null;

    // Optimistic local update
    final updated = item.copyWith(
      id:                      item.isPersisted ? item.id : item.id,
      operationalInstructions: operational,
      contingencyInstructions: contingency,
      escalationInstructions:  escalation,
      instructionsSource:      source,
      instructionsApprovedBy:  approvedBy,
      instructionsApprovedAt:  approvedAt,
    );
    _allItems = [
      for (final i in _allItems) if (i.id == item.id) updated else i,
    ];
    notifyListeners();

    try {
      final row = RunSheetRow(
        id:                       item.isPersisted ? item.id : '',
        tripId:                   _tripId,
        dayId:                    item.dayId,
        itineraryItemId:          item.itineraryItemId,
        status:                   item.status,
        primaryContactName:       item.primaryContactName,
        primaryContactPhone:      item.primaryContactPhone,
        backupContactName:        item.backupContactName,
        backupContactPhone:       item.backupContactPhone,
        responsibleName:          item.responsibleName,
        responsibleUserId:        item.responsibleUserId,
        opsNotes:                 item.opsNotes,
        logisticsNotes:           item.logisticsNotes,
        transportNotes:           item.transportNotes,
        guideNotes:               item.guideNotes,
        sortOrder:                item.sortOrder,
        operationalInstructions:  operational,
        contingencyInstructions:  contingency,
        escalationInstructions:   escalation,
        instructionsSource:       source,
        instructionsApprovedBy:   approvedBy,
        instructionsApprovedAt:   approvedAt,
      );
      final savedId = await _runSheetRepo.upsertRow(row, _teamId ?? '');
      if (savedId != item.id) {
        // Was synthetic — swap in the real DB id
        _allItems = [
          for (final i in _allItems)
            if (i.id == item.id) i.copyWith(id: savedId) else i,
        ];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[RunSheetProvider.saveInstructions] error: $e');
      // Revert
      _allItems = [
        for (final i in _allItems) if (i.id == updated.id) item else i,
      ];
      notifyListeners();
      rethrow;
    }
  }

  TripDay? _todayDay(List<TripDay> days) {
    final now = DateTime.now();
    for (final d in days) {
      if (d.date != null &&
          d.date!.year  == now.year  &&
          d.date!.month == now.month &&
          d.date!.day   == now.day) { return d; }
    }
    return null;
  }
}
