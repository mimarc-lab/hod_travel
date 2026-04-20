import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/app_db.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SeedService
//
// Inserts all demo/mock data into Supabase for the current team.
// Run order respects FK constraints:
//   suppliers → trips + destinations → board_groups → tasks
//   → cost_items → trip_days → itinerary_items
// ─────────────────────────────────────────────────────────────────────────────

class SeedService {
  SeedService._();

  /// Delete all team data so a fresh seed can run.
  static Future<void> clearAll({
    required void Function(String message) onProgress,
    required void Function(String error) onError,
  }) async {
    final repos = AppRepositories.instance;
    if (repos == null) { onError('Supabase is not configured.'); return; }
    final teamId = repos.currentTeamId;
    if (teamId == null) { onError('Not signed in or no team found.'); return; }

    try {
      onProgress('Deleting itinerary items…');
      // itinerary_items → trip_days (need to find day IDs first)
      final dayIds = (await db.from('trip_days').select('id').eq('team_id', teamId) as List)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (dayIds.isNotEmpty) {
        await db.from('itinerary_items').delete().inFilter('trip_day_id', dayIds);
      }

      onProgress('Deleting itinerary days…');
      await db.from('trip_days').delete().eq('team_id', teamId);

      onProgress('Deleting cost items…');
      await db.from('cost_items').delete().eq('team_id', teamId);

      onProgress('Deleting tasks…');
      await db.from('tasks').delete().eq('team_id', teamId);

      onProgress('Deleting board groups & trips…');
      final tripIds = (await db.from('trips').select('id').eq('team_id', teamId) as List)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (tripIds.isNotEmpty) {
        // Delete board_groups via RPC or direct delete (cascade handles the rest)
        for (final tid in tripIds) {
          await db.from('board_groups').delete().eq('trip_id', tid);
        }
        await db.from('trip_destinations').delete().inFilter('trip_id', tripIds);
      }
      await db.from('trips').delete().eq('team_id', teamId);

      onProgress('Deleting supplier tags…');
      final spIds = (await db.from('suppliers').select('id').eq('team_id', teamId) as List)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (spIds.isNotEmpty) {
        await db.from('supplier_tag_links').delete().inFilter('supplier_id', spIds);
      }
      await db.from('supplier_tags').delete().eq('team_id', teamId);

      onProgress('Deleting suppliers…');
      await db.from('suppliers').delete().eq('team_id', teamId);

      onProgress('Cleared.');
    } catch (e) {
      onError('Clear failed: $e');
    }
  }

  static Future<void> seed({
    required void Function(String message) onProgress,
    required void Function(String error) onError,
  }) async {
    final repos = AppRepositories.instance;
    if (repos == null) {
      onError('Supabase is not configured.');
      return;
    }
    final client = db;
    final teamId = repos.currentTeamId;
    final userId = repos.currentUserId;

    if (teamId == null || userId == null) {
      onError('Not signed in or no team found.');
      return;
    }

    try {
      // ── 1. Suppliers ────────────────────────────────────────────────────────
      onProgress('Inserting suppliers…');
      final spIdMap = await _insertSuppliers(client, teamId, userId);

      // ── 2. Trips ─────────────────────────────────────────────────────────────
      onProgress('Inserting trips…');
      final tripIdMap = await _insertTrips(client, teamId, userId);

      // ── 3. Board groups — query existing or insert defaults ──────────────────
      onProgress('Creating board groups…');
      final groupIdMap = await _fetchOrCreateGroups(client, tripIdMap);

      // ── 4. Tasks ──────────────────────────────────────────────────────────────
      onProgress('Inserting tasks…');
      final taskCount = await _insertTasks(client, teamId, userId, tripIdMap, groupIdMap, spIdMap);
      onProgress('Inserted $taskCount tasks…');

      // ── 5. Cost items ─────────────────────────────────────────────────────────
      onProgress('Inserting cost items…');
      await _insertCostItems(client, teamId, userId, tripIdMap, spIdMap);

      // ── 6. Trip days (t1 only) ────────────────────────────────────────────────
      onProgress('Inserting itinerary days…');
      final dayIdMap = await _insertTripDays(client, teamId, userId, tripIdMap);

      // ── 7. Itinerary items (t1 only) ──────────────────────────────────────────
      onProgress('Inserting itinerary items…');
      await _insertItineraryItems(client, teamId, userId, dayIdMap, spIdMap);

      onProgress('Done! All demo data loaded.');
    } catch (e) {
      onError('Seed failed: $e');
    }
  }

