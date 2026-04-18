import 'package:flutter/material.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/signature_experience.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';

// ── TripContext ───────────────────────────────────────────────────────────────

/// Bundles all trip-related data needed for AI prompt building.
class TripContext {
  final Trip trip;
  final List<TripDay> days;

  /// Items keyed by tripDayId.
  final Map<String, List<ItineraryItem>> itemsByDay;

  final List<Task> tasks;
  final List<Supplier> suppliers;
  final List<SignatureExperience> signatureExperiences;

  const TripContext({
    required this.trip,
    required this.days,
    required this.itemsByDay,
    required this.tasks,
    required this.suppliers,
    required this.signatureExperiences,
  });

  // ── Computed ───────────────────────────────────────────────────────────────

  int get totalItemCount =>
      itemsByDay.values.fold(0, (sum, items) => sum + items.length);

  List<TripDay> get emptyDays =>
      days.where((d) => (itemsByDay[d.id] ?? []).isEmpty).toList();

  int? get tripDurationDays {
    final s = trip.startDate;
    final e = trip.endDate;
    if (s == null || e == null) return null;
    return e.difference(s).inDays + 1;
  }
}

// ── AiContextBuilder ──────────────────────────────────────────────────────────

/// Converts a [TripContext] into a structured, high-signal prompt block.
///
/// Section order (most signal → least):
///   1. Design Brief       — audience profile, trip type, duration, priorities
///   2. Trip Details       — dates, destinations, guest count, status
///   3. Itinerary Gaps     — empty days, missing categories (highest AI priority)
///   4. Day Structure      — full day-by-day breakdown
///   5. Signature Library  — DreamMaker Signature Experiences (audience-matched)
///   6. Suppliers          — destination-filtered, preferred first
///   7. Open Tasks         — unresolved operational items
class AiContextBuilder {
  const AiContextBuilder();

  String build(TripContext ctx) {
    final buf = StringBuffer();
    _writeDesignBrief(buf, ctx);
    _writeTripMeta(buf, ctx.trip);
    _writeCategoryGaps(buf, ctx);
    _writeDayStructure(buf, ctx);
    _writeSignatureExperiences(buf, ctx);
    _writeSuppliers(buf, ctx.suppliers, ctx.trip.destinations);
    _writeTasks(buf, ctx.tasks);
    return buf.toString();
  }

  // ── 1. Design Brief ────────────────────────────────────────────────────────

  /// High-signal summary the AI reads first — audience, trip type, priorities.
  void _writeDesignBrief(StringBuffer buf, TripContext ctx) {
    final trip        = ctx.trip;
    final audience    = _inferAudienceProfile(trip);
    final tripType    = _inferTripType(trip);
    final durationStr = ctx.tripDurationDays != null
        ? '${ctx.tripDurationDays} days'
        : 'Duration unspecified';

    buf.writeln('## DESIGN BRIEF');
    buf.writeln('Audience Profile: $audience');
    buf.writeln('Trip Type: $tripType');
    buf.writeln('Duration: $durationStr');
    buf.writeln('Destinations: ${trip.destinations.join(' → ')}');
    buf.writeln('Group Size: ${trip.guestCount} guest(s)');
    buf.writeln();

    final priorities = _inferDesignPriorities(ctx, audience, tripType);
    if (priorities.isNotEmpty) {
      buf.writeln('Design Priorities:');
      for (final p in priorities) {
        buf.writeln('  • $p');
      }
      buf.writeln();
    }
  }

  // ── 2. Trip Metadata ───────────────────────────────────────────────────────

  void _writeTripMeta(StringBuffer buf, Trip trip) {
    buf.writeln('## TRIP DETAILS');
    buf.writeln('Name: ${trip.name}');
    buf.writeln('Client: ${trip.clientName}');
    buf.writeln('Status: ${trip.status.label}');
    if (trip.startDate != null) buf.writeln('Start: ${_fmtDate(trip.startDate!)}');
    if (trip.endDate   != null) buf.writeln('End:   ${_fmtDate(trip.endDate!)}');
    if (trip.notes != null && trip.notes!.isNotEmpty) {
      buf.writeln('Notes: ${trip.notes}');
    }
    buf.writeln();
  }

