import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/repositories/budget_repository.dart';

/// Local state for the Budget / Costing module.
///
/// Realtime strategy:
///   • Global constructor subscribes to [BudgetRepository.watchAll] for the
///     whole team — emits on any cost_item change within the team.
///   • [forTrip] constructor subscribes to [BudgetRepository.watchForTrip] —
///     emits on any cost_item change for that trip.
/// The subscription seeds initial data, replacing the old reload/_loadForTrip.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository? _repo;
  final String _teamId;

  List<CostItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  String? _tripFilter;
  CostCategory? _categoryFilter;
  PaymentStatus? _statusFilter;
  String? _currencyFilter;

  StreamSubscription<List<CostItem>>? _sub;

  BudgetProvider({
    BudgetRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _subscribeAll();
  }

  /// Creates a provider pre-scoped to a single trip.
  BudgetProvider.forTrip(
    String tripId, {
    BudgetRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _tripFilter = tripId;
    _subscribeForTrip(tripId);
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading             => _isLoading;
  String? get error              => _error;
  String? get tripFilter         => _tripFilter;
  CostCategory? get categoryFilter => _categoryFilter;
  PaymentStatus? get statusFilter  => _statusFilter;
  String? get currencyFilter     => _currencyFilter;

  bool get hasActiveFilters =>
      _categoryFilter != null || _statusFilter != null || _currencyFilter != null;

  List<CostItem> get filteredItems {
    return _items.where((item) {
      if (_tripFilter != null && item.tripId != _tripFilter) return false;
      if (_categoryFilter != null && item.category != _categoryFilter) return false;
      if (_statusFilter != null && item.paymentStatus != _statusFilter) return false;
      if (_currencyFilter != null && item.currency != _currencyFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.paymentStatus != b.paymentStatus) {
          const order = [PaymentStatus.due, PaymentStatus.pending,
                         PaymentStatus.paid, PaymentStatus.cancelled];
          return order.indexOf(a.paymentStatus)
              .compareTo(order.indexOf(b.paymentStatus));
        }
        if (a.date != null && b.date != null) return a.date!.compareTo(b.date!);
        return 0;
      });
  }

  BudgetSummary get summary => BudgetSummary.fromItems(filteredItems);

  BudgetSummary summaryForTrip(String tripId) =>
      BudgetSummary.fromItems(_items.where((i) => i.tripId == tripId).toList());

  List<String> get availableCurrencies {
    final source = _tripFilter != null
        ? _items.where((i) => i.tripId == _tripFilter)
        : _items;
    return source.map((i) => i.currency).toSet().toList()..sort();
  }

  // ── Realtime subscriptions ─────────────────────────────────────────────────

  void _subscribeAll() {
    if (_repo == null || _teamId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchAll(_teamId).listen(
      (items) {
        _items = items;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load budget items.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _subscribeForTrip(String tripId) {
    if (_repo == null) return;
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchForTrip(tripId).listen(
      (items) {
        _items = items;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load budget items.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _sub?.cancel();
    if (_tripFilter != null) {
      _subscribeForTrip(_tripFilter!);
    } else {
      _subscribeAll();
    }
  }

  // ── Filter setters ─────────────────────────────────────────────────────────

  void setTripFilter(String? tripId) {
    if (_tripFilter == tripId) return;
    _tripFilter = tripId;
    notifyListeners();
  }

  void setCategoryFilter(CostCategory? category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
  }

  void setStatusFilter(PaymentStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  void setCurrencyFilter(String? currency) {
    if (_currencyFilter == currency) return;
    _currencyFilter = currency;
    notifyListeners();
  }

  void clearFilters() {
    _categoryFilter = null;
    _statusFilter = null;
    _currencyFilter = null;
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addItem(CostItem item) async {
    if (_repo == null || _teamId.isEmpty) return;
    // Optimistic add — gives instant feedback while the DB call is in flight.
    _items.add(item);
    notifyListeners();
    try {
      final created = await _repo.create(item, _teamId);
      // Replace ghost immediately with the server-confirmed item (real UUID,
      // server-side defaults, etc.).  Do NOT wait for realtime — if the
      // subscription fires later it will overwrite _items with a fresh fetch
      // that already contains the real item, so there is no double-entry risk.
      final ghostIdx = _items.indexWhere((i) => i.id == item.id);
      if (ghostIdx != -1) {
        _items[ghostIdx] = created;
      } else if (!_items.any((i) => i.id == created.id)) {
        // Realtime beat us here and already replaced _items; make sure the
        // created item is present (in case the fetch ran before the INSERT
        // was visible to the reader).
        _items.add(created);
      }
      notifyListeners();
    } catch (_) {
      _items.removeWhere((i) => i.id == item.id);
      _error = 'Could not save cost item.';
      notifyListeners();
    }
  }

  Future<void> updateItem(CostItem updated) async {
    if (_repo == null) return;
    // Optimistic update.
    final idx = _items.indexWhere((i) => i.id == updated.id);
    if (idx != -1) {
      _items[idx] = updated;
      notifyListeners();
    }
    try {
      final confirmed = await _repo.update(updated);
      // Overwrite with server-confirmed values immediately.
      final confirmedIdx = _items.indexWhere((i) => i.id == confirmed.id);
      if (confirmedIdx != -1) {
        _items[confirmedIdx] = confirmed;
        notifyListeners();
      }
    } catch (_) {
      _error = 'Could not update cost item.';
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    if (_repo == null) return;
    // Optimistic remove — realtime confirms
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    try {
      await _repo.delete(id);
    } catch (_) {
      _error = 'Could not delete cost item.';
      notifyListeners();
    }
  }

  void updateItemApproval(String id, ApprovalStatus status) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final updated = _items[idx].copyWith(approvalStatus: status);
    updateItem(updated);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
