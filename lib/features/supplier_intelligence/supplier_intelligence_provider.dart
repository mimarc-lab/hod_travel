import 'package:flutter/foundation.dart';

import '../../core/supabase/app_db.dart';
import '../../data/models/supplier_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/enrichment_repository.dart';
import 'supplier_intelligence_service.dart';
import 'supplier_metrics_model.dart';
import 'supplier_reliability_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierIntelligenceProvider
//
// Loads all team tasks + enrichments once, then computes metrics for every
// supplier in the provided list. Designed to be created once per session
// (e.g. in SuppliersScreen) and passed down to detail screens.
// ─────────────────────────────────────────────────────────────────────────────

enum IntelligenceLoadState { idle, loading, loaded, error }

class SupplierIntelligenceProvider extends ChangeNotifier {
  final String teamId;

  SupplierIntelligenceProvider({required this.teamId});

  // ── State ──────────────────────────────────────────────────────────────────
  IntelligenceLoadState _state = IntelligenceLoadState.idle;
  IntelligenceLoadState get state => _state;
  bool get isLoaded => _state == IntelligenceLoadState.loaded;

  List<Task> _allTasks = const [];
  List<SupplierEnrichmentRecord> _allEnrichments = const [];

  /// supplierId → computed metrics
  Map<String, SupplierMetrics> _metricsMap = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns metrics for [supplierId], or empty metrics if not yet computed.
  SupplierMetrics metricsFor(String supplierId) =>
      _metricsMap[supplierId] ?? SupplierMetrics.empty();

  /// Derived reliability tier — convenience shorthand.
  ReliabilityTier tierFor(Supplier supplier) =>
      SupplierReliabilityEngine.compute(supplier, metricsFor(supplier.id));

  /// All enrichment records for a specific supplier, sorted newest first.
  List<SupplierEnrichmentRecord> enrichmentsFor(String supplierId) =>
      _allEnrichments
          .where((e) => e.supplierId == supplierId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Loads or reloads data for a specific list of [suppliers].
  Future<void> load(List<Supplier> suppliers) async {
    if (_state == IntelligenceLoadState.loading) return;
    _state = IntelligenceLoadState.loading;
    notifyListeners();

    try {
      final repos = AppRepositories.instance;
      final results = await Future.wait([
        repos?.tasks.fetchAllForTeam(teamId) ?? Future.value(<Task>[]),
        repos?.enrichments.fetchForTeam(teamId) ??
            Future.value(<SupplierEnrichmentRecord>[]),
      ]);

      _allTasks       = results[0] as List<Task>;
      _allEnrichments = results[1] as List<SupplierEnrichmentRecord>;

      _metricsMap = SupplierIntelligenceService.computeForAll(
        supplierIds:    suppliers.map((s) => s.id).toList(),
        allTasks:       _allTasks,
        allEnrichments: _allEnrichments,
      );

      _state = IntelligenceLoadState.loaded;
    } catch (e) {
      debugPrint('[SupplierIntelligenceProvider] load error: $e');
      _state = IntelligenceLoadState.error;
    }

    notifyListeners();
  }

  /// Recomputes metrics when the supplier list changes without re-fetching
  /// from the network (e.g. after a supplier is added to the in-memory list).
  void recompute(List<Supplier> suppliers) {
    if (_state != IntelligenceLoadState.loaded) return;
    _metricsMap = SupplierIntelligenceService.computeForAll(
      supplierIds:    suppliers.map((s) => s.id).toList(),
      allTasks:       _allTasks,
      allEnrichments: _allEnrichments,
    );
    notifyListeners();
  }
}
