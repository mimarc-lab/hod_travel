import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_traveler_model.dart';
import '../../../data/models/client_questionnaire_model.dart';
import '../../../data/repositories/client_dossier_repository.dart';

class ClientDossierProvider extends ChangeNotifier {
  final ClientDossierRepository? _repo;
  final String _teamId;

  List<ClientDossier> _dossiers = [];
  bool _isLoading = false;
  String? _error;

  String _searchQuery = '';
  TripType? _typeFilter;

  StreamSubscription<List<ClientDossier>>? _sub;

  ClientDossierProvider({
    ClientDossierRepository? repository,
    required String teamId,
  })  : _repo = repository,
        _teamId = teamId {
    _subscribe();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoading                => _isLoading;
  String? get error                 => _error;
  String get searchQuery            => _searchQuery;
  TripType? get typeFilter          => _typeFilter;
  int get totalCount                => _dossiers.length;
  List<ClientDossier> get dossiers  => List.unmodifiable(_dossiers);

  bool get hasActiveFilters => _searchQuery.isNotEmpty || _typeFilter != null;

  List<ClientDossier> get filteredDossiers {
    return _dossiers.where((d) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = d.primaryClientName.toLowerCase().contains(q) ||
            (d.familyName?.toLowerCase().contains(q) ?? false) ||
            (d.homeBase?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_typeFilter != null && d.typicalTripType != _typeFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  // ── Realtime subscription ──────────────────────────────────────────────────

  void _subscribe() {
    if (_repo == null || _teamId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    _sub?.cancel();
    _sub = _repo.watchForTeam(_teamId).listen(
      (list) {
        _dossiers  = list;
        _isLoading = false;
        _error     = null;
        notifyListeners();
      },
      onError: (_) {
        _error     = 'Could not load client dossiers.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> reload() async {
    _sub?.cancel();
    _subscribe();
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  void setSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(TripType? type) {
    if (_typeFilter == type) return;
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _typeFilter  = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── CRUD — Dossiers ────────────────────────────────────────────────────────

  Future<ClientDossier?> addDossier(ClientDossier dossier) async {
    if (_repo == null || _teamId.isEmpty) return null;
    try {
      final created = await _repo.create(dossier, _teamId);
      // Realtime will refresh the list; return created for navigation
      return created;
    } catch (_) {
      _error = 'Could not save client dossier.';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateDossier(ClientDossier updated) async {
    if (_repo == null) return;
    // Optimistic update
    final idx = _dossiers.indexWhere((d) => d.id == updated.id);
    if (idx != -1) {
      _dossiers[idx] = updated;
      notifyListeners();
    }
    try {
      await _repo.update(updated);
    } catch (_) {
      _error = 'Could not update client dossier.';
      notifyListeners();
    }
  }

  Future<void> deleteDossier(String id) async {
    if (_repo == null) return;
    _dossiers.removeWhere((d) => d.id == id);
    notifyListeners();
    try {
      await _repo.delete(id);
    } catch (_) {
      _error = 'Could not delete client dossier.';
      notifyListeners();
    }
  }

  ClientDossier? findById(String id) =>
      _dossiers.where((d) => d.id == id).firstOrNull;

  // ── CRUD — Travelers ───────────────────────────────────────────────────────

  Future<ClientTraveler?> addTraveler(ClientTraveler traveler) async {
    if (_repo == null) return null;
    try {
      final created = await _repo.addTraveler(traveler);
      _refreshDossierTravelers(traveler.dossierId);
      return created;
    } catch (_) {
      _error = 'Could not add traveler.';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateTraveler(ClientTraveler traveler) async {
    if (_repo == null) return;
    try {
      await _repo.updateTraveler(traveler);
      _refreshDossierTravelers(traveler.dossierId);
    } catch (_) {
      _error = 'Could not update traveler.';
      notifyListeners();
    }
  }

  Future<void> deleteTraveler(String id, String dossierId) async {
    if (_repo == null) return;
    try {
      await _repo.deleteTraveler(id);
      _refreshDossierTravelers(dossierId);
    } catch (_) {
      _error = 'Could not delete traveler.';
      notifyListeners();
    }
  }

  void _refreshDossierTravelers(String dossierId) {
    // Realtime channel will refresh full list; trigger early reload for snappy UX
    _repo?.fetchById(dossierId).then((updated) {
      if (updated == null) return;
      final idx = _dossiers.indexWhere((d) => d.id == dossierId);
      if (idx != -1) {
        _dossiers[idx] = updated;
        notifyListeners();
      }
    });
  }

  // ── Questionnaire ──────────────────────────────────────────────────────────

  Future<ClientQuestionnaireResponse?> saveQuestionnaireResponse(
    ClientQuestionnaireResponse response,
    String dossierId,
  ) async {
    if (_repo == null) return null;
    try {
      return await _repo.saveQuestionnaireResponse(response, dossierId, _teamId);
    } catch (_) {
      _error = 'Could not save questionnaire response.';
      notifyListeners();
      return null;
    }
  }

  Future<List<ClientQuestionnaireResponse>> fetchQuestionnaireResponses(
      String dossierId) async {
    if (_repo == null) return [];
    try {
      return await _repo.fetchQuestionnaireResponses(dossierId);
    } catch (_) {
      return [];
    }
  }

  Future<ClientQuestionnaireResponse?> upsertDraft(
    ClientQuestionnaireResponse response,
    String dossierId,
  ) async {
    if (_repo == null) return null;
    try {
      return await _repo.upsertDraft(response, dossierId, _teamId);
    } catch (_) {
      _error = 'Could not save draft.';
      notifyListeners();
      return null;
    }
  }

  Future<ClientQuestionnaireResponse?> submitResponse(
    ClientQuestionnaireResponse response,
    String dossierId,
  ) async {
    if (_repo == null) return null;
    try {
      return await _repo.submitResponse(response, dossierId, _teamId);
    } catch (_) {
      _error = 'Could not submit questionnaire.';
      notifyListeners();
      return null;
    }
  }

  Future<ClientQuestionnaireResponse?> fetchLatestDraft(
      String dossierId) async {
    if (_repo == null) return null;
    try {
      return await _repo.fetchLatestDraft(dossierId);
    } catch (_) {
      return null;
    }
  }

  Future<ClientQuestionnaireResponse?> fetchResponseById(String id) async {
    if (_repo == null) return null;
    try {
      return await _repo.fetchResponseById(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> markApplied(String id) async {
    if (_repo == null) return;
    try {
      await _repo.markApplied(id);
    } catch (_) {
      _error = 'Could not mark response as applied.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
