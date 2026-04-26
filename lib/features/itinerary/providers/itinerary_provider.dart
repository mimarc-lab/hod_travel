import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/itinerary_repository.dart';

/// State manager for the itinerary view of a single trip.
///
/// Realtime strategy: subscribes to [ItineraryRepository.watchForTrip] which
/// emits a full snapshot whenever trip_days or itinerary_items change.
/// The subscription seeds initial data, replacing the old _loadFromRepo call.
/// Subsequent emissions silently update state without a loading flash.
class ItineraryProvider extends ChangeNotifier {
  final Trip trip;
  final ItineraryRepository? _repo;
  final String _teamId;

  List<TripDay> _days = [];
  Map<String, List<ItineraryItem>> _itemsByDayId = {};
  int _selectedDayIndex = 0;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<ItinerarySnapshot>? _sub;

  ItineraryProvider(
    this.trip, {
    ItineraryRepository? repository,
    String? teamId,
  })  : _repo = repository,
        _teamId = teamId ?? '' {
    _subscribe();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<TripDay> get days      => _days;
  Map<String, List<ItineraryItem>> get itemsByDayId => _itemsByDayId;
  int get selectedDayIndex    => _selectedDayIndex;
  bool get isLoading          => _isLoading;
  String? get error           => _error;

  TripDay? get selectedDay =>
      _days.isNotEmpty ? _days[_selectedDayIndex] : null;

  List<ItineraryItem> itemsForDay(String dayId) =>
      _itemsByDayId[dayId] ?? const [];

  // ── Realtime subscription ──────────────────────────────────────────────────

  /// Resolves the team ID to use, preferring the trip's own teamId, then the
  /// provider's stored _teamId, then the live AppRepositories value (which may
  /// have been set after this provider was constructed).
  String get _effectiveTeamId =>
      trip.teamId?.isNotEmpty == true
          ? trip.teamId!
          : _teamId.isNotEmpty
              ? _teamId
              : AppRepositories.instance?.currentTeamId ?? '';

  void _subscribe() {
    if (_repo == null) return;
    final effectiveTeamId = _effectiveTeamId;
    if (effectiveTeamId.isEmpty) {
      debugPrint('[ItineraryProvider] teamId missing — cannot subscribe.');
      _error = 'Team context is missing. Please close and reopen this trip.';
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchForTrip(trip.id, effectiveTeamId).listen(
      (snapshot) {
        final prevDayId = selectedDay?.id;
        _days = snapshot.days;
        _itemsByDayId = {
          for (final e in snapshot.items.entries) e.key: List.of(e.value),
        };
        // Restore selected day by ID if it still exists, else clamp
        if (prevDayId != null) {
          final idx = _days.indexWhere((d) => d.id == prevDayId);
          _selectedDayIndex = idx != -1 ? idx : 0;
        } else {
          _selectedDayIndex = 0;
        }
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load itinerary.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _sub?.cancel();
    _subscribe();
  }

  // ── Day selection ──────────────────────────────────────────────────────────

  void selectDay(int index) {
    if (index == _selectedDayIndex) return;
    _selectedDayIndex = index.clamp(0, _days.length - 1);
    notifyListeners();
  }

  // ── Day CRUD ───────────────────────────────────────────────────────────────

  /// Appends a new day after the last existing day.
  Future<void> addDay({
    required String city,
    DateTime? date,
    String? label,
  }) async {
    if (_repo == null) return;
    final effectiveTeamId = _effectiveTeamId;
    if (effectiveTeamId.isEmpty) {
      debugPrint('[ItineraryProvider.addDay] BAIL: teamId empty');
      _error = 'Could not save day — team context is missing. Please close and reopen this trip.';
      notifyListeners();
      return;
    }

    final nextNumber = _days.isEmpty
        ? 1
        : _days.map((d) => d.dayNumber).reduce(max) + 1;
    try {
      final saved = await _repo.createDay(
        TripDay(
          id:        '',
          tripId:    trip.id,
          teamId:    effectiveTeamId,
          dayNumber: nextNumber,
          date:      date,
          city:      city,
          label:     label,
        ),
        effectiveTeamId,
      );
      // Add the confirmed day directly so it appears even if realtime is slow
      // or fires before the INSERT is visible to the next SELECT.
      if (!_days.any((d) => d.id == saved.id)) {
        _days = [..._days, saved];
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[ItineraryProvider.addDay] error: $e\n$st');
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> upsertDay(TripDay day) async {
    if (_repo == null) return;
    final effectiveTeamId = _effectiveTeamId;
    if (effectiveTeamId.isEmpty) {
      _error = 'Team context is missing — cannot save day.';
      notifyListeners();
      throw Exception(_error);
    }
    // Optimistic update so the UI reflects the change immediately.
    final prevDays = List<TripDay>.from(_days);
    final idx = _days.indexWhere((d) => d.id == day.id);
    if (idx != -1) {
      _days[idx] = day;
      notifyListeners();
    }
    try {
      final saved = await _repo.upsertDay(day, effectiveTeamId);
      // Replace with the DB-confirmed version.
      final newIdx = _days.indexWhere((d) => d.id == saved.id);
      if (newIdx != -1) {
        _days[newIdx] = saved;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[ItineraryProvider.upsertDay] error: $e\n$st');
      _days = prevDays; // Rollback
      _error = 'Could not save day: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ── Item CRUD ──────────────────────────────────────────────────────────────

  Future<void> addItem(ItineraryItem item) async {
    if (_repo == null) {
      debugPrint('[addItem] BAIL: repo is null');
      throw Exception('Repository not available.');
    }
    final effectiveTeamId = _effectiveTeamId;
    debugPrint('[addItem] teamId=$effectiveTeamId dayId=${item.tripDayId} type=${item.type.dbValue}');
    if (effectiveTeamId.isEmpty) {
      debugPrint('[addItem] BAIL: teamId empty');
      const msg = 'Team context is missing — cannot save item. Please close and reopen this trip.';
      _error = msg;
      notifyListeners();
      throw Exception(msg);
    }
    // Optimistic add — item appears immediately without waiting for realtime.
    _itemsByDayId.putIfAbsent(item.tripDayId, () => []).add(item);
    notifyListeners();
    try {
      final saved = await _repo.createItem(item, effectiveTeamId);
      debugPrint('[addItem] saved id=${saved.id}');
      // After the await, _itemsByDayId may have been replaced by a realtime
      // snapshot. Always work on the CURRENT list for this day.
      final currentList =
          _itemsByDayId.putIfAbsent(saved.tripDayId, () => []);
      if (currentList.any((i) => i.id == saved.id)) {
        // Realtime already added the confirmed item — remove the temp placeholder.
        currentList.removeWhere((i) => i.id == item.id);
      } else {
        // Replace the temp placeholder with the real item, or just add it.
        final idx = currentList.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          currentList[idx] = saved;
        } else {
          currentList.add(saved);
        }
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('[addItem] ERROR: $e\n$st');
      // Rollback the optimistic entry.
      _itemsByDayId[item.tripDayId]?.removeWhere((i) => i.id == item.id);
      _error = e.toString();
      notifyListeners();
      rethrow; // Let the editor catch and display the error directly.
    }
  }

  Future<void> updateItem(ItineraryItem updated) async {
    final list = _itemsByDayId[updated.tripDayId];
    if (list == null) return;
    final idx = list.indexWhere((i) => i.id == updated.id);
    if (idx == -1) return;
    final prev = list[idx];
    list[idx] = updated;
    notifyListeners();
    if (_repo != null) {
      try {
        await _repo.updateItem(updated);
        // Realtime confirms; optimistic state remains until then.
      } catch (e, st) {
        debugPrint('[ItineraryProvider.updateItem] error: $e\n$st');
        list[idx] = prev; // Rollback
        _error = e.toString();
        notifyListeners();
        rethrow; // Let the editor catch and display the error directly.
      }
    }
  }

  Future<void> deleteDay(String dayId) async {
    if (_repo == null) return;
    final idx = _days.indexWhere((d) => d.id == dayId);
    if (idx == -1) return;
    final removedDay = _days[idx];
    final removedItems = _itemsByDayId[dayId];
    _days = [..._days]..removeAt(idx);
    _itemsByDayId.remove(dayId);
    _selectedDayIndex = _selectedDayIndex.clamp(0, (_days.length - 1).clamp(0, double.maxFinite.toInt()));
    notifyListeners();
    try {
      await _repo.deleteDay(dayId);
    } catch (e) {
      // Rollback
      _days = [..._days]..insert(idx, removedDay);
      if (removedItems != null) _itemsByDayId[dayId] = removedItems;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteItem(String dayId, String itemId) async {
    final list = _itemsByDayId[dayId];
    if (list == null) return;
    final idx = list.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final removed = list.removeAt(idx);
    notifyListeners();
    if (_repo != null) {
      try {
        await _repo.deleteItem(itemId);
      } catch (_) {
        list.insert(idx, removed);
        notifyListeners();
      }
    }
  }

  /// Called after the user drags a card to a new position within a block.
  ///
  /// [newBlockOrder] is the block's items in the new display order (already
  /// adjusted by the caller). Rebuilds the full-day list (other blocks
  /// unchanged) and persists `sort_order` to the DB so the order survives
  /// navigation away and realtime reloads.
  Future<void> reorderBlock({
    required String dayId,
    required TimeBlock block,
    required List<ItineraryItem> newBlockOrder,
  }) async {
    final allItems = _itemsByDayId[dayId];
    if (allItems == null) return;

    // Rebuild the full day list: keep block ordering from other blocks intact,
    // replace this block's slice with newBlockOrder.
    final rebuilt = <ItineraryItem>[
      for (final b in TimeBlock.values)
        if (b == block)
          ...newBlockOrder
        else
          ...allItems.where((i) => i.timeBlock == b),
    ];
    _itemsByDayId[dayId] = rebuilt;
    notifyListeners();

    // Persist sort_order for ALL items in the day so the unique constraint
    // (trip_day_id, sort_order) is never violated across blocks.
    if (_repo != null) {
      try {
        await _repo.updateSortOrders(rebuilt);
      } catch (e) {
        debugPrint('[ItineraryProvider.reorderBlock] sort persist error: $e');
        // Non-fatal: the in-memory order is already correct; next realtime
        // emission will restore the last saved DB order.
      }
    }
  }

  String generateItemId() => 'item_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
