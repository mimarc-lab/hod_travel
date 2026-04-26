import '../../../data/models/itinerary_models.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItinerarySequenceInput
//
// Everything needed to build the sequencing context prompt.
// Components should already be filtered to approved/confirmed/booked only.
// ─────────────────────────────────────────────────────────────────────────────

class ItinerarySequenceInput {
  final Trip trip;
  final List<TripDay> existingDays;
  final Map<String, List<ItineraryItem>> existingItemsByDay;
  final List<TripComponent> components;

  const ItinerarySequenceInput({
    required this.trip,
    required this.existingDays,
    required this.existingItemsByDay,
    required this.components,
  });

  List<TripComponent> get activeComponents => components
      .where((c) =>
          c.status == ComponentStatus.approved ||
          c.status == ComponentStatus.confirmed ||
          c.status == ComponentStatus.booked)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// ItinerarySequenceContextBuilder
//
// Performs deterministic pre-processing and builds a structured prompt block:
//   1. Trip overview + pacing profile
//   2. Dated components grouped by day
//   3. Undated components
//   4. Routing / pacing flags
//   5. Missing data notices
//   6. Existing itinerary summary (items to preserve)
// ─────────────────────────────────────────────────────────────────────────────

class ItinerarySequenceContextBuilder {
  const ItinerarySequenceContextBuilder();

  String build(ItinerarySequenceInput input) {
    final active = input.activeComponents;
    final buf    = StringBuffer();

    _writeTripOverview(buf, input, active);
    _writeGroupedComponents(buf, input, active);
    _writeUndatedComponents(buf, input.trip, active);
    _writeRoutingFlags(buf, active);
    _writeMissingData(buf, active);
    _writeExistingItinerary(buf, input);

    return buf.toString();
  }

  // ── 1. Trip overview + pacing profile ────────────────────────────────────

  void _writeTripOverview(
      StringBuffer buf, ItinerarySequenceInput input, List<TripComponent> active) {
    final trip       = input.trip;
    final durStr     = _durationStr(trip);
    final audience   = _inferAudience(trip);
    final pacingNote = _pacingNote(audience);

    buf.writeln('## TRIP OVERVIEW');
    buf.writeln('Name: ${trip.name}');
    buf.writeln('Client: ${trip.clientName}');
    buf.writeln('Duration: $durStr');
    buf.writeln('Destinations: ${trip.destinations.join(' → ')}');
    buf.writeln('Guests: ${trip.guestCount}');
    buf.writeln('Audience profile: $audience');
    buf.writeln();
    buf.writeln('Pacing guidance: $pacingNote');
    buf.writeln();
    buf.writeln('Components to sequence: ${active.length} '
        '(${_dated(active).length} dated, ${_undated(active).length} undated)');
    buf.writeln();
  }

  // ── 2. Dated components grouped by trip day ───────────────────────────────

  void _writeGroupedComponents(
      StringBuffer buf, ItinerarySequenceInput input, List<TripComponent> active) {
    final dated = _dated(active);
    if (dated.isEmpty) {
      buf.writeln('## DATED COMPONENTS\n[None — all components are undated]\n');
      return;
    }

    // Group by date string
    final byDate = <String, List<TripComponent>>{};
    for (final c in dated) {
      final key = _fmtDate(c.startDate!);
      byDate.putIfAbsent(key, () => []).add(c);
    }

    // Map date → trip day number
    final dayByDate = <String, int>{};
    for (final day in input.existingDays) {
      if (day.date != null) dayByDate[_fmtDate(day.date!)] = day.dayNumber;
    }

    buf.writeln('## DATED COMPONENTS (grouped by service date)');

    final sortedDates = byDate.keys.toList()..sort();
    for (final dateStr in sortedDates) {
      final comps   = byDate[dateStr]!;
      final dayNum  = dayByDate[dateStr];
      final dayLabel= dayNum != null ? 'Day $dayNum ($dateStr)' : dateStr;
      final overload= comps.length > 4 ? '  ⚠ OVERLOADED: ${comps.length} components' : '';

      buf.writeln('$dayLabel$overload:');
      for (final c in comps) {
        final time   = c.startTime != null ? ' [FIXED ${c.startTime!}]' : ' [FLEXIBLE]';
        final loc    = c.locationName ?? c.address;
        final locStr = loc != null ? ' @ $loc' : '';
        buf.writeln('  •$time [${c.componentType.label}] ${c.title}$locStr');
      }
      buf.writeln();
    }
  }