  // ── Suppliers ────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _insertSuppliers(
    SupabaseClient client,
    String teamId,
    String userId,
  ) async {
    final spIdMap = <String, String>{}; // 'sp1' → real uuid

    final rows = _supplierRows(teamId, userId);
    for (final entry in rows.entries) {
      final mockId = entry.key;
      final row    = entry.value;
      final inserted = await client.from('suppliers').insert(row).select('id').single();
      final realId = inserted['id'] as String;
      spIdMap[mockId] = realId;

      // Insert tags for this supplier
      final tags = _supplierTags[mockId] ?? [];
      if (tags.isNotEmpty) {
        final tagRows = await client
            .from('supplier_tags')
            .upsert(
              tags.map((n) => {'team_id': teamId, 'name': n}).toList(),
              onConflict: 'team_id,name',
            )
            .select('id, name');
        final links = (tagRows as List).map((r) => {
          'supplier_id': realId,
          'tag_id': (r as Map<String, dynamic>)['id'] as String,
        }).toList();
        if (links.isNotEmpty) {
          await client.from('supplier_tag_links').insert(links);
        }
      }
    }
    return spIdMap;
  }

  // ── Trips ────────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _insertTrips(
    SupabaseClient client,
    String teamId,
    String userId,
  ) async {
    final tripIdMap = <String, String>{}; // 't1' → real uuid

    for (final entry in _tripRows(teamId, userId).entries) {
      final mockId = entry.key;
      final data   = entry.value;
      final row    = data['trip'] as Map<String, dynamic>;
      final cities = data['destinations'] as List<String>;

      final inserted = await client.from('trips').insert(row).select('id').single();
      final realId   = inserted['id'] as String;
      tripIdMap[mockId] = realId;

      // Destinations
      if (cities.isNotEmpty) {
        await client.from('trip_destinations').insert(
          cities.asMap().entries.map((e) => {
            'trip_id':    realId,
            'city':       e.value,
            'sort_order': e.key,
          }).toList(),
        );
      }
    }
    return tripIdMap;
  }

  // ── Board groups ──────────────────────────────────────────────────────────────
  // Query existing groups first; only insert if none exist for the trip.
  // This avoids duplicates from prior partial seeds and RLS-blocked deletions.

  static const _defaultGroupNames = [
    'Pre-Planning', 'Accommodation', 'Experiences',
    'Logistics',    'Finance',       'Client Delivery',
  ];

  static Future<Map<String, String>> _fetchOrCreateGroups(
    SupabaseClient client,
    Map<String, String> tripIdMap,
  ) async {
    final groupIdMap = <String, String>{};

    for (final entry in tripIdMap.entries) {
      final mockTripKey = entry.key;
      final realTripId  = entry.value;

      // Check for existing groups
      var rows = await client
          .from('board_groups')
          .select('id, sort_order')
          .eq('trip_id', realTripId)
          .order('sort_order') as List;

      // Insert defaults if none found
      if (rows.isEmpty) {
        rows = await client
            .from('board_groups')
            .insert(
              _defaultGroupNames.asMap().entries.map((e) => {
                'trip_id':    realTripId,
                'name':       e.value,
                'sort_order': e.key,
              }).toList(),
            )
            .select('id, sort_order') as List;
      }

      // For t1 only, map g1-g6 → real UUIDs (by sort_order position)
      if (mockTripKey == 't1') {
        const mockKeys = ['g1', 'g2', 'g3', 'g4', 'g5', 'g6'];
        for (final r in rows) {
          final row       = r as Map<String, dynamic>;
          final sortOrder = (row['sort_order'] as num?)?.toInt() ?? 0;
          if (sortOrder < mockKeys.length) {
            groupIdMap[mockKeys[sortOrder]] = row['id'] as String;
          }
        }
      }
    }

    if (groupIdMap.isEmpty) {
      throw Exception(
        'Board groups for t1 could not be created. Check board_groups RLS policies.');
    }
    return groupIdMap;
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────────

  static Future<int> _insertTasks(
    SupabaseClient client,
    String teamId,
    String userId,
    Map<String, String> tripIdMap,
    Map<String, String> groupIdMap,
    Map<String, String> spIdMap,
  ) async {
    final realTripId = tripIdMap['t1'];
    if (realTripId == null) return 0;

    final rows = _taskRows(teamId, userId, realTripId, groupIdMap, spIdMap);
    final inserted = await client
        .from('tasks')
        .insert(rows)
        .select('id') as List;

    if (inserted.isEmpty) {
      throw Exception(
        'Task insert returned 0 rows. Check tasks RLS INSERT policy for your role.');
    }
    return inserted.length;
  }

  // ── Cost items ────────────────────────────────────────────────────────────────

  static Future<void> _insertCostItems(
    SupabaseClient client,
    String teamId,
    String userId,
    Map<String, String> tripIdMap,
    Map<String, String> spIdMap,
  ) async {
    for (final row in _costItemRows(teamId, userId, tripIdMap, spIdMap)) {
      await client.from('cost_items').insert(row);
    }
  }

  // ── Trip days ─────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _insertTripDays(
    SupabaseClient client,
    String teamId,
    String userId,
    Map<String, String> tripIdMap,
  ) async {
    final dayIdMap = <String, String>{}; // 'd1' → real uuid
    final realTripId = tripIdMap['t1'];
    if (realTripId == null) return dayIdMap;

    for (final entry in _tripDayRows(teamId, realTripId).entries) {
      final mockId   = entry.key;
      final row      = entry.value;
      final inserted = await client.from('trip_days').insert(row).select('id').single();
      dayIdMap[mockId] = inserted['id'] as String;
    }
    return dayIdMap;
  }

  // ── Itinerary items ───────────────────────────────────────────────────────────

  static Future<void> _insertItineraryItems(
    SupabaseClient client,
    String teamId,
    String userId,
    Map<String, String> dayIdMap,
    Map<String, String> spIdMap,
  ) async {
    for (final row in _itineraryItemRows(teamId, dayIdMap, spIdMap)) {
      await client.from('itinerary_items').insert(row);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Row data
  // ════════════════════════════════════════════════════════════════════════════

  // ── Supplier rows (keyed by mock ID) ─────────────────────────────────────────

  static Map<String, Map<String, dynamic>> _supplierRows(String teamId, String userId) => {
    'sp1': {'team_id': teamId, 'created_by': userId, 'name': 'Belmond Hotel Caruso', 'category': 'hotel', 'city': 'Ravello', 'country': 'Italy', 'location': 'Piazza San Giovanni del Toro 2, Ravello', 'contact_name': 'Giulia Ferretti', 'contact_email': 'reservations@hotelcaruso.com', 'contact_phone': '+39 089 858 801', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.belmond.com/hotels/europe/italy/amalfi-coast/belmond-hotel-caruso', 'notes': 'Outstanding service and views. Giulia at reservations is our main contact — always responsive. Infinity suite is the preferred category for our clients. Early check-in usually granted with advance notice. Strong sommelier team for wine pairing dinners.'},
    'sp2': {'team_id': teamId, 'created_by': userId, 'name': 'Le Sirenuse', 'category': 'hotel', 'city': 'Positano', 'country': 'Italy', 'location': 'Via Cristoforo Colombo 30, Positano', 'contact_name': 'Antonio Sersale', 'contact_email': 'info@sirenuse.it', 'contact_phone': '+39 089 875 066', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.sirenuse.it', 'notes': 'The defining Positano property. Family-owned and maintained to impeccable standards. Superior suites with private terraces are always our first recommendation. La Sponda restaurant bookings need to be arranged well in advance. Wine list is exceptional.'},
    'sp3': {'team_id': teamId, 'created_by': userId, 'name': 'Palazzo Avino', 'category': 'hotel', 'city': 'Ravello', 'country': 'Italy', 'location': 'Via San Giovanni del Toro 28, Ravello', 'contact_name': 'Marco Avino', 'contact_email': 'info@palazzoavino.com', 'contact_phone': '+39 089 818 181', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.palazzoavino.com', 'notes': 'Rossellinis is a 2 Michelin star restaurant worth booking even for non-resident clients. Pink suites are our preferred category. Cliff pool is stunning in late afternoon light.'},
    'sp4': {'team_id': teamId, 'created_by': userId, 'name': 'San Domenico Palace', 'category': 'hotel', 'city': 'Taormina', 'country': 'Italy', 'location': 'Piazza San Domenico 5, Taormina', 'contact_name': 'Francesca Lombardo', 'contact_email': 'reservations@sandomenico.com', 'contact_phone': '+39 0942 613 111', 'preferred': true, 'internal_rating': 4.0, 'website': 'https://www.fourseasons.com/taormina', 'notes': 'Four Seasons-managed property. Exceptional pool terrace with Etna views. Francesca in reservations manages HOD special rates. Best time to book is 4–5 months ahead for peak season.'},
    'sp5': {'team_id': teamId, 'created_by': userId, 'name': 'Four Seasons Firenze', 'category': 'hotel', 'city': 'Florence', 'country': 'Italy', 'location': 'Borgo Pinti 99, Florence', 'contact_name': 'Isabella Ricci', 'contact_email': 'reservations.flo@fourseasons.com', 'contact_phone': '+39 055 2626 1', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.fourseasons.com/florence', 'notes': 'Garden suites are the standout offering. The private garden is unlike anything else in Florence. Il Palagio restaurant is Michelin recommended. Ask Isabella for the private garden dinner setup — available for special occasions.'},
    'sp6': {'team_id': teamId, 'created_by': userId, 'name': 'Villa Rufolo Estate', 'category': 'villa', 'city': 'Ravello', 'country': 'Italy', 'location': 'Piazza Duomo, Ravello', 'contact_name': 'Roberto Mansi', 'contact_email': 'bookings@villarufolo.it', 'contact_phone': '+39 089 857 621', 'preferred': true, 'internal_rating': 4.0, 'website': 'https://www.villarufolo.com', 'notes': 'Ravello Festival uses the gardens — concerts during summer months need to be cross-referenced with client booking dates. Roberto handles private access and event hire. Deposit required 6 months ahead in festival season.'},
    'sp7': {'team_id': teamId, 'created_by': userId, 'name': 'Amalfi Limo', 'category': 'transport', 'city': 'Amalfi', 'country': 'Italy', 'location': "Via Lorenzo d'Amalfi 12, Amalfi", 'contact_name': 'Marco Esposito', 'contact_email': 'info@amafilimo.it', 'contact_phone': '+39 333 456 7890', 'preferred': true, 'internal_rating': 4.0, 'website': 'https://www.amalfilimo.it', 'notes': 'Marco is highly reliable. Always on time, speaks good English, and is discreet with high-profile clients. Fleet includes Mercedes E-Class, V-Class, and a minibus for groups. Book 3+ weeks ahead for peak summer. Always ask for Marco personally.'},
    'sp8': {'team_id': teamId, 'created_by': userId, 'name': 'Amalfi Charters', 'category': 'transport', 'city': 'Amalfi', 'country': 'Italy', 'location': 'Amalfi Marina, Amalfi', 'contact_name': 'Luca Ferrara', 'contact_email': 'charters@amalfiboats.it', 'contact_phone': '+39 089 872 345', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.amalfiboats.it', 'notes': 'Best private boat operator on the coast. 8-person speedboat and larger vessels available. Luca is our main contact. Champagne and snack service included in HOD rate. Fully insured, all safety-compliant.'},
    'sp9': {'team_id': teamId, 'created_by': userId, 'name': 'Elite Transfers Italy', 'category': 'transport', 'city': 'Rome', 'country': 'Italy', 'location': 'Via Veneto 45, Rome', 'contact_name': 'Claudia Bianchi', 'contact_email': 'bookings@elitetransfers.it', 'contact_phone': '+39 06 5678 1234', 'preferred': false, 'internal_rating': 4.0, 'website': 'https://www.elitetransfers.it', 'notes': 'Good reliability for airport and intercity transfers. Fleet is well-maintained. Sometimes communication lags — always confirm 48h before departure.'},
    'sp10': {'team_id': teamId, 'created_by': userId, 'name': 'British Airways', 'category': 'transport', 'city': 'London', 'country': 'United Kingdom', 'location': 'Heathrow Terminal 5', 'contact_name': 'Trade Desk', 'contact_email': 'trade@britishairways.com', 'contact_phone': '+44 344 493 0787', 'preferred': false, 'internal_rating': 3.0, 'website': 'https://www.britishairways.com', 'notes': 'Primary carrier for LHR routes. Business class preferred for HOD clients. Trade desk access via BA Travel Agent portal. Seat selection should be handled immediately after booking.'},
    'sp11': {'team_id': teamId, 'created_by': userId, 'name': 'Ravello Festival', 'category': 'experience', 'city': 'Ravello', 'country': 'Italy', 'location': 'Villa Rufolo Gardens, Ravello', 'contact_name': 'Sofia Manfredi', 'contact_email': 'vip@ravellofestival.com', 'contact_phone': '+39 089 858 422', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.ravellofestival.com', 'notes': 'Annual classical music festival in the Villa Rufolo gardens. VIP access and premium seating available for HOD clients. Sofia manages partner relations. Booking typically opens in January — act fast.'},
    'sp12': {'team_id': teamId, 'created_by': userId, 'name': 'Mamma Agata', 'category': 'experience', 'city': 'Ravello', 'country': 'Italy', 'location': 'Via Pietro di Maiori 4, Ravello', 'contact_name': 'Chiara Lima', 'contact_email': 'info@mammaagata.com', 'contact_phone': '+39 089 857 043', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.mammaagata.com', 'notes': 'Exceptional private cooking school. 4–5 hour class includes limoncello, pasta, and pastries. Maximum 6 guests per session. Clients consistently rate this a trip highlight. Book 2+ months ahead.'},
    'sp13': {'team_id': teamId, 'created_by': userId, 'name': 'Etna Guides', 'category': 'guide', 'city': 'Taormina', 'country': 'Italy', 'location': 'Via Etnea 120, Catania', 'contact_name': 'Salvatore Bruno', 'contact_email': 'info@etnaguides.it', 'contact_phone': '+39 095 714 5566', 'preferred': false, 'internal_rating': 3.0, 'notes': 'Communication has been inconsistent — took 3 attempts to confirm Sept 2025 booking and eventually cancelled last minute. May need alternative provider for Etna excursions. Keep on watch list.'},
    'sp14': {'team_id': teamId, 'created_by': userId, 'name': 'Marco Esposito Private Guide', 'category': 'guide', 'city': 'Amalfi', 'country': 'Italy', 'contact_name': 'Marco Esposito', 'contact_email': 'marco.guide@gmail.com', 'contact_phone': '+39 347 891 2345', 'preferred': true, 'internal_rating': 5.0, 'notes': 'Independent guide, exceptional cultural knowledge of the Amalfi Coast and Pompeii. Speaks fluent English and French. Available for full-day and multi-day guiding. Contact via WhatsApp preferred for scheduling.'},
    'sp15': {'team_id': teamId, 'created_by': userId, 'name': 'La Caravella', 'category': 'restaurant', 'city': 'Amalfi', 'country': 'Italy', 'location': 'Via Matteo Camera 12, Amalfi', 'contact_name': "Pierino d'Amore", 'contact_email': 'info@ristorantelacaravella.it', 'contact_phone': '+39 089 871 029', 'preferred': true, 'internal_rating': 4.0, 'website': 'https://www.ristorantelacaravella.it', 'notes': 'Oldest restaurant on the Amalfi coast. Pierino manages HOD reservations — always reserves the best terrace table. Seafood tasting menu is exceptional.'},
    'sp16': {'team_id': teamId, 'created_by': userId, 'name': 'Don Alfonso 1890', 'category': 'restaurant', 'city': 'Sorrento', 'country': 'Italy', 'location': "Piazza Sant'Agata 13, Sant'Agata sui Due Golfi", 'contact_name': 'Alfonso Iaccarino', 'contact_email': 'info@donalfonso.com', 'contact_phone': '+39 081 878 0026', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.donalfonso.com', 'notes': '2 Michelin stars. One of the finest dining experiences in southern Italy. Own organic farm supplies the kitchen. Must book minimum 6 weeks ahead. Private dining room available for groups.'},
    'sp17': {'team_id': teamId, 'created_by': userId, 'name': 'Casa Cucina', 'category': 'restaurant', 'city': 'Naples', 'country': 'Italy', 'location': 'Via dei Tribunali 44, Naples', 'contact_name': 'Elena Russo', 'contact_email': 'reservations@casacucina.it', 'contact_phone': '+39 081 234 5678', 'preferred': false, 'internal_rating': 4.0, 'notes': 'Excellent Neapolitan cooking school and restaurant. Pasta-making and pizza experiences are very popular with clients. Can accommodate dietary requirements with advance notice.'},
    'sp18': {'team_id': teamId, 'created_by': userId, 'name': 'The Thinking Traveller', 'category': 'concierge', 'city': 'London', 'country': 'United Kingdom', 'location': '22 Endell Street, London WC2H 9AD', 'contact_name': 'Henry Hallam', 'contact_email': 'henry@thethinkingtraveller.com', 'contact_phone': '+44 20 7099 5045', 'preferred': true, 'internal_rating': 5.0, 'website': 'https://www.thethinkingtraveller.com', 'notes': 'Best-in-class villa concierge for Italy. Henry is incredibly knowledgeable about off-market villas and can handle the full concierge setup. Works well alongside our team rather than competing.'},
  };

  static const Map<String, List<String>> _supplierTags = {
    'sp1':  ['Amalfi Coast', 'Infinity Pool', 'Fine Dining', 'Honeymoon', 'Anniversary'],
    'sp2':  ['Positano', 'Terrace', 'La Sponda', 'Family Owned', 'Iconic'],
    'sp3':  ['Ravello', 'Michelin Star', 'Clifftop', 'Dining', 'Pink Palace'],
    'sp4':  ['Taormina', 'Four Seasons', 'Mount Etna View', 'Historic'],
    'sp5':  ['Florence', 'Four Seasons', 'Private Garden', 'Renaissance', 'Il Palagio'],
    'sp6':  ['Ravello', 'Historic', 'Festival Garden', 'Concerts', 'UNESCO'],
    'sp7':  ['Driver', 'Private Transfer', 'Group Transport', 'Reliable'],
    'sp8':  ['Boat Charter', 'Speedboat', 'Coastal', 'Swimming', 'Amalfi Coast'],
    'sp9':  ['Airport Transfer', 'Intercity', 'Rome', 'Reliable'],
    'sp10': ['Flights', 'LHR', 'Business Class', 'BA'],
    'sp11': ['Music', 'Cultural', 'Outdoor', 'Festival', 'Exclusive Access'],
    'sp12': ['Cooking Class', 'Limoncello', 'Authentic', 'Private', 'Food'],
    'sp13': ['Mount Etna', 'Hiking', 'Volcanic', 'Sicily'],
    'sp14': ['Amalfi', 'Pompeii', 'Private', 'Cultural', 'English Speaking'],
    'sp15': ['Seafood', 'Terrace', 'Tasting Menu', 'Historic', 'Amalfi'],
    'sp16': ['Michelin', '2 Stars', 'Farm to Table', 'Private Dining', 'Sorrento'],
    'sp17': ['Cooking', 'Naples', 'Pizza', 'Pasta', 'Group Friendly'],
    'sp18': ['Villa Specialist', 'Concierge', 'Italy', 'Exclusive', 'Private'],
  };

  // ── Trip rows ─────────────────────────────────────────────────────────────────

  static Map<String, Map<String, dynamic>> _tripRows(String teamId, String userId) => {
    't1': {
      'trip': {'team_id': teamId, 'created_by': userId, 'trip_name': 'Amalfi & Sicily', 'client_name': 'The Hartwell Family', 'start_date': '2026-06-10', 'end_date': '2026-06-25', 'number_of_guests': 6, 'trip_lead_id': userId, 'status': 'confirmed', 'notes': 'Anniversary celebration. Client prefers boutique properties only.'},
      'destinations': ['Naples', 'Positano', 'Palermo', 'Taormina'],
    },
    't2': {
      'trip': {'team_id': teamId, 'created_by': userId, 'trip_name': 'Japanese Highlands', 'client_name': 'Mr & Mrs Ashford', 'start_date': '2026-09-04', 'end_date': '2026-09-20', 'number_of_guests': 2, 'trip_lead_id': userId, 'status': 'planning', 'notes': 'Preference for ryokans and off-the-beaten-path experiences.'},
      'destinations': ['Tokyo', 'Kyoto', 'Hakone', 'Kanazawa'],
    },
    't3': {
      'trip': {'team_id': teamId, 'created_by': userId, 'trip_name': 'Patagonia Expedition', 'client_name': 'The Reinhardt Group', 'start_date': '2026-11-15', 'end_date': '2026-11-30', 'number_of_guests': 4, 'trip_lead_id': userId, 'status': 'planning'},
      'destinations': ['Buenos Aires', 'El Calafate', 'Torres del Paine'],
    },
    't4': {
      'trip': {'team_id': teamId, 'created_by': userId, 'trip_name': 'Maldives Escape', 'client_name': 'Mr Dominic Strauss', 'start_date': '2026-04-18', 'end_date': '2026-04-26', 'number_of_guests': 2, 'trip_lead_id': userId, 'status': 'in_progress'},
      'destinations': ['Malé', 'Baa Atoll'],
    },
    't5': {
      'trip': {'team_id': teamId, 'created_by': userId, 'trip_name': 'Morocco & Sahara', 'client_name': 'The Okonkwo Family', 'start_date': '2026-03-05', 'end_date': '2026-03-16', 'number_of_guests': 8, 'trip_lead_id': userId, 'status': 'completed'},
      'destinations': ['Marrakech', 'Fès', 'Merzouga', 'Essaouira'],
    },
  };

  // ── Board group rows (grouped by mock trip ID) ────────────────────────────────
  // ── Task rows (t1 only — fully seeded from mock) ──────────────────────────────

  static List<Map<String, dynamic>> _taskRows(
    String teamId,
    String userId,
    String tripId,
    Map<String, String> groupIdMap,
    Map<String, String> spIdMap,
  ) {
    String? g(String mockGroupId) => groupIdMap[mockGroupId];
    String? sp(String? mockSpId) => mockSpId != null ? spIdMap[mockSpId] : null;

    return [
      // ── Pre-Planning (g1) ─────────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g1'), 'title': 'Client intake call',    'status': 'confirmed',   'priority': 'high',   'cost_status': 'pending', 'destination_city': 'N/A',      'due_date': '2026-03-10', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g1'), 'title': 'Proposal document',     'status': 'confirmed',   'priority': 'high',   'cost_status': 'pending', 'destination_city': 'N/A',      'due_date': '2026-03-15', 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 1},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g1'), 'title': 'Passport & visa check', 'status': 'researching', 'priority': 'medium', 'cost_status': 'pending', 'destination_city': 'N/A',      'due_date': '2026-04-01', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 2},
      // ── Accommodation (g2) ────────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g2'), 'title': 'Villa Rufolo — 3 nights',       'status': 'researching',   'priority': 'high',   'cost_status': 'quoted',  'destination_city': 'Positano', 'travel_date': '2026-06-12', 'due_date': '2026-04-20', 'supplier_id': sp('sp1'), 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g2'), 'title': 'Hotel San Domenico',            'status': 'not_started',   'priority': 'high',   'cost_status': 'pending', 'destination_city': 'Taormina', 'travel_date': '2026-06-19', 'due_date': '2026-04-25', 'supplier_id': sp('sp2'), 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 1},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g2'), 'title': 'Palermo boutique hotel',        'status': 'not_started',   'priority': 'medium', 'cost_status': 'pending', 'destination_city': 'Palermo',  'travel_date': '2026-06-16', 'due_date': '2026-04-25', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 2},
      // ── Experiences (g3) ──────────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g3'), 'title': 'Private boat tour — Amalfi coast',  'status': 'researching',   'priority': 'high',   'cost_status': 'approved', 'destination_city': 'Positano', 'travel_date': '2026-06-13', 'due_date': '2026-05-01', 'supplier_id': sp('sp3'), 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g3'), 'title': 'Cooking class — pasta & limoncello', 'status': 'not_started',   'priority': 'low',    'cost_status': 'quoted',   'destination_city': 'Naples',   'travel_date': '2026-06-11', 'due_date': '2026-05-05', 'supplier_id': sp('sp4'), 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 1},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g3'), 'title': 'Etna summit excursion',             'status': 'awaiting_reply','priority': 'medium', 'cost_status': 'pending',  'destination_city': 'Taormina', 'travel_date': '2026-06-21', 'due_date': '2026-05-10', 'supplier_id': sp('sp5'), 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 2},
      // ── Logistics (g4) ────────────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g4'), 'title': 'International flights — LHR to NAP',   'status': 'awaiting_reply','priority': 'high',   'cost_status': 'quoted',  'destination_city': 'Naples',   'travel_date': '2026-06-10', 'due_date': '2026-04-15', 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g4'), 'title': 'Private transfer — Naples to Positano', 'status': 'not_started',  'priority': 'medium', 'cost_status': 'pending', 'destination_city': 'Positano', 'travel_date': '2026-06-10', 'due_date': '2026-05-15', 'supplier_id': sp('sp6'), 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 1},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g4'), 'title': 'Internal Sicily transfers',             'status': 'not_started',  'priority': 'low',    'cost_status': 'pending', 'destination_city': 'Sicily',   'travel_date': '2026-06-16', 'due_date': '2026-05-20', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 2},
      // ── Finance (g5) ──────────────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g5'), 'title': 'Budget summary sheet',      'status': 'researching', 'priority': 'high',   'cost_status': 'quoted',  'due_date': '2026-04-10', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g5'), 'title': 'Deposit invoice to client', 'status': 'not_started', 'priority': 'high',   'cost_status': 'pending', 'due_date': '2026-04-20', 'is_client_visible': false, 'approval_status': 'draft', 'sort_order': 1},
      // ── Client Delivery (g6) ──────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g6'), 'title': 'Digital itinerary — first draft', 'status': 'not_started', 'priority': 'high',   'cost_status': 'pending', 'due_date': '2026-05-01', 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 0},
      {'team_id': teamId, 'created_by': userId, 'trip_id': tripId, 'board_group_id': g('g6'), 'title': 'Client welcome pack',            'status': 'not_started', 'priority': 'medium', 'cost_status': 'pending', 'due_date': '2026-05-25', 'is_client_visible': true,  'approval_status': 'draft', 'sort_order': 1},
    ];
  }

  // ── Cost item rows ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _costItemRows(
    String teamId,
    String userId,
    Map<String, String> tripIdMap,
    Map<String, String> spIdMap,
  ) {
    String? t(String mockTripId) => tripIdMap[mockTripId];
    String? sp(String? mockSpId) => mockSpId != null ? spIdMap[mockSpId] : null;

    return [
      // ── t1: Amalfi & Sicily ──────────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp1'), 'item_name': 'Belmond Hotel Caruso — 2 nights',          'category': 'accommodation', 'city': 'Ravello',   'service_date': '2025-09-14', 'currency': 'USD', 'net_cost': 3200,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 3680.0,   'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp2'), 'item_name': 'Le Sirenuse — 2 nights',                   'category': 'accommodation', 'city': 'Positano',  'service_date': '2025-09-16', 'currency': 'USD', 'net_cost': 2800,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 3220.0,   'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp4'), 'item_name': 'San Domenico Palace — 3 nights',            'category': 'accommodation', 'city': 'Taormina',  'service_date': '2025-09-20', 'currency': 'USD', 'net_cost': 3900,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 4485.0,   'payment_status': 'due',     'approval_status': 'draft', 'payment_due_date': '2026-04-25'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp3'), 'item_name': 'Palazzo Avino — 1 night',                   'category': 'accommodation', 'city': 'Ravello',   'service_date': '2025-09-15', 'currency': 'USD', 'net_cost': 1400,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 1610.0,   'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp10'),'item_name': 'British Airways JFK–NAP (×6)',              'category': 'flights',       'city': 'New York',  'service_date': '2025-09-14', 'currency': 'USD', 'net_cost': 7200,  'markup_type': 'fixed',      'markup_value': 300,'sell_price': 7500.0,   'payment_status': 'pending', 'approval_status': 'draft', 'payment_due_date': '2026-04-15'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp7'), 'item_name': 'Amalfi Limo — airport transfers (×3)',       'category': 'transport',     'city': 'Amalfi',    'service_date': '2025-09-14', 'currency': 'USD', 'net_cost': 480,   'markup_type': 'percentage', 'markup_value': 20, 'sell_price': 576.0,    'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp8'), 'item_name': 'Amalfi Charters — private boat day',         'category': 'transport',     'city': 'Positano',  'service_date': '2025-09-15', 'currency': 'USD', 'net_cost': 1200,  'markup_type': 'percentage', 'markup_value': 20, 'sell_price': 1440.0,   'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp6'), 'item_name': 'Villa Rufolo — concert access',              'category': 'experience',    'city': 'Ravello',   'service_date': '2025-09-16', 'currency': 'USD', 'net_cost': 600,   'markup_type': 'percentage', 'markup_value': 25, 'sell_price': 750.0,    'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp12'),'item_name': 'Mamma Agata — private cooking class',        'category': 'experience',    'city': 'Ravello',   'service_date': '2025-09-17', 'currency': 'USD', 'net_cost': 520,   'markup_type': 'percentage', 'markup_value': 25, 'sell_price': 650.0,    'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp3'), 'item_name': 'Rossellinis — dinner for 6',                 'category': 'dining',        'city': 'Ravello',   'service_date': '2025-09-15', 'currency': 'USD', 'net_cost': 780,   'markup_type': 'fixed',      'markup_value': 0,  'sell_price': 780.0,    'payment_status': 'paid',    'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp15'),'item_name': 'La Caravella — seafood lunch',               'category': 'dining',        'city': 'Amalfi',    'service_date': '2025-09-17', 'currency': 'USD', 'net_cost': 420,   'markup_type': 'fixed',      'markup_value': 0,  'sell_price': 420.0,    'payment_status': 'pending', 'approval_status': 'draft', 'payment_due_date': '2026-05-10'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'supplier_id': sp('sp14'),'item_name': 'Marco Esposito — private guide (2 days)',    'category': 'guide',         'city': 'Amalfi',    'service_date': '2025-09-16', 'currency': 'USD', 'net_cost': 700,   'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 805.0,    'payment_status': 'due',     'approval_status': 'draft', 'payment_due_date': '2026-04-20', 'notes': '2 full days: Amalfi old town + Pompeii. Confirm vehicle included.'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t1'), 'item_name': 'Sicily internal transfers',                                             'category': 'logistics',     'city': 'Palermo',   'service_date': '2025-09-21', 'currency': 'USD', 'net_cost': 380,   'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 437.0,    'payment_status': 'pending', 'approval_status': 'draft'},
      // ── t2: Japanese Highlands ───────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t2'), 'item_name': 'Aman Tokyo — 3 nights',               'category': 'accommodation', 'city': 'Tokyo',              'service_date': '2026-09-04', 'currency': 'USD', 'net_cost': 5400,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 6210.0,   'payment_status': 'pending', 'approval_status': 'draft', 'payment_due_date': '2026-07-01'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t2'), 'item_name': 'Gora Kadan ryokan — 2 nights',        'category': 'accommodation', 'city': 'Hakone',             'service_date': '2026-09-08', 'currency': 'USD', 'net_cost': 2200,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 2530.0,   'payment_status': 'pending', 'approval_status': 'draft'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t2'), 'item_name': 'Japan Airlines JFK–HND (×2)',         'category': 'flights',       'city': 'New York',           'service_date': '2026-09-04', 'currency': 'USD', 'net_cost': 6800,  'markup_type': 'fixed',      'markup_value': 400,'sell_price': 7200.0,   'payment_status': 'pending', 'approval_status': 'draft', 'payment_due_date': '2026-06-15', 'notes': 'Business class confirmed. Seat selection needed.'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t2'), 'item_name': 'Private tea ceremony — Kyoto',        'category': 'experience',    'city': 'Kyoto',              'service_date': '2026-09-11', 'currency': 'USD', 'net_cost': 380,   'markup_type': 'percentage', 'markup_value': 25, 'sell_price': 475.0,    'payment_status': 'pending', 'approval_status': 'draft'},
      // ── t3: Patagonia Expedition ─────────────────────────────────────────
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t3'), 'item_name': 'Tierra Patagonia — 4 nights',         'category': 'accommodation', 'city': 'Torres del Paine',   'service_date': '2026-11-18', 'currency': 'USD', 'net_cost': 8800,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 10120.0,  'payment_status': 'pending', 'approval_status': 'draft', 'payment_due_date': '2026-09-01'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t3'), 'item_name': 'American Airlines JFK–EZE (×4)',      'category': 'flights',       'city': 'New York',           'service_date': '2026-11-15', 'currency': 'USD', 'net_cost': 12400, 'markup_type': 'fixed',      'markup_value': 600,'sell_price': 13000.0,  'payment_status': 'pending', 'approval_status': 'draft', 'notes': 'Business class. Connecting LAN flight to SCL onward.'},
      {'team_id': teamId, 'created_by': userId, 'trip_id': t('t3'), 'item_name': 'Estancia Don Melchor — 2 nights',     'category': 'accommodation', 'city': 'El Calafate',        'service_date': '2026-11-22', 'currency': 'USD', 'net_cost': 3200,  'markup_type': 'percentage', 'markup_value': 15, 'sell_price': 3680.0,   'payment_status': 'pending', 'approval_status': 'draft'},
    ];
  }

  // ── Trip day rows (t1 only) ───────────────────────────────────────────────────

  static Map<String, Map<String, dynamic>> _tripDayRows(String teamId, String tripId) => {
    'd1':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 1,  'date': '2025-09-14', 'city': 'Naples',    'title': 'Arrival & Transfer'},
    'd2':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 2,  'date': '2025-09-15', 'city': 'Ravello',   'title': 'Ravello Hilltop'},
    'd3':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 3,  'date': '2025-09-16', 'city': 'Positano',  'title': 'Positano Day'},
    'd4':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 4,  'date': '2025-09-17', 'city': 'Amalfi',    'title': 'Coast Drive & Dinner'},
    'd5':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 5,  'date': '2025-09-18', 'city': 'Amalfi'},
    'd6':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 6,  'date': '2025-09-19', 'city': 'Capri',     'title': 'Island Escape'},
    'd7':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 7,  'date': '2025-09-20', 'city': 'Capri'},
    'd8':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 8,  'date': '2025-09-21', 'city': 'Palermo',   'title': 'Sicily Transfer'},
    'd9':  {'team_id': teamId, 'trip_id': tripId, 'day_number': 9,  'date': '2025-09-22', 'city': 'Palermo',   'title': 'City & Markets'},
    'd10': {'team_id': teamId, 'trip_id': tripId, 'day_number': 10, 'date': '2025-09-23', 'city': 'Taormina',  'title': 'Drive to Taormina'},
    'd11': {'team_id': teamId, 'trip_id': tripId, 'day_number': 11, 'date': '2025-09-24', 'city': 'Taormina',  'title': 'Mt Etna Excursion'},
    'd12': {'team_id': teamId, 'trip_id': tripId, 'day_number': 12, 'date': '2025-09-25', 'city': 'Taormina'},
    'd13': {'team_id': teamId, 'trip_id': tripId, 'day_number': 13, 'date': '2025-09-26', 'city': 'Agrigento', 'title': 'Valley of Temples'},
    'd14': {'team_id': teamId, 'trip_id': tripId, 'day_number': 14, 'date': '2025-09-27', 'city': 'Catania',   'title': 'Departure Prep'},
    'd15': {'team_id': teamId, 'trip_id': tripId, 'day_number': 15, 'date': '2025-09-28', 'city': 'Catania',   'title': 'Departure Day'},
  };

  // ── Itinerary item rows (t1, days 1–4) ────────────────────────────────────────

  static List<Map<String, dynamic>> _itineraryItemRows(
    String teamId,
    Map<String, String> dayIdMap,
    Map<String, String> spIdMap,
  ) {
    String? d(String mockDayId) => dayIdMap[mockDayId];
    String? sp(String? name) {
      // Map supplier names (used in mock) to IDs via name lookup
      const nameToMock = {
        'British Airways':     'sp10',
        'Amalfi Limo':         'sp7',
        'Belmond Hotel Caruso':'sp1',
        'Ravello Festival':    'sp11',
        'Palazzo Avino':       'sp3',
        'Amalfi Charter':      'sp8',
        'Amalfi Charters':     'sp8',
        'Le Sirenuse':         'sp2',
        'Mamma Agata':         'sp12',
      };
      if (name == null) return null;
      final mockId = nameToMock[name];
      return mockId != null ? spIdMap[mockId] : null;
    }

    return [
      // ── Day 1 ─────────────────────────────────────────────────────────────
      {'team_id': teamId, 'trip_day_id': d('d1'), 'type': 'transport', 'title': 'British Airways BA562 — LHR → NAP',   'time_block': 'morning',   'start_time': '07:30', 'end_time': '11:15', 'location': 'Heathrow Terminal 5',               'supplier_id': sp('British Airways'),     'status': 'confirmed', 'approval_status': 'draft', 'notes': 'Check-in opens 3h before. Premium Economy row 12.',                        'sort_order': 0},
      {'team_id': teamId, 'trip_day_id': d('d1'), 'type': 'transport', 'title': 'Private transfer — NAP → Ravello',    'time_block': 'afternoon', 'start_time': '12:30',                       'location': 'Naples Capodichino Airport',         'supplier_id': sp('Amalfi Limo'),         'status': 'confirmed', 'approval_status': 'draft', 'description': 'Driver: Marco (+39 333 456 7890). Meet at arrivals with name sign.',  'sort_order': 1},
      {'team_id': teamId, 'trip_day_id': d('d1'), 'type': 'hotel',     'title': 'Check-in — Belmond Hotel Caruso',     'time_block': 'afternoon', 'start_time': '15:00',                       'location': 'Ravello, Piazza San Giovanni del Toro','supplier_id': sp('Belmond Hotel Caruso'), 'status': 'confirmed', 'approval_status': 'draft', 'description': 'Infinity suite with garden view. Early check-in requested (TBC).',    'sort_order': 2},
      {'team_id': teamId, 'trip_day_id': d('d1'), 'type': 'dining',    'title': 'Welcome dinner — Il Flauto di Pan',   'time_block': 'evening',   'start_time': '20:00', 'end_time': '22:30', 'location': 'Belmond Hotel Caruso, Ravello',      'supplier_id': sp('Belmond Hotel Caruso'), 'status': 'confirmed', 'approval_status': 'draft', 'description': 'Private terrace booking. Tasting menu with Campania wine pairing.',  'sort_order': 3},
      // ── Day 2 ─────────────────────────────────────────────────────────────
      {'team_id': teamId, 'trip_day_id': d('d2'), 'type': 'experience','title': 'Morning garden walk — Villa Cimbrone', 'time_block': 'morning',   'start_time': '09:00', 'end_time': '11:00', 'location': 'Via Santa Chiara 26, Ravello',                                         'status': 'approved',  'approval_status': 'draft', 'description': 'Private access before public opening. Includes Terrazza dell\'Infinito.','sort_order': 0},
      {'team_id': teamId, 'trip_day_id': d('d2'), 'type': 'experience','title': 'Private concert — Villa Rufolo Gardens','time_block': 'afternoon', 'start_time': '17:30', 'end_time': '19:00', 'location': 'Piazza Duomo, Ravello',            'supplier_id': sp('Ravello Festival'),     'status': 'confirmed', 'approval_status': 'draft', 'description': 'Seats reserved in premium row. Evening attire suggested.',            'sort_order': 1},
      {'team_id': teamId, 'trip_day_id': d('d2'), 'type': 'dining',    'title': 'Dinner — Rossellinis',                'time_block': 'evening',   'start_time': '20:30',                       'location': 'Palazzo Avino, Ravello',             'supplier_id': sp('Palazzo Avino'),       'status': 'confirmed', 'approval_status': 'draft', 'description': '2 Michelin star. Pre-order tasting menu confirmed with sommelier.',   'sort_order': 2},
      // ── Day 3 ─────────────────────────────────────────────────────────────
      {'team_id': teamId, 'trip_day_id': d('d3'), 'type': 'transport', 'title': 'Boat transfer — Ravello → Positano',  'time_block': 'morning',   'start_time': '09:30', 'end_time': '11:00', 'location': 'Amalfi Marina',                     'supplier_id': sp('Amalfi Charter'),      'status': 'confirmed', 'approval_status': 'draft', 'description': 'Private 8-person speedboat. Departs Amalfi pier, stops at Praiano.',  'sort_order': 0},
      {'team_id': teamId, 'trip_day_id': d('d3'), 'type': 'hotel',     'title': 'Check-in — Le Sirenuse',              'time_block': 'morning',   'start_time': '11:30',                       'location': 'Via Cristoforo Colombo 30, Positano','supplier_id': sp('Le Sirenuse'),         'status': 'confirmed', 'approval_status': 'draft', 'description': 'Superior suite with terrace. Luggage transferred from Ravello overnight.','sort_order': 1},
      {'team_id': teamId, 'trip_day_id': d('d3'), 'type': 'experience','title': 'Cooking class — Mamma Agata',         'time_block': 'afternoon', 'start_time': '14:00', 'end_time': '17:30', 'location': 'Via Pietro di Maiori 4, Ravello',   'supplier_id': sp('Mamma Agata'),         'status': 'approved',  'approval_status': 'draft', 'description': 'Private class: limoncello, pasta, and local pastries. 6 guests max.',  'sort_order': 2},
      {'team_id': teamId, 'trip_day_id': d('d3'), 'type': 'dining',    'title': 'Sunset drinks — La Sponda',           'time_block': 'evening',   'start_time': '19:00', 'end_time': '20:30', 'location': 'Le Sirenuse, Positano',             'supplier_id': sp('Le Sirenuse'),         'status': 'confirmed', 'approval_status': 'draft',                                                                                                                                           'sort_order': 3},
      {'team_id': teamId, 'trip_day_id': d('d3'), 'type': 'dining',    'title': 'Dinner — Chez Black',                 'time_block': 'evening',   'start_time': '21:00',                       'location': 'Via del Brigantino 19, Positano',                                     'status': 'draft',     'approval_status': 'draft', 'description': 'Reservation pending confirmation. Alternative: next door at Da Vincenzo.','sort_order': 4},
      // ── Day 4 ─────────────────────────────────────────────────────────────
      {'team_id': teamId, 'trip_day_id': d('d4'), 'type': 'transport', 'title': 'Private coastal drive — Positano → Amalfi','time_block': 'morning',  'start_time': '10:00', 'end_time': '12:00',                                          'supplier_id': sp('Amalfi Limo'),         'status': 'confirmed', 'approval_status': 'draft', 'description': 'Scenic SS163 route with photo stop at Furore and Conca dei Marini.', 'sort_order': 0},
      {'team_id': teamId, 'trip_day_id': d('d4'), 'type': 'experience','title': 'Cathedral & Cloister of Paradise tour','time_block': 'afternoon', 'start_time': '12:30', 'end_time': '14:00', 'location': 'Piazza Duomo, Amalfi',                                                'status': 'approved',  'approval_status': 'draft', 'description': 'Private guide arranged. Skip-the-line access included.',              'sort_order': 1},
      {'team_id': teamId, 'trip_day_id': d('d4'), 'type': 'dining',    'title': 'Lunch — La Caravella',                'time_block': 'afternoon', 'start_time': '14:30', 'end_time': '16:30', 'location': 'Via Matteo Camera 12, Amalfi',                                        'status': 'confirmed', 'approval_status': 'draft', 'description': 'Oldest restaurant on the coast. Seafood tasting menu booked.',        'sort_order': 2},
      {'team_id': teamId, 'trip_day_id': d('d4'), 'type': 'note',      'title': 'Afternoon free — beach or Old Arsenal visit','time_block': 'afternoon',                                                                                                                         'status': 'draft',     'approval_status': 'draft', 'notes': 'Client requested optional beach time. Arsenal closes 17:00.',               'sort_order': 3},
      {'team_id': teamId, 'trip_day_id': d('d4'), 'type': 'dining',    'title': 'Farewell Amalfi dinner — Ristorante Eolo','time_block': 'evening',   'start_time': '20:00',                      'location': 'Via Pantaleone Comite 3, Amalfi',                                     'status': 'confirmed', 'approval_status': 'draft', 'description': 'Terrace table overlooking bay. Wine list pre-selected with sommelier.','sort_order': 4},
    ];
  }
}
