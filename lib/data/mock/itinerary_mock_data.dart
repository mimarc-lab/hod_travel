import 'package:flutter/material.dart';
import '../models/itinerary_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock itinerary data for trip t1 (Amalfi & Sicily, 15 days)
// Days 1–4 fully seeded; days 5–15 have city/label only.
// ─────────────────────────────────────────────────────────────────────────────

List<TripDay> mockDaysForTrip(String tripId) {
  if (tripId != 't1') return [];
  return _days;
}

Map<String, List<ItineraryItem>> mockItemsForTrip(String tripId) {
  if (tripId != 't1') return {};
  return _itemsByDayId;
}

// ── Days ──────────────────────────────────────────────────────────────────────

final List<TripDay> _days = [
  _day('d1',  't1', 1,  DateTime(2025, 9, 14), 'Naples',       'Arrival & Transfer'),
  _day('d2',  't1', 2,  DateTime(2025, 9, 15), 'Ravello',      'Ravello Hilltop'),
  _day('d3',  't1', 3,  DateTime(2025, 9, 16), 'Positano',     'Positano Day'),
  _day('d4',  't1', 4,  DateTime(2025, 9, 17), 'Amalfi',       'Coast Drive & Dinner'),
  _day('d5',  't1', 5,  DateTime(2025, 9, 18), 'Amalfi',       null),
  _day('d6',  't1', 6,  DateTime(2025, 9, 19), 'Capri',        'Island Escape'),
  _day('d7',  't1', 7,  DateTime(2025, 9, 20), 'Capri',        null),
  _day('d8',  't1', 8,  DateTime(2025, 9, 21), 'Palermo',      'Sicily Transfer'),
  _day('d9',  't1', 9,  DateTime(2025, 9, 22), 'Palermo',      'City & Markets'),
  _day('d10', 't1', 10, DateTime(2025, 9, 23), 'Taormina',     'Drive to Taormina'),
  _day('d11', 't1', 11, DateTime(2025, 9, 24), 'Taormina',     'Mt Etna Excursion'),
  _day('d12', 't1', 12, DateTime(2025, 9, 25), 'Taormina',     null),
  _day('d13', 't1', 13, DateTime(2025, 9, 26), 'Agrigento',    'Valley of Temples'),
  _day('d14', 't1', 14, DateTime(2025, 9, 27), 'Catania',      'Departure Prep'),
  _day('d15', 't1', 15, DateTime(2025, 9, 28), 'Catania',      'Departure Day'),
];

TripDay _day(String id, String tripId, int num, DateTime date, String city, String? label) =>
    TripDay(id: id, tripId: tripId, dayNumber: num, date: date, city: city, label: label);

// ── Items ─────────────────────────────────────────────────────────────────────

