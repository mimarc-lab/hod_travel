import '../../data/models/task_model.dart';
import '../../data/repositories/enrichment_repository.dart';
import 'supplier_metrics_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierIntelligenceService
//
// Pure, stateless computation. No I/O — takes pre-fetched lists and returns
// metrics maps. Called by SupplierIntelligenceProvider after data loads.
// ─────────────────────────────────────────────────────────────────────────────

abstract class SupplierIntelligenceService {
  /// Computes metrics for every supplier that appears in [allTasks] or
  /// [allEnrichments].  Returns a map of supplierId → SupplierMetrics.
  ///
  /// Suppliers with zero tasks and zero enrichments get SupplierMetrics.empty().
  static Map<String, SupplierMetrics> computeForAll({
    required List<String> supplierIds,
    required List<Task> allTasks,
    required List<SupplierEnrichmentRecord> allEnrichments,
  }) {
    final result = <String, SupplierMetrics>{};
    for (final id in supplierIds) {
      result[id] = metricsFor(
        supplierId: id,
        allTasks: allTasks,
        allEnrichments: allEnrichments,
      );
    }
    return result;
  }

  /// Computes metrics for a single supplier.
  static SupplierMetrics metricsFor({
    required String supplierId,
    required List<Task> allTasks,
    required List<SupplierEnrichmentRecord> allEnrichments,
  }) {
    // ── Task-based metrics ─────────────────────────────────────────────────
    final tasks = allTasks.where((t) => t.supplierId == supplierId).toList();

    int confirmed     = 0;
    int awaitingReply = 0;
    int overdue       = 0;
    final tripIds     = <String>{};
    DateTime? lastUsed;
    final now         = DateTime.now();

    for (final task in tasks) {
      if (task.status == TaskStatus.confirmed)     confirmed++;
      if (task.status == TaskStatus.awaitingReply) awaitingReply++;

      // Overdue: dueDate in the past and not resolved
      if (task.dueDate != null &&
          task.dueDate!.isBefore(now) &&
          task.status != TaskStatus.confirmed &&
          task.status != TaskStatus.cancelled) {
        overdue++;
      }

      if (task.tripId != null) tripIds.add(task.tripId!);

      // Use travelDate as the "last used" proxy (most meaningful date)
      final date = task.travelDate ?? task.dueDate;
      if (date != null) {
        if (lastUsed == null || date.isAfter(lastUsed)) {
          lastUsed = date;
        }
      }
    }

    // ── Enrichment-based metrics ───────────────────────────────────────────
    final enrichments = allEnrichments
        .where((e) => e.supplierId == supplierId)
        .toList();

    DateTime? lastEnrichedAt;
    for (final e in enrichments) {
      if (lastEnrichedAt == null || e.createdAt.isAfter(lastEnrichedAt)) {
        lastEnrichedAt = e.createdAt;
      }
    }

    return SupplierMetrics(
      taskCount:          tasks.length,
      confirmedCount:     confirmed,
      awaitingReplyCount: awaitingReply,
      overdueCount:       overdue,
      tripIds:            tripIds,
      lastUsedDate:       lastUsed,
      enrichmentCount:    enrichments.length,
      lastEnrichedAt:     lastEnrichedAt,
    );
  }
}