  // ── 3. Category Gaps ──────────────────────────────────────────────────────

  /// Explicitly surfaces structural gaps — these are the AI's highest-priority targets.
  void _writeCategoryGaps(StringBuffer buf, TripContext ctx) {
    final allItems = ctx.itemsByDay.values.expand((i) => i).toList();
    final types    = allItems.map((i) => i.type).toSet();

    final gaps = <String>[];

    if (!types.contains(ItemType.hotel)) {
      gaps.add('No accommodation items in itinerary');
    }
    if (!types.contains(ItemType.dining)) {
      gaps.add('No dining experiences scheduled');
    }
    if (!types.contains(ItemType.transport) && !types.contains(ItemType.flight)) {
      gaps.add('No transfers or transport arranged');
    }
    if (!types.contains(ItemType.experience)) {
      gaps.add('No curated or signature experiences added');
    }
    if (ctx.emptyDays.isNotEmpty) {
      final dayNums = ctx.emptyDays.map((d) => 'Day ${d.dayNumber}').join(', ');
      gaps.add(
          '${ctx.emptyDays.length} day(s) with nothing scheduled — '
          'top priority for new content: $dayNums');
    }

    if (gaps.isEmpty) {
      buf.writeln('## ITINERARY GAPS\n[No major structural gaps detected]\n');
    } else {
      buf.writeln(
          '## ITINERARY GAPS  ← Priority targets for AI suggestions');
      for (final g in gaps) {
        buf.writeln('  ⚠ $g');
      }
      buf.writeln();
    }
  }

  // ── 4. Day Structure ──────────────────────────────────────────────────────

  void _writeDayStructure(StringBuffer buf, TripContext ctx) {
    buf.writeln('## ITINERARY  (${ctx.days.length} days, '
        '${ctx.totalItemCount} items total)');

    for (final day in ctx.days) {
      final items   = ctx.itemsByDay[day.id] ?? [];
      final dateStr = day.date != null ? ' (${_fmtDate(day.date!)})' : '';
      final titleStr = day.title != null ? ': ${day.title}' : '';
      buf.writeln('Day ${day.dayNumber}$dateStr — ${day.city}$titleStr');

      if (items.isEmpty) {
        buf.writeln('  [EMPTY — nothing scheduled]');
      } else {
        final blocks = <TimeBlock, List<ItineraryItem>>{};
        for (final item in items) {
          blocks.putIfAbsent(item.timeBlock, () => []).add(item);
        }
        for (final block in TimeBlock.values) {
          final blockItems = blocks[block];
          if (blockItems == null || blockItems.isEmpty) continue;
          buf.writeln('  ${block.label}:');
          for (final item in blockItems) {
            final timeStr = item.startTime != null
                ? ' [${_fmtTime(item.startTime!)}]'
                : '';
            buf.writeln(
                '    - [${item.type.label}]$timeStr ${item.title}'
                '${item.location != null ? ' @ ${item.location}' : ''}');
          }
        }
      }
    }
    buf.writeln();
  }

  // ── 5. Signature Experience Library ───────────────────────────────────────

