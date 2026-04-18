import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';
import '../../../data/models/run_sheet_view_mode.dart';

export '../../../data/models/run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetRoleFilter — pure-function service.
//
// Filters a List<RunSheetItem> to only what the given role should see, and
// exposes static helpers for deciding which note blocks to render per mode.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetRoleFilter {
  RunSheetRoleFilter._();

  /// Apply role-based item filtering.
  ///
  /// [responsibleUserId] — items assigned to this user are always included,
  /// even if their type falls outside the role's normal scope.
  static List<RunSheetItem> apply(
    List<RunSheetItem> items,
    RunSheetViewMode mode, {
    String? responsibleUserId,
  }) =>
      switch (mode) {
        RunSheetViewMode.director   => items,
        RunSheetViewMode.operations => items,
        RunSheetViewMode.driver     => _forDriver(items, responsibleUserId),
        RunSheetViewMode.guide      => _forGuide(items, responsibleUserId),
      };

  // ── Driver: transport + flight (+ personally assigned items) ─────────────

  static const _driverTypes = {ItemType.transport, ItemType.flight};

  static List<RunSheetItem> _forDriver(
      List<RunSheetItem> items, String? uid) =>
      items
          .where((i) =>
              _driverTypes.contains(i.type) ||
              (uid != null && uid.isNotEmpty && i.responsibleUserId == uid))
          .toList();

  // ── Guide: experience items (+ personally assigned items) ─────────────────

  static const _guideTypes = {ItemType.experience};

  static List<RunSheetItem> _forGuide(
      List<RunSheetItem> items, String? uid) =>
      items
          .where((i) =>
              _guideTypes.contains(i.type) ||
              (uid != null && uid.isNotEmpty && i.responsibleUserId == uid))
          .toList();

  // ── Note-block visibility helpers ─────────────────────────────────────────

  /// Should the opsNotes block be visible in this view mode?
  static bool showOpsNotes(RunSheetViewMode mode) =>
      mode == RunSheetViewMode.director || mode == RunSheetViewMode.operations;

  /// Should the logisticsNotes block be visible in this view mode?
  static bool showLogisticsNotes(RunSheetViewMode mode) =>
      mode != RunSheetViewMode.guide;

  /// Should the transportNotes block be visible in this view mode?
  static bool showTransportNotes(RunSheetViewMode mode) =>
      mode == RunSheetViewMode.director ||
      mode == RunSheetViewMode.driver ||
      mode == RunSheetViewMode.operations;

  /// Should the guideNotes block be visible in this view mode?
  static bool showGuideNotes(RunSheetViewMode mode) =>
      mode == RunSheetViewMode.director ||
      mode == RunSheetViewMode.guide ||
      mode == RunSheetViewMode.operations;
}