final Map<String, List<ItineraryItem>> _itemsByDayId = {
  'd1': [
    _item('i1a', 'd1', ItemType.flight, 'British Airways BA562 — LHR → NAP',
        timeBlock: TimeBlock.morning, startTime: const TimeOfDay(hour: 7, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 15),
        location: 'Heathrow Terminal 5', supplierName: 'British Airways',
        status: ItemStatus.confirmed,
        notes: 'Check-in opens 3h before. Premium Economy row 12.'),
    _item('i1b', 'd1', ItemType.transport, 'Private transfer — NAP → Ravello',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 12, minute: 30),
        location: 'Naples Capodichino Airport', supplierName: 'Amalfi Limo',
        status: ItemStatus.confirmed,
        description: 'Driver: Marco (+39 333 456 7890). Meet at arrivals with name sign.'),
    _item('i1c', 'd1', ItemType.hotel, 'Check-in — Belmond Hotel Caruso',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 15, minute: 0),
        location: 'Ravello, Piazza San Giovanni del Toro', supplierName: 'Belmond Hotel Caruso',
        status: ItemStatus.confirmed,
        description: 'Infinity suite with garden view. Early check-in requested (TBC).'),
    _item('i1d', 'd1', ItemType.dining, 'Welcome dinner — Il Flauto di Pan',
        timeBlock: TimeBlock.evening, startTime: const TimeOfDay(hour: 20, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 30),
        location: 'Belmond Hotel Caruso, Ravello', supplierName: 'Belmond Hotel Caruso',
        status: ItemStatus.confirmed,
        description: 'Private terrace booking. Tasting menu with Campania wine pairing.'),
  ],
  'd2': [
    _item('i2a', 'd2', ItemType.experience, 'Morning garden walk — Villa Cimbrone',
        timeBlock: TimeBlock.morning, startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 0),
        location: 'Via Santa Chiara 26, Ravello',
        status: ItemStatus.approved,
        description: 'Private access before public opening. Includes Terrazza dell\'Infinito.'),
    _item('i2b', 'd2', ItemType.experience, 'Private concert — Villa Rufolo Gardens',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 17, minute: 30),
        endTime: const TimeOfDay(hour: 19, minute: 0),
        location: 'Piazza Duomo, Ravello', supplierName: 'Ravello Festival',
        status: ItemStatus.confirmed, linkedTaskId: 'tk4',
        description: 'Seats reserved in premium row. Evening attire suggested.'),
    _item('i2c', 'd2', ItemType.dining, 'Dinner — Rossellinis',
        timeBlock: TimeBlock.evening, startTime: const TimeOfDay(hour: 20, minute: 30),
        location: 'Palazzo Avino, Ravello', supplierName: 'Palazzo Avino',
        status: ItemStatus.confirmed,
        description: '2 Michelin star. Pre-order tasting menu confirmed with sommelier.'),
  ],
  'd3': [
    _item('i3a', 'd3', ItemType.transport, 'Boat transfer — Ravello → Positano',
        timeBlock: TimeBlock.morning, startTime: const TimeOfDay(hour: 9, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 0),
        location: 'Amalfi Marina', supplierName: 'Amalfi Charter',
        status: ItemStatus.confirmed, linkedTaskId: 'tk7',
        description: 'Private 8-person speedboat. Departs Amalfi pier, stops at Praiano.'),
    _item('i3b', 'd3', ItemType.hotel, 'Check-in — Le Sirenuse',
        timeBlock: TimeBlock.morning, startTime: const TimeOfDay(hour: 11, minute: 30),
        location: 'Via Cristoforo Colombo 30, Positano', supplierName: 'Le Sirenuse',
        status: ItemStatus.confirmed,
        description: 'Superior suite with terrace. Luggage transferred from Ravello overnight.'),
    _item('i3c', 'd3', ItemType.experience, 'Cooking class — Mamma Agata',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 17, minute: 30),
        location: 'Via Pietro di Maiori 4, Ravello', supplierName: 'Mamma Agata',
        status: ItemStatus.approved,
        description: 'Private class: limoncello, pasta, and local pastries. 6 guests max.'),
    _item('i3d', 'd3', ItemType.dining, 'Sunset drinks — La Sponda',
        timeBlock: TimeBlock.evening, startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 20, minute: 30),
        location: 'Le Sirenuse, Positano', supplierName: 'Le Sirenuse',
        status: ItemStatus.confirmed),
    _item('i3e', 'd3', ItemType.dining, 'Dinner — Chez Black',
        timeBlock: TimeBlock.evening, startTime: const TimeOfDay(hour: 21, minute: 0),
        location: 'Via del Brigantino 19, Positano',
        status: ItemStatus.draft,
        description: 'Reservation pending confirmation. Alternative: next door at Da Vincenzo.'),
  ],
  'd4': [
    _item('i4a', 'd4', ItemType.transport, 'Private coastal drive — Positano → Amalfi',
        timeBlock: TimeBlock.morning, startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0),
        supplierName: 'Amalfi Limo', status: ItemStatus.confirmed,
        description: 'Scenic SS163 route with photo stop at Furore and Conca dei Marini.'),
    _item('i4b', 'd4', ItemType.experience, 'Cathedral & Cloister of Paradise tour',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 12, minute: 30),
        endTime: const TimeOfDay(hour: 14, minute: 0),
        location: 'Piazza Duomo, Amalfi',
        status: ItemStatus.approved,
        description: 'Private guide arranged. Skip-the-line access included.'),
    _item('i4c', 'd4', ItemType.dining, 'Lunch — La Caravella',
        timeBlock: TimeBlock.afternoon, startTime: const TimeOfDay(hour: 14, minute: 30),
        endTime: const TimeOfDay(hour: 16, minute: 30),
        location: 'Via Matteo Camera 12, Amalfi',
        status: ItemStatus.confirmed,
        description: 'Oldest restaurant on the coast. Seafood tasting menu booked.'),
    _item('i4d', 'd4', ItemType.note, 'Afternoon free — beach or Old Arsenal visit',
        timeBlock: TimeBlock.afternoon,
        status: ItemStatus.draft,
        notes: 'Client requested optional beach time. Arsenal closes 17:00.'),
    _item('i4e', 'd4', ItemType.dining, 'Farewell Amalfi dinner — Ristorante Eolo',
        timeBlock: TimeBlock.evening, startTime: const TimeOfDay(hour: 20, minute: 0),
        location: 'Via Pantaleone Comite 3, Amalfi',
        status: ItemStatus.confirmed,
        description: 'Terrace table overlooking bay. Wine list pre-selected with sommelier.'),
  ],
};

ItineraryItem _item(
  String id,
  String tripDayId,
  ItemType type,
  String title, {
  required TimeBlock timeBlock,
  TimeOfDay? startTime,
  TimeOfDay? endTime,
  String? location,
  String? supplierName,
  required ItemStatus status,
  String? description,
  String? linkedTaskId,
  String? notes,
}) {
  return ItineraryItem(
    id: id,
    tripDayId: tripDayId,
    type: type,
    title: title,
    timeBlock: timeBlock,
    startTime: startTime,
    endTime: endTime,
    location: location,
    supplierName: supplierName,
    status: status,
    description: description,
    linkedTaskId: linkedTaskId,
    notes: notes,
  );
}