  /// DreamMaker Signature Experiences — audience-sorted, flagship first.
  /// The AI is instructed to prioritise these over generic third-party alternatives.
  void _writeSignatureExperiences(StringBuffer buf, TripContext ctx) {
    final active = ctx.signatureExperiences
        .where((e) =>
            e.status == ExperienceStatus.approved ||
            e.status == ExperienceStatus.flagship)
        .toList()
      ..sort((a, b) {
        // Flagships surface first
        final af = a.status == ExperienceStatus.flagship ? 0 : 1;
        final bf = b.status == ExperienceStatus.flagship ? 0 : 1;
        return af.compareTo(bf);
      });

    if (active.isEmpty) {
      buf.writeln('## DREAMMAKER SIGNATURE EXPERIENCES\n[Library empty]\n');
      return;
    }

    buf.writeln(
        '## DREAMMAKER SIGNATURE EXPERIENCES  (${active.length} available)');
    buf.writeln(
        'Instruction: When audience and destination match, ALWAYS prefer these'
        ' over generic third-party suggestions. Use source_type = "dreammaker_signature".');
    buf.writeln();

    for (final e in active.take(12)) {
      final flagship  = e.status == ExperienceStatus.flagship ? ' [FLAGSHIP]' : '';
      final audience  = e.audienceSuitability.isNotEmpty
          ? ' | Audience: ${e.audienceSuitability.join(', ')}'
          : '';
      final size      = (e.idealGroupSizeMin != null || e.idealGroupSizeMax != null)
          ? ' | ${e.groupSizeLabel}'
          : '';
      final flex      = ' | ${e.destinationFlexibility.label}';

      buf.writeln('  ◆ ${e.title}$flagship  [${e.category.label}]$flex$audience$size');

      // Prefer conceptSummary; fall back to shortDescriptionClient
      final blurb = (e.conceptSummary?.isNotEmpty == true)
          ? e.conceptSummary!
          : e.shortDescriptionClient;
      if (blurb != null && blurb.isNotEmpty) {
        final truncated =
            blurb.length > 130 ? '${blurb.substring(0, 130)}…' : blurb;
        buf.writeln('    "$truncated"');
      }
    }
    if (active.length > 12) {
      buf.writeln('  … and ${active.length - 12} more in the library');
    }
    buf.writeln();
  }

  // ── 6. Suppliers ──────────────────────────────────────────────────────────

  /// Destination-matched suppliers surface first; preferred suppliers ranked higher.
  void _writeSuppliers(
      StringBuffer buf, List<Supplier> suppliers, List<String> destinations) {
    if (suppliers.isEmpty) {
      buf.writeln('## PREFERRED SUPPLIERS\n[None on file]\n');
      return;
    }

    final destLower = destinations.map((d) => d.toLowerCase()).toList();
    final sorted    = [...suppliers]..sort((a, b) {
        final sa = _supplierScore(a, destLower);
        final sb = _supplierScore(b, destLower);
        return sb.compareTo(sa);
      });

    buf.writeln('## PREFERRED SUPPLIERS  (${sorted.length} on file)');
    for (final s in sorted.take(15)) {
      final preferred = s.preferred ? ' [PREFERRED ★]' : '';
      final rating    = s.internalRating > 0
          ? ' (${s.internalRating.toStringAsFixed(1)}★)'
          : '';
      buf.writeln(
          '  - ${s.name}$preferred [${s.category.name}]'
          ' — ${s.city}, ${s.country}$rating');
    }
    if (sorted.length > 15) {
      buf.writeln('  … and ${sorted.length - 15} more');
    }
    buf.writeln();
  }

  int _supplierScore(Supplier s, List<String> destLower) {
    var score = 0;
    if (s.preferred) score += 10;
    final cityLower = s.city.toLowerCase();
    if (destLower.any(
        (d) => cityLower.contains(d) || d.contains(cityLower))) {
      score += 20;
    }
    score += (s.internalRating * 2).round();
    return score;
  }

  // ── 7. Tasks ──────────────────────────────────────────────────────────────

  void _writeTasks(StringBuffer buf, List<Task> tasks) {
    if (tasks.isEmpty) {
      buf.writeln('## OPEN TASKS\n[None]\n');
      return;
    }

    final open = tasks
        .where((t) =>
            t.status != TaskStatus.confirmed &&
            t.status != TaskStatus.cancelled)
        .toList();

    buf.writeln('## OPEN TASKS  (${open.length} of ${tasks.length} open)');
    for (final task in open.take(15)) {
      buf.writeln('  - [${task.priority.label}] ${task.name}'
          '${task.category != null ? ' (${task.category})' : ''}');
    }
    if (open.length > 15) buf.writeln('  … and ${open.length - 15} more');
    buf.writeln();
  }

  // ── Audience + trip type inference ────────────────────────────────────────

