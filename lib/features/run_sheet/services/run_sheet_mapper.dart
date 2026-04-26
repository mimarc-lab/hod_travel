import 'package:flutter/material.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/run_sheet_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetMapper
//
// Merges ItineraryItems (schedule source of truth) with RunSheetRows
// (execution overlay) into RunSheetItems ready for display.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetMapper {
  RunSheetMapper._();

  static List<RunSheetItem> mapAll({
    required String tripId,
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDayId,
    required List<RunSheetRow> rows,
  }) {
    final index  = _indexRows(rows);
    final result = <RunSheetItem>[];
    for (final day in days) {
      final items = _sorted(itemsByDayId[day.id] ?? []);
      for (final item in items) {
        result.add(_merge(tripId, day, item, index[item.id]));
      }
    }
    return result;
  }

  static List<RunSheetItem> mapDay({
    required String tripId,
    required TripDay day,
    required List<ItineraryItem> items,
    required List<RunSheetRow> rows,
  }) {
    final index = _indexRows(rows);
    return _sorted(items)
        .map((item) => _merge(tripId, day, item, index[item.id]))
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Map<String, RunSheetRow> _indexRows(List<RunSheetRow> rows) {
    final map = <String, RunSheetRow>{};
    for (final r in rows) {
      if (r.itineraryItemId != null) map[r.itineraryItemId!] = r;
    }
    return map;
  }

  static RunSheetItem _merge(
    String tripId,
    TripDay day,
    ItineraryItem item,
    RunSheetRow? row,
  ) =>
      RunSheetItem(
        id:                  row?.id ?? '_synth_${item.id}',
        itineraryItemId:     item.id,
        tripId:              tripId,
        dayId:               day.id,
        title:               item.title,
        type:                item.type,
        startTime:           item.startTime,
        endTime:             item.endTime,
        timeBlock:           item.timeBlock,
        location:            item.location,
        supplierId:          item.supplierId,
        supplierName:        item.supplierName,
        description:         item.description,
        status:                   row?.status              ?? RunSheetStatus.upcoming,
        primaryContactName:       row?.primaryContactName,
        primaryContactPhone:      row?.primaryContactPhone,
        backupContactName:        row?.backupContactName,
        backupContactPhone:       row?.backupContactPhone,
        responsibleName:          row?.responsibleName,
        responsibleUserId:        row?.responsibleUserId,
        opsNotes:                 row?.opsNotes ?? item.notes,
        logisticsNotes:           row?.logisticsNotes,
        transportNotes:           row?.transportNotes,
        guideNotes:               row?.guideNotes,
        sortOrder:                row?.sortOrder ?? _blockOrder(item.timeBlock),
        operationalInstructions:  row?.operationalInstructions,
        contingencyInstructions:  row?.contingencyInstructions,
        escalationInstructions:   row?.escalationInstructions,
        instructionsSource:       row?.instructionsSource,
        instructionsApprovedBy:   row?.instructionsApprovedBy,
        instructionsApprovedAt:   row?.instructionsApprovedAt,
      );

  static List<ItineraryItem> _sorted(List<ItineraryItem> items) {
    final copy = List<ItineraryItem>.from(items);
    copy.sort((a, b) {
      final am = _minutes(a.startTime);
      final bm = _minutes(b.startTime);
      if (am != null && bm != null) return am.compareTo(bm);
      if (am != null) return -1;
      if (bm != null) return 1;
      return _blockOrder(a.timeBlock).compareTo(_blockOrder(b.timeBlock));
    });
    return copy;
  }

  static int? _minutes(TimeOfDay? t) =>
      t != null ? t.hour * 60 + t.minute : null;

  static int _blockOrder(TimeBlock b) => switch (b) {
    TimeBlock.allDay    => -1,
    TimeBlock.morning   => 0,
    TimeBlock.afternoon => 1,
    TimeBlock.evening   => 2,
  };
}
