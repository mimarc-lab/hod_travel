import 'package:flutter/foundation.dart';
import '../../../data/models/trip_document.dart';
import '../../../data/repositories/trip_document_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DocumentsProvider
//
// State manager for all trip documents. Used by TripDocumentsScreen.
// Supports filtering by type, status, and search query.
// ─────────────────────────────────────────────────────────────────────────────

class DocumentsProvider extends ChangeNotifier {
  final String                   tripId;
  final String?                  teamId;
  final TripDocumentRepository?  repository;

  List<TripDocument> _documents   = [];
  DocumentType?      _filterType;
  DocumentStatus?    _filterStatus;
  String             _searchQuery = '';
  bool               _loading     = false;
  String?            _error;

  DocumentsProvider({
    required this.tripId,
    this.teamId,
    this.repository,
  }) {
    _load();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<TripDocument> get all       => _documents;
  DocumentType?      get filterType   => _filterType;
  DocumentStatus?    get filterStatus => _filterStatus;
  String             get searchQuery  => _searchQuery;
  bool               get loading      => _loading;
  String?            get error        => _error;

  List<TripDocument> get filtered {
    var list = _documents;
    if (_filterType != null) {
      list = list.where((d) => d.documentType == _filterType).toList();
    }
    if (_filterStatus != null) {
      list = list.where((d) => d.status == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) =>
          d.title.toLowerCase().contains(q) ||
          (d.fileName?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  Map<DocumentType, int> get countsByType {
    final map = <DocumentType, int>{};
    for (final d in _documents) {
      map[d.documentType] = (map[d.documentType] ?? 0) + 1;
    }
    return map;
  }

  int get expiringCount =>
      _documents.where((d) => d.isExpiringSoon || d.isExpired).length;

  // ── Filter setters ─────────────────────────────────────────────────────────

  void setFilterType(DocumentType? t) {
    _filterType = t;
    notifyListeners();
  }

  void setFilterStatus(DocumentStatus? s) {
    _filterStatus = s;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void clearFilters() {
    _filterType   = null;
    _filterStatus = null;
    _searchQuery  = '';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (repository == null) return;
    _loading = true;
    notifyListeners();
    try {
      _documents = await repository!.fetchForTrip(tripId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> reload() => _load();

  /// Directly seeds the documents list (used by LinkedDocumentsSection when
  /// fetching for a specific entity rather than the full trip).
  void seedDocuments(List<TripDocument> docs) {
    _documents = docs;
    _loading   = false;
    _error     = null;
    notifyListeners();
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<TripDocument?> create(TripDocument doc) async {
    if (repository == null || teamId == null) return null;
    try {
      final saved = await repository!.create(doc, teamId!);
      _documents = [saved, ..._documents];
      notifyListeners();
      return saved;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<TripDocument?> updateDoc(TripDocument doc) async {
    if (repository == null) return null;
    final prev = _documents.toList();
    _documents = [
      for (final d in _documents) d.id == doc.id ? doc : d,
    ];
    notifyListeners();
    try {
      final saved = await repository!.update(doc);
      _documents = [
        for (final d in _documents) d.id == saved.id ? saved : d,
      ];
      notifyListeners();
      return saved;
    } catch (e) {
      _documents = prev;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> archive(String id) async {
    if (repository == null) return false;
    final prev = _documents.toList();
    _documents = _documents.where((d) => d.id != id).toList();
    notifyListeners();
    try {
      await repository!.archive(id);
      return true;
    } catch (e) {
      _documents = prev;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markReviewed(TripDocument doc, String reviewedBy) async {
    final updated = doc.copyWith(
      status:     DocumentStatus.reviewed,
      reviewedAt: DateTime.now(),
      reviewedBy: reviewedBy,
    );
    return await updateDoc(updated) != null;
  }

  Future<bool> markApproved(TripDocument doc, String approvedBy) async {
    final updated = doc.copyWith(
      status:     DocumentStatus.approved,
      approvedAt: DateTime.now(),
      approvedBy: approvedBy,
    );
    return await updateDoc(updated) != null;
  }
}