  String _inferAudienceProfile(Trip trip) {
    final hints = [
      trip.name,
      trip.clientName,
      trip.notes ?? '',
    ].map((s) => s.toLowerCase()).join(' ');

    if (_hasKeywords(hints, ['ypo', 'executive', 'ceo', 'board', 'corporate', 'chairman'])) {
      return 'Executive / High-Performance Group';
    }
    if (_hasKeywords(hints, ['family', 'kids', 'children', 'multigenerational', 'multi-gen', 'grandparents'])) {
      return 'Family / Multigenerational';
    }
    if (_hasKeywords(hints, ['honeymoon', 'anniversary', 'couple', 'romantic'])) {
      return 'Couple / Romantic';
    }
    if (_hasKeywords(hints, ['incentive', 'reward', 'recognition', 'team-building'])) {
      return 'Corporate Incentive Group';
    }
    if (_hasKeywords(hints, ['intellectual', 'debate', 'salon', 'academic', 'research'])) {
      return 'Intellectually Engaged Private Group';
    }
    if (trip.guestCount <= 2)  return 'Intimate Private (2 guests)';
    if (trip.guestCount <= 6)  return 'Small Private Group (${trip.guestCount} guests)';
    if (trip.guestCount <= 16) return 'Small Group (${trip.guestCount} guests)';
    return 'Medium Group (${trip.guestCount} guests)';
  }

  String _inferTripType(Trip trip) {
    final hints = [
      trip.name,
      trip.notes ?? '',
    ].map((s) => s.toLowerCase()).join(' ');

    if (trip.destinations.length > 3) return 'Multi-Destination Grand Tour';
    if (trip.destinations.length > 1) return 'Multi-City';
    if (_hasKeywords(hints, ['safari', 'africa', 'kenya', 'tanzania', 'serengeti'])) return 'Safari';
    if (_hasKeywords(hints, ['ski', 'snow', 'winter', 'alps', 'mountain'])) return 'Mountain / Winter Sport';
    if (_hasKeywords(hints, ['cruise', 'yacht', 'sailing', 'maritime', 'boat'])) return 'Yacht / Maritime';
    if (_hasKeywords(hints, ['wellness', 'spa', 'retreat', 'detox'])) return 'Wellness Retreat';
    if (_hasKeywords(hints, ['cultural', 'heritage', 'art', 'museum', 'history'])) return 'Cultural Immersion';
    if (_hasKeywords(hints, ['culinary', 'food', 'gastronomy', 'wine', 'dining'])) return 'Culinary Journey';
    return 'Bespoke Private';
  }

  /// Generates 2–4 actionable design priority statements for the AI to reason from.
  List<String> _inferDesignPriorities(
      TripContext ctx, String audience, String tripType) {
    final priorities = <String>[];

    // Audience-specific design guidance
    if (audience.contains('Executive')) {
      priorities.add(
          'Prioritise intellectual depth, private access, and curated substance — '
          'this audience values meaning over volume');
    } else if (audience.contains('Family')) {
      priorities.add(
          'Balance active exploration with restorative pacing — '
          'multigenerational groups need variety in energy level and format');
    } else if (audience.contains('Couple')) {
      priorities.add(
          'Prioritise intimate, unhurried moments — private settings and '
          'slow pacing matter more than itinerary density');
    } else if (audience.contains('Incentive')) {
      priorities.add(
          'Shared group experiences with a clear emotional arc work best — '
          'design for connection and shared memory');
    }

    // Multi-destination flow
    if (ctx.trip.destinations.length > 2) {
      priorities.add(
          'Multi-destination trip — geographic sequencing and transition moments '
          'require careful attention to prevent fatigue');
    }

    // Empty day urgency
    if (ctx.emptyDays.length >= 2) {
      priorities.add(
          '${ctx.emptyDays.length} days are completely unscheduled — '
          'these represent the highest-priority design gaps');
    }

    // Signature experience fit signal
    final guestCount = ctx.trip.guestCount;
    if (guestCount >= 2 && guestCount <= 30 &&
        ctx.signatureExperiences.isNotEmpty) {
      priorities.add(
          'Group size of $guestCount fits most DreamMaker Signature formats — '
          'check the library before proposing generic alternatives');
    }

    return priorities;
  }

  bool _hasKeywords(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Date / time helpers ───────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
