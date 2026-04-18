import 'package:flutter/foundation.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/repositories/trip_repository.dart';

/// State manager for the Trips module.
/// Requires [teamId] to scope queries to the correct team.
class TripProvider extends ChangeNotifier {
  final TripRepository? _repo;
  final String _teamId;

  List<Trip> _trips = [];
  bool _isLoading = false;
  String? _error;

  TripProvider({
    TripRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _loadInitial();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Trip> get trips     => List.unmodifiable(_trips);
  bool get isLoading       => _isLoading;
  String? get error        => _error;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    if (_repo == null || _teamId.isEmpty) return;
    await reload();
  }

  Future<void> reload() async {
    if (_repo == null || _teamId.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _trips = await _repo.fetchAll(_teamId);
    } catch (e) {
      _error = 'Could not load trips. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<Trip?> addTrip(Trip trip) async {
    if (_repo == null) return null;
    try {
      final created = await _repo.create(trip, _teamId);
      _trips.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = 'Could not save trip. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateTrip(Trip trip) async {
    if (_repo == null) return;
    try {
      final updated = await _repo.update(trip);
      final idx = _trips.indexWhere((t) => t.id == updated.id);
      if (idx != -1) _trips[idx] = updated;
      notifyListeners();
    } catch (e) {
      _error = 'Could not update trip. Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String id) async {
    if (_repo == null) return;
    try {
      await _repo.delete(id);
      _trips.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Could not delete trip. Please try again.';
      notifyListeners();
    }
  }

  Trip? findById(String id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Upcoming trips — start date in the future, sorted by proximity.
  List<Trip> get upcomingTrips {
    final now = DateTime.now();
    return _trips
        .where((t) => t.startDate != null && t.startDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
  }

  /// Active trips — in progress or confirmed.
  List<Trip> get activeTrips => _trips
      .where((t) =>
          t.status == TripStatus.inProgress || t.status == TripStatus.confirmed)
      .toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