  // ── 3. Undated components ─────────────────────────────────────────────────

  void _writeUndatedComponents(
      StringBuffer buf, Trip trip, List<TripComponent> active) {
    final undated = _undated(active);
    if (undated.isEmpty) {
      buf.writeln('## UNDATED COMPONENTS\n[All components have dates]\n');
      return;
    }

    buf.writeln('## UNDATED COMPONENTS (assign to best-fit days)');
    for (final c in undated) {
      final loc    = c.locationName ?? c.address;
      final locStr = loc != null ? ' @ $loc' : '';
      final hint   = _placementHint(c, trip);
      buf.writeln('  • [${c.componentType.label}] ${c.title}$locStr → $hint');
    }
    buf.writeln();
  }

  // ── 4. Routing flags ──────────────────────────────────────────────────────

  void _writeRoutingFlags(StringBuffer buf, List<TripComponent> active) {
    final flags = <String>[];

    // Group by date; check for location diversity on the same day
    final byDate = <String, List<TripComponent>>{};
    for (final c in _dated(active)) {
      byDate.putIfAbsent(_fmtDate(c.startDate!), () => []).add(c);
    }
    for (final entry in byDate.entries) {
      final locs = entry.value
          .map((c) => (c.locationName ?? c.address ?? '').toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
      if (locs.length >= 3) {
        flags.add('${entry.key}: ${locs.length} different locations — '
            'routing should be reviewed to avoid backtracking');
      }
    }

    // Transport with no time on days with multiple components
    final transports = active.where((c) =>
        c.componentType == ComponentType.transport && c.startTime == null);
    for (final t in transports) {
      flags.add('Transport "${t.title}" has no departure time — '
          'sequence position should be confirmed with operator');
    }

    if (flags.isEmpty) {
      buf.writeln('## ROUTING FLAGS\n[No routing concerns detected]\n');
    } else {
      buf.writeln('## ROUTING FLAGS');
      for (final f in flags) { buf.writeln('  ⚠ $f'); }
      buf.writeln();
    }
  }

  // ── 5. Missing data notices ───────────────────────────────────────────────

  void _writeMissingData(StringBuffer buf, List<TripComponent> active) {
    final warnings = <String>[];

    for (final c in active) {
      final hasLocation = (c.locationName ?? c.address) != null;
      if (!hasLocation &&
          (c.componentType == ComponentType.accommodation ||
           c.componentType == ComponentType.dining ||
           c.componentType == ComponentType.experience)) {
        warnings.add('"${c.title}" (${c.componentType.label}): no location — routing check not possible');
      }
      if (c.componentType == ComponentType.transport && c.startDate == null) {
        warnings.add('"${c.title}" (Transport): no service date — placement is a guess');
      }
      if (c.componentType == ComponentType.guide &&
          c.primaryContactName == null &&
          c.primaryContactPhone == null) {
        warnings.add('"${c.title}" (Guide): no contact info on file');
      }
    }

    if (warnings.isEmpty) {
      buf.writeln('## MISSING DATA\n[No critical missing data]\n');
    } else {
      buf.writeln('## MISSING DATA WARNINGS');
      for (final w in warnings) { buf.writeln('  ⚠ $w'); }
      buf.writeln();
    }
  }

  // ── 6. Existing itinerary summary ─────────────────────────────────────────

  void _writeExistingItinerary(StringBuffer buf, ItinerarySequenceInput input) {
    final daysWithItems = input.existingDays
        .where((d) => (input.existingItemsByDay[d.id] ?? []).isNotEmpty)
        .toList();

    if (daysWithItems.isEmpty) {
      buf.writeln('## EXISTING ITINERARY\n[Empty — no existing items to preserve]\n');
      return;
    }

    buf.writeln('## EXISTING ITINERARY (items already scheduled — do not overwrite)');
    for (final day in daysWithItems) {
      final items = input.existingItemsByDay[day.id] ?? [];
      buf.writeln('Day ${day.dayNumber} (${day.city}): ${items.length} existing item(s)');
      for (final item in items) {
        buf.writeln('  — [${item.type.label}] ${item.title}');
      }
    }
    buf.writeln();
    buf.writeln('IMPORTANT: These items are already in the live itinerary. '
        'The suggested sequence should complement them, not replace them.');
    buf.writeln();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<TripComponent> _dated(List<TripComponent> all) =>
      all.where((c) => c.startDate != null).toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

  List<TripComponent> _undated(List<TripComponent> all) =>
      all.where((c) => c.startDate == null).toList();

  String _durationStr(Trip trip) {
    final s = trip.startDate;
    final e = trip.endDate;
    if (s == null || e == null) return 'Duration unspecified';
    final days = e.difference(s).inDays + 1;
    return '$days days (${_fmtDate(s)} → ${_fmtDate(e)})';
  }

  String _inferAudience(Trip trip) {
    final hints = '${trip.name} ${trip.clientName} ${trip.notes ?? ''}'.toLowerCase();
    if (_has(hints, ['ypo', 'executive', 'ceo', 'board', 'corporate'])) return 'Executive / High-Performance';
    if (_has(hints, ['family', 'kids', 'children', 'multigenerational'])) return 'Family / Multigenerational';
    if (_has(hints, ['honeymoon', 'anniversary', 'couple', 'romantic'])) return 'Couple / Romantic';
    if (_has(hints, ['incentive', 'reward', 'team-building'])) return 'Corporate Incentive';
    if (trip.guestCount <= 2) return 'Intimate Private (2 guests)';
    if (trip.guestCount <= 6) return 'Small Private Group';
    return 'Small Group (${trip.guestCount} guests)';
  }

  String _pacingNote(String audience) {
    if (audience.contains('Executive')) {
      return 'Dense schedule acceptable; preserve private dinner/salon time; signature experiences first.';
    }
    if (audience.contains('Family')) {
      return 'Max 2 major activities per day; include rest windows; avoid very early starts.';
    }
    if (audience.contains('Couple')) {
      return 'Slow mornings; unhurried pacing; avoid back-to-back transfers; intimate settings.';
    }
    if (audience.contains('Corporate Incentive')) {
      return 'Group format; shared experiences; emotional arc through the program.';
    }
    return 'Balanced pacing; avoid overloading days; preserve flexibility.';
  }

  String _placementHint(TripComponent c, Trip trip) {
    switch (c.componentType) {
      case ComponentType.accommodation:
        return 'likely spans multiple nights — place check-in on Day 1 or after major transit';
      case ComponentType.transport:
        final loc = c.locationName ?? '';
        if (loc.toLowerCase().contains('airport') ||
            loc.toLowerCase().contains('kix') ||
            loc.toLowerCase().contains('nrt')) {
          return 'airport transfer — assign to arrival or departure day';
        }
        return 'assign before or after the activity it serves';
      case ComponentType.dining:
        return 'assign to evening of best available day in ${trip.destinations.firstOrNull ?? 'destination'}';
      case ComponentType.experience:
        final dest = trip.destinations.firstOrNull ?? 'destination';
        return 'assign to an available half-day in $dest';
      default:
        return 'assign to best-fit available day';
    }
  }

  bool _has(String text, List<String> kws) => kws.any(text.contains);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
