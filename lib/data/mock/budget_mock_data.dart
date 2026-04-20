import '../models/cost_item_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock budget data — 20 cost items across trips t1, t2, t3
// Supplier names match supplier mock data for conceptual linking.
// ─────────────────────────────────────────────────────────────────────────────

final List<CostItem> mockCostItems = [
  // ── Trip t1: Amalfi & Sicily ───────────────────────────────────────────────

  _item('ci1',  't1', 'Belmond Hotel Caruso — 2 nights',      CostCategory.accommodation,
      city: 'Ravello',   supplierId: 'sp1', taskId: 'tk4',
      net: 3200, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 14)),

  _item('ci2',  't1', 'Le Sirenuse — 2 nights',               CostCategory.accommodation,
      city: 'Positano',  supplierId: 'sp2',
      net: 2800, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 16)),

  _item('ci3',  't1', 'San Domenico Palace — 3 nights',       CostCategory.accommodation,
      city: 'Taormina',  supplierId: 'sp4', taskId: 'tk5',
      net: 3900, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.due,
      paymentDueDate: DateTime(2026, 4, 25),
      date: DateTime(2025, 9, 20)),

  _item('ci4',  't1', 'Palazzo Avino — 1 night',              CostCategory.accommodation,
      city: 'Ravello',   supplierId: 'sp3',
      net: 1400, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 15)),

  _item('ci5',  't1', 'British Airways LHR–NAP (×6)',         CostCategory.flights,
      city: 'London',    supplierId: 'sp10', taskId: 'tk10',
      net: 7200, mt: MarkupType.fixed, mv: 300, currency: 'USD',
      status: PaymentStatus.pending,
      paymentDueDate: DateTime(2026, 4, 15),
      date: DateTime(2025, 9, 14)),

  _item('ci6',  't1', 'Amalfi Limo — airport transfers (×3)', CostCategory.transport,
      city: 'Amalfi',    supplierId: 'sp7', taskId: 'tk11',
      net: 480, mt: MarkupType.percentage, mv: 20, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 14)),

  _item('ci7',  't1', 'Amalfi Charters — private boat day',   CostCategory.transport,
      city: 'Positano',  supplierId: 'sp8', taskId: 'tk7',
      net: 1200, mt: MarkupType.percentage, mv: 20, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 15)),

  _item('ci8',  't1', 'Villa Rufolo — concert access',        CostCategory.experience,
      city: 'Ravello',   supplierId: 'sp6',
      net: 600, mt: MarkupType.percentage, mv: 25, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 16)),

  _item('ci9',  't1', 'Mamma Agata — private cooking class',  CostCategory.experience,
      city: 'Ravello',   supplierId: 'sp12', taskId: 'tk8',
      net: 520, mt: MarkupType.percentage, mv: 25, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 17)),

  _item('ci10', 't1', 'Rossellinis — dinner for 6',           CostCategory.dining,
      city: 'Ravello',   supplierId: 'sp3',
      net: 780, mt: MarkupType.fixed, mv: 0, currency: 'USD',
      status: PaymentStatus.paid,
      date: DateTime(2025, 9, 15)),

  _item('ci11', 't1', 'La Caravella — seafood lunch',         CostCategory.dining,
      city: 'Amalfi',    supplierId: 'sp15',
      net: 420, mt: MarkupType.fixed, mv: 0, currency: 'USD',
      status: PaymentStatus.pending,
      paymentDueDate: DateTime(2026, 5, 10),
      date: DateTime(2025, 9, 17)),

  _item('ci12', 't1', 'Marco Esposito — private guide (2 days)', CostCategory.guide,
      city: 'Amalfi',    supplierId: 'sp14',
      net: 700, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.due,
      paymentDueDate: DateTime(2026, 4, 20),
      date: DateTime(2025, 9, 16),
      notes: '2 full days: Amalfi old town + Pompeii. Confirm vehicle included.'),

  _item('ci13', 't1', 'Sicily internal transfers',            CostCategory.logistics,
      city: 'Palermo',   taskId: 'tk12',
      net: 380, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.pending,
      date: DateTime(2025, 9, 21)),

  // ── Trip t2: Japanese Highlands ────────────────────────────────────────────

  _item('ci14', 't2', 'Aman Tokyo — 3 nights',                CostCategory.accommodation,
      city: 'Tokyo',
      net: 5400, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.pending,
      paymentDueDate: DateTime(2026, 7, 1),
      date: DateTime(2026, 9, 4)),

  _item('ci15', 't2', 'Gora Kadan ryokan — 2 nights',         CostCategory.accommodation,
      city: 'Hakone',
      net: 2200, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.pending,
      date: DateTime(2026, 9, 8)),

  _item('ci16', 't2', 'Japan Airlines LHR–HND (×2)',          CostCategory.flights,
      city: 'London',
      net: 6800, mt: MarkupType.fixed, mv: 400, currency: 'USD',
      status: PaymentStatus.pending,
      paymentDueDate: DateTime(2026, 6, 15),
      date: DateTime(2026, 9, 4),
      notes: 'Business class confirmed. Seat selection needed.'),

  _item('ci17', 't2', 'Private tea ceremony — Kyoto',         CostCategory.experience,
      city: 'Kyoto',
      net: 380, mt: MarkupType.percentage, mv: 25, currency: 'USD',
      status: PaymentStatus.pending,
      date: DateTime(2026, 9, 11)),

  // ── Trip t3: Patagonia Expedition ──────────────────────────────────────────

  _item('ci18', 't3', 'Tierra Patagonia — 4 nights',          CostCategory.accommodation,
      city: 'Torres del Paine',
      net: 8800, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.pending,
      paymentDueDate: DateTime(2026, 9, 1),
      date: DateTime(2026, 11, 18)),

  _item('ci19', 't3', 'British Airways LHR–EZE (×4)',         CostCategory.flights,
      city: 'London',
      net: 12400, mt: MarkupType.fixed, mv: 600, currency: 'USD',
      status: PaymentStatus.pending,
      date: DateTime(2026, 11, 15),
      notes: 'Business class. Connecting LAN flight to SCL onward.'),

  _item('ci20', 't3', 'Estancia Don Melchor — 2 nights',      CostCategory.accommodation,
      city: 'El Calafate',
      net: 3200, mt: MarkupType.percentage, mv: 15, currency: 'USD',
      status: PaymentStatus.pending,
      date: DateTime(2026, 11, 22)),
];

CostItem _item(
  String id,
  String tripId,
  String name,
  CostCategory category, {
  required String city,
  String? supplierId,
  String? taskId,
  required double net,
  required MarkupType mt,
  required double mv,
  required String currency,
  required PaymentStatus status,
  DateTime? date,
  DateTime? paymentDueDate,
  String? notes,
}) {
  return CostItem(
    id: id,
    tripId: tripId,
    itemName: name,
    category: category,
    city: city,
    supplierId: supplierId,
    taskId: taskId,
    netCost: net,
    markupType: mt,
    markupValue: mv,
    sellPrice: CostItem.deriveSellPrice(net, mt, mv),
    currency: currency,
    paymentStatus: status,
    date: date,
    paymentDueDate: paymentDueDate,
    notes: notes,
  );
}
