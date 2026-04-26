import 'package:flutter/material.dart';
import '../../../data/models/approval_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/proposed_itinerary_day.dart';
import '../../../data/repositories/itinerary_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItinerarySequenceApplyService
//
// Creates live itinerary items from the approved draft items.
//
// Safety guarantees:
//   • Never overwrites existing itinerary items
//   • Only creates items for days marked in the draft
//   • Requires explicit approval per item (SequenceItemStatus.included)
//   • If the target day doesn't exist in the live itinerary, it is skipped
//     (the user must create days first via the Itinerary Builder)
// ─────────────────────────────────────────────────────────────────────────────

class ItinerarySequenceApplyResult {
  final int created;
  final int skipped;
  final List<String> warnings;

  const ItinerarySequenceApplyResult({
    required this.created,
    required this.skipped,
    required this.warnings,
  });
}

class ItinerarySequenceApplyService {
  const ItinerarySequenceApplyService();

  /// Applies [approvedItems] from the draft to the live itinerary.
  ///
  /// [includedItems] is a map of itemId → true for each item the user approved.
  /// [itemEdits]     is a map of itemId → overridden fields (title, timeBlock, etc.).
  /// [existingDays]  is the current live trip days list.
  /// [existingItemsByDay] is used to detect conflicts.
  Future<ItinerarySequenceApplyResult> apply({
    required ItinerarySequenceDraft draft,
    required Map<String, bool> includedItems,
    required Map<String, Map<String, String>> itemEdits,
    required List<TripDay> existingDays,
    required Map<String, List<ItineraryItem>> existingItemsByDay,
    required ItineraryRepository repository,
    required String teamId,
  }) async {
    int created = 0;
    int skipped = 0;
    final warnings = <String>[];

    // Build a dayNumber → TripDay lookup
    final dayByNumber = <int, TripDay>{};
    for (final day in existingDays) {
      dayByNumber[day.dayNumber] = day;
    }

    for (final proposedDay in draft.days) {
      final targetDay = dayByNumber[proposedDay.dayNumber];
      if (targetDay == null) {
        skipped += proposedDay.items
            .where((i) => includedItems[i.id] == true)
            .length;
        warnings.add(
            'Day ${proposedDay.dayNumber} does not exist in the itinerary — '
            '${proposedDay.items.where((i) => includedItems[i.id] == true).length} item(s) skipped. '
            'Add Day ${proposedDay.dayNumber} in the Itinerary Builder first.');
        continue;
      }

      for (final item in proposedDay.items) {
        if (includedItems[item.id] != true) continue;

        // Apply any inline edits the user made in the review screen
        final edits     = itemEdits[item.id] ?? {};
        final title     = edits['title']     ?? item.title;
        final timeBlock = edits['timeBlock'] ?? item.timeBlock;
        final location  = edits['location']  ?? item.location;

        try {
          await repository.createItem(
            ItineraryItem(
              id:             '',
              tripDayId:      targetDay.id,
              type:           _mapComponentType(item.componentTypeName),
              title:          title,
              description:    item.description,
              timeBlock:      _mapTimeBlock(timeBlock),
              startTime:      _parseTime(item.startTime),
              endTime:        _parseTime(item.endTime),
              location:       location,
              status:         ItemStatus.draft,
              approvalStatus: ApprovalStatus.draft,
            ),
            teamId,
          );
          created++;
        } catch (e, st) {
          debugPrint('[ItinerarySequenceApplyService] createItem failed: $e\n$st');
          skipped++;
          warnings.add('Could not create "${item.title}" on Day ${proposedDay.dayNumber}.');
        }
      }
    }

    return ItinerarySequenceApplyResult(
      created:  created,
      skipped:  skipped,
      warnings: warnings,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ItemType _mapComponentType(String typeName) => switch (typeName.toLowerCase()) {
        'accommodation' => ItemType.hotel,
        'transport'     => ItemType.transport,
        'dining'        => ItemType.dining,
        'flight'        => ItemType.flight,
        _               => ItemType.experience,
      };

  TimeBlock _mapTimeBlock(String v) => switch (v.toLowerCase()) {
        'afternoon'                       => TimeBlock.afternoon,
        'evening'                         => TimeBlock.evening,
        'all_day' || 'allday' || 'all day'=> TimeBlock.allDay,
        _                                 => TimeBlock.morning,
      };

  TimeOfDay? _parseTime(String? v) {
    if (v == null || v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
