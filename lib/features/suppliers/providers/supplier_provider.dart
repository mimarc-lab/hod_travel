import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/repositories/supplier_repository.dart';

/// Local state for the Supplier Database module.
///
/// Realtime strategy: subscribes to [SupplierRepository.watchForTeam] which
/// emits a refreshed list whenever any supplier in the team changes.
/// The subscription seeds initial data, replacing the old [reload] call.
class SupplierProvider extends ChangeNotifier {
  final SupplierRepository? _repo;
  final String _teamId;

  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  SupplierCategory? _categoryFilter;
  bool _preferredOnly = false;

  StreamSubscription<List<Supplier>>? _sub;

  SupplierProvider({
    SupplierRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _subscribe();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading                   => _isLoading;
  String? get error                    => _error;
  String get searchQuery               => _searchQuery;
  SupplierCategory? get categoryFilter => _categoryFilter;
  bool get preferredOnly               => _preferredOnly;
  int get totalCount                   => _suppliers.length;
  List<Supplier> get suppliers         => List.unmodifiable(_suppliers);

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _categoryFilter != null || _preferredOnly;

  List<Supplier> get filteredSuppliers {
    return _suppliers.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            (s.contactName?.toLowerCase().contains(q) ?? false) ||
            s.tags.any((t) => t.toLowerCase().contains(q));
        if (!match) return false;
      }
      if (_categoryFilter != null && s.category != _categoryFilter) return false;
      if (_preferredOnly && !s.preferred) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.preferred != b.preferred) return a.preferred ? -1 : 1;
        return a.name.compareTo(b.name);
      });
  }

  // ── Realtime subscription ──────────────────────────────────────────────────

  void _subscribe() {
    if (_repo == null || _teamId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchForTeam(_teamId).listen(
      (suppliers) {
        _suppliers = suppliers;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load suppliers.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _sub?.cancel();
    _subscribe();
  }

  // ── Filter setters ─────────────────────────────────────────────────────────

  void setSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(SupplierCategory? category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
  }

  void setPreferredOnly(bool value) {
    if (_preferredOnly == value) return;
    _preferredOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = null;
    _preferredOnly = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addSupplier(Supplier supplier) async {
    if (_repo == null || _teamId.isEmpty) return;
    // Optimistic add — realtime will replace with server-confirmed entry
    _suppliers.add(supplier);
    notifyListeners();
    try {
      await _repo.create(supplier, _teamId);
    } catch (_) {
      _suppliers.removeWhere((s) => s.id == supplier.id);
      _error = 'Could not save supplier.';
      notifyListeners();
    }
  }

  Future<void> updateSupplier(Supplier updated) async {
    if (_repo == null) return;
    // Optimistic update — realtime will confirm
    final idx = _suppliers.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _suppliers[idx] = updated;
      notifyListeners();
    }
    try {
      await _repo.update(updated);
    } catch (_) {
      _error = 'Could not update supplier.';
      notifyListeners();
    }
  }

  Future<void> deleteSupplier(String id) async {
    if (_repo == null) return;
    // Optimistic remove — realtime confirms
    _suppliers.removeWhere((s) => s.id == id);
    notifyListeners();
    try {
      await _repo.delete(id);
    } catch (_) {
      _error = 'Could not delete supplier.';
      notifyListeners();
    }
  }

  Supplier? findById(String id) {
    try {
      return _suppliers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
