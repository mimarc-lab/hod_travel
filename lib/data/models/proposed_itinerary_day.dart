// ─────────────────────────────────────────────────────────────────────────────
// Proposed Itinerary Day
//
// Data models for the Assisted Itinerary Sequencing draft.
// These are pure in-memory types — not persisted separately.
// The full draft is stored as proposedPayload on an AiSuggestion record.
// ─────────────────────────────────────────────────────────────────────────────

enum SequenceItemStatus { included, removed }

// ── ProposedItinerarySummary ──────────────────────────────────────────────────

class ProposedItinerarySummary {
  final int componentsAnalyzed;
  final int componentsPlaced;
  final int unplacedCount;
  final int timingConflicts;
  final int pacingNotesCount;

  const ProposedItinerarySummary({
    this.componentsAnalyzed = 0,
    this.componentsPlaced   = 0,
    this.unplacedCount      = 0,
    this.timingConflicts    = 0,
    this.pacingNotesCount   = 0,
  });

  factory ProposedItinerarySummary.fromJson(Map<String, dynamic> j) =>
      ProposedItinerarySummary(
        componentsAnalyzed: j['components_analyzed'] as int? ?? 0,
        componentsPlaced:   j['components_placed']   as int? ?? 0,
        unplacedCount:      j['unplaced_components'] as int? ?? 0,
        timingConflicts:    j['timing_conflicts']    as int? ?? 0,
        pacingNotesCount:   j['pacing_notes_count']  as int? ?? 0,
      );
}

// ── ProposedItineraryItem ─────────────────────────────────────────────────────

class ProposedItineraryItem {
  final String id;
  final String? tripComponentId;
  final String? supplierId;
  final String  componentTypeName;
  final String  title;
  final String? description;
  final String  timeBlock;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? notes;
  final bool    isFixedTime;

  const ProposedItineraryItem({
    required this.id,
    this.tripComponentId,
    this.supplierId,
    this.componentTypeName = 'other',
    required this.title,
    this.description,
    this.timeBlock   = 'morning',
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
    this.isFixedTime = false,
  });

  factory ProposedItineraryItem.fromJson(Map<String, dynamic> j, String fallbackId) =>
      ProposedItineraryItem(
        id:                j['id']                as String? ?? fallbackId,
        tripComponentId:   j['trip_component_id'] as String?,
        supplierId:        j['supplier_id']       as String?,
        componentTypeName: j['component_type']    as String? ?? 'other',
        title:             j['title']             as String? ?? 'Untitled',
        description:       j['description']       as String?,
        timeBlock:         j['time_block']        as String? ?? 'morning',
        startTime:         j['start_time']        as String?,
        endTime:           j['end_time']          as String?,
        location:          j['location']          as String?,
        notes:             j['notes']             as String?,
        isFixedTime:       j['is_fixed_time']     as bool? ?? false,
      );

  ProposedItineraryItem copyWith({
    String? title,
    String? timeBlock,
    String? startTime,
    String? endTime,
    String? location,
    String? description,
  }) =>
      ProposedItineraryItem(
        id:                id,
        tripComponentId:   tripComponentId,
        supplierId:        supplierId,
        componentTypeName: componentTypeName,
        title:             title       ?? this.title,
        description:       description ?? this.description,
        timeBlock:         timeBlock   ?? this.timeBlock,
        startTime:         startTime   ?? this.startTime,
        endTime:           endTime     ?? this.endTime,
        location:          location    ?? this.location,
        notes:             notes,
        isFixedTime:       isFixedTime,
      );
}

// ── ProposedItineraryDay ──────────────────────────────────────────────────────

class ProposedItineraryDay {
  final int    dayNumber;
  final String? dateStr;
  final String? city;
  final String? title;
  final List<ProposedItineraryItem> items;
  final List<String> pacingNotes;
  final List<String> routingNotes;

  const ProposedItineraryDay({
    required this.dayNumber,
    this.dateStr,
    this.city,
    this.title,
    this.items       = const [],
    this.pacingNotes = const [],
    this.routingNotes= const [],
  });

  factory ProposedItineraryDay.fromJson(Map<String, dynamic> j, int dayIdx) {
    final rawItems = j['items'] as List<dynamic>? ?? [];
    return ProposedItineraryDay(
      dayNumber:  j['day_number'] as int? ?? (dayIdx + 1),
      dateStr:    j['date']       as String?,
      city:       j['city']       as String?,
      title:      j['title']      as String?,
      items: rawItems.asMap().entries
          .where((e) => e.value is Map<String, dynamic>)
          .map((e) => ProposedItineraryItem.fromJson(
                e.value as Map<String, dynamic>,
                'item_d${dayIdx}_i${e.key}',
              ))
          .toList(),
      pacingNotes:  List<String>.from(j['pacing_notes']  as List? ?? []),
      routingNotes: List<String>.from(j['routing_notes'] as List? ?? []),
    );
  }

  ProposedItineraryDay copyWithItems(List<ProposedItineraryItem> newItems) =>
      ProposedItineraryDay(
        dayNumber:  dayNumber,
        dateStr:    dateStr,
        city:       city,
        title:      title,
        items:      newItems,
        pacingNotes:  pacingNotes,
        routingNotes: routingNotes,
      );
}

// ── UnplacedComponent ─────────────────────────────────────────────────────────

class UnplacedComponent {
  final String? componentId;
  final String  title;
  final String  reason;

  const UnplacedComponent({
    this.componentId,
    required this.title,
    required this.reason,
  });

  factory UnplacedComponent.fromJson(Map<String, dynamic> j) =>
      UnplacedComponent(
        componentId: j['component_id'] as String?,
        title:       j['title']        as String? ?? 'Unknown component',
        reason:      j['reason']       as String? ?? 'Could not be placed',
      );
}

// ── ItinerarySequenceDraft ────────────────────────────────────────────────────

class ItinerarySequenceDraft {
  final ProposedItinerarySummary summary;
  final List<ProposedItineraryDay> days;
  final List<String> globalPacingNotes;
  final List<String> globalRoutingNotes;
  final List<String> missingDataWarnings;
  final List<UnplacedComponent> unplaced;

  const ItinerarySequenceDraft({
    required this.summary,
    required this.days,
    this.globalPacingNotes  = const [],
    this.globalRoutingNotes = const [],
    this.missingDataWarnings= const [],
    this.unplaced           = const [],
  });

  factory ItinerarySequenceDraft.fromPayload(Map<String, dynamic> payload) {
    final summaryJson = payload['summary']       as Map<String, dynamic>? ?? {};
    final rawDays     = payload['proposed_days'] as List<dynamic>?        ?? [];
    final rawUnplaced = payload['unplaced_components'] as List<dynamic>?  ?? [];

    return ItinerarySequenceDraft(
      summary: ProposedItinerarySummary.fromJson(summaryJson),
      days: rawDays.asMap().entries
          .where((e) => e.value is Map<String, dynamic>)
          .map((e) => ProposedItineraryDay.fromJson(
                e.value as Map<String, dynamic>, e.key))
          .toList(),
      globalPacingNotes:  List<String>.from(payload['global_pacing_notes']   as List? ?? []),
      globalRoutingNotes: List<String>.from(payload['global_routing_notes']  as List? ?? []),
      missingDataWarnings:List<String>.from(payload['missing_data_warnings'] as List? ?? []),
      unplaced: rawUnplaced
          .whereType<Map<String, dynamic>>()
          .map(UnplacedComponent.fromJson)
          .toList(),
    );
  }

  int get totalItems => days.fold(0, (s, d) => s + d.items.length);
}
