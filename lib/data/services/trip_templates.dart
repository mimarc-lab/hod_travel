// =============================================================================
// TripTemplates
//
// Defines default task sets for each trip template type.
// Each entry maps a group name → list of task titles.
// Group names must match defaultBoardGroupNames exactly.
// =============================================================================

/// Template IDs match the values used in create_trip_screen.dart
const _prePlanning  = 'Pre-Planning';
const _accommodation= 'Accommodation';
const _experiences  = 'Experiences';
const _logistics    = 'Logistics';
const _finance      = 'Finance';
const _delivery     = 'Client Delivery';

/// Returns tasks for [templateId] as a list of {group, title, priority} maps.
/// Returns an empty list for 'none' (blank trip).
List<Map<String, String>> templateTasks(String? templateId) {
  switch (templateId) {
    case 'luxury_city':
      return _luxuryCity;
    case 'adventure':
      return _adventure;
    case 'beach':
      return _beach;
    case 'cultural':
      return _cultural;
    default:
      return [];
  }
}

// ── Luxury City Break ─────────────────────────────────────────────────────────

const _luxuryCity = [
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client intake call & preferences brief',   'priority': 'high'},
  {'group': _prePlanning,   'title': 'Send proposal & itinerary draft',            'priority': 'high'},
  {'group': _prePlanning,   'title': 'Confirm passport validity & visa requirements','priority': 'medium'},
  {'group': _prePlanning,   'title': 'Travel insurance confirmation',               'priority': 'medium'},

  // Accommodation
  {'group': _accommodation, 'title': 'Source luxury 5-star hotel options',         'priority': 'high'},
  {'group': _accommodation, 'title': 'Confirm suite or premium room category',     'priority': 'high'},
  {'group': _accommodation, 'title': 'Request early check-in / late check-out',    'priority': 'medium'},
  {'group': _accommodation, 'title': 'Arrange VIP amenities & welcome gift',       'priority': 'low'},

  // Experiences
  {'group': _experiences,   'title': 'Book private city tour with expert guide',   'priority': 'high'},
  {'group': _experiences,   'title': 'Reserve fine-dining restaurant (signature)', 'priority': 'high'},
  {'group': _experiences,   'title': 'Arrange spa or wellness session',            'priority': 'medium'},
  {'group': _experiences,   'title': 'Source exclusive cultural or art experience','priority': 'medium'},

  // Logistics
  {'group': _logistics,     'title': 'Book business class flights',                'priority': 'high'},
  {'group': _logistics,     'title': 'Arrange private airport transfer (chauffeur)','priority': 'high'},
  {'group': _logistics,     'title': 'Organise in-city private car hire',          'priority': 'medium'},

  // Finance
  {'group': _finance,       'title': 'Prepare itemised budget sheet',              'priority': 'high'},
  {'group': _finance,       'title': 'Send deposit invoice to client',             'priority': 'high'},
  {'group': _finance,       'title': 'Collect final balance payment',              'priority': 'medium'},

  // Client Delivery
  {'group': _delivery,      'title': 'Create digital itinerary document',          'priority': 'high'},
  {'group': _delivery,      'title': 'Prepare destination & hotel info pack',      'priority': 'medium'},
  {'group': _delivery,      'title': 'Send final itinerary to client',             'priority': 'high'},
  {'group': _delivery,      'title': 'Post-trip feedback call',                    'priority': 'low'},
];

// ── Adventure Expedition ──────────────────────────────────────────────────────

const _adventure = [
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client fitness & experience level assessment','priority': 'high'},
  {'group': _prePlanning,   'title': 'Research destination entry requirements',     'priority': 'high'},
  {'group': _prePlanning,   'title': 'Confirm travel vaccinations & health advice', 'priority': 'high'},
  {'group': _prePlanning,   'title': 'Adventure travel insurance policy',           'priority': 'high'},

  // Accommodation
  {'group': _accommodation, 'title': 'Source eco-lodge or expedition camp',         'priority': 'high'},
  {'group': _accommodation, 'title': 'Confirm sleeping bag / equipment rental',    'priority': 'medium'},
  {'group': _accommodation, 'title': 'Book base camp or mountain hut permits',     'priority': 'high'},

  // Experiences
  {'group': _experiences,   'title': 'Book licensed adventure guide / outfitter',  'priority': 'high'},
  {'group': _experiences,   'title': 'Arrange trekking / climbing permits',        'priority': 'high'},
  {'group': _experiences,   'title': 'Source wildlife or nature day excursion',    'priority': 'medium'},
  {'group': _experiences,   'title': 'Confirm safety briefing & emergency protocol','priority': 'high'},

  // Logistics
  {'group': _logistics,     'title': 'Book flights including domestic legs',       'priority': 'high'},
  {'group': _logistics,     'title': 'Arrange ground transport to trailhead',      'priority': 'high'},
  {'group': _logistics,     'title': 'Pack & ship specialist equipment if needed', 'priority': 'medium'},

  // Finance
  {'group': _finance,       'title': 'Prepare expedition cost breakdown',          'priority': 'high'},
  {'group': _finance,       'title': 'Collect deposit from client',                'priority': 'high'},
  {'group': _finance,       'title': 'Confirm permit & park fee payments',         'priority': 'medium'},

  // Client Delivery
  {'group': _delivery,      'title': 'Build day-by-day expedition itinerary',      'priority': 'high'},
  {'group': _delivery,      'title': 'Prepare kit list & packing guide',           'priority': 'medium'},
  {'group': _delivery,      'title': 'Share emergency contacts & safety plan',     'priority': 'high'},
  {'group': _delivery,      'title': 'Post-trip debrief & review',                 'priority': 'low'},
];

// ── Beach & Island ────────────────────────────────────────────────────────────

const _beach = [
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client brief — beach vs island hopping',     'priority': 'high'},
  {'group': _prePlanning,   'title': 'Send tropical destination proposal',          'priority': 'high'},
  {'group': _prePlanning,   'title': 'Check visa & entry requirements',             'priority': 'medium'},
  {'group': _prePlanning,   'title': 'Confirm travel & medical insurance',          'priority': 'medium'},

  // Accommodation
  {'group': _accommodation, 'title': 'Source overwater villa or beachfront resort', 'priority': 'high'},
  {'group': _accommodation, 'title': 'Confirm ocean-view room or villa category',   'priority': 'high'},
  {'group': _accommodation, 'title': 'Request honeymoon / anniversary amenities',   'priority': 'low'},
  {'group': _accommodation, 'title': 'Book additional island properties if hopping','priority': 'medium'},

  // Experiences
  {'group': _experiences,   'title': 'Arrange private snorkelling or diving trip',  'priority': 'high'},
  {'group': _experiences,   'title': 'Book sunset yacht or catamaran cruise',       'priority': 'high'},
  {'group': _experiences,   'title': 'Source island-hopping speedboat transfers',   'priority': 'medium'},
  {'group': _experiences,   'title': 'Reserve beachfront fine-dining dinner',       'priority': 'medium'},

  // Logistics
  {'group': _logistics,     'title': 'Book long-haul & connecting island flights',  'priority': 'high'},
  {'group': _logistics,     'title': 'Arrange seaplane or speedboat airport transfer','priority': 'high'},
  {'group': _logistics,     'title': 'Confirm inter-island transfers',              'priority': 'medium'},

  // Finance
  {'group': _finance,       'title': 'Prepare resort & activities budget',          'priority': 'high'},
  {'group': _finance,       'title': 'Issue deposit invoice',                       'priority': 'high'},
  {'group': _finance,       'title': 'Final balance collection before departure',   'priority': 'medium'},

  // Client Delivery
  {'group': _delivery,      'title': 'Create island-by-island digital itinerary',  'priority': 'high'},
  {'group': _delivery,      'title': 'Prepare resort info & local tips pack',       'priority': 'medium'},
  {'group': _delivery,      'title': 'Send final documents to client',              'priority': 'high'},
  {'group': _delivery,      'title': 'Post-trip feedback & review call',            'priority': 'low'},
];

// ── Cultural Immersion ────────────────────────────────────────────────────────

const _cultural = [
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client cultural interests & pace preference', 'priority': 'high'},
  {'group': _prePlanning,   'title': 'Send curated cultural itinerary proposal',    'priority': 'high'},
  {'group': _prePlanning,   'title': 'Check entry & visa requirements',             'priority': 'medium'},
  {'group': _prePlanning,   'title': 'Confirm travel insurance',                    'priority': 'medium'},

  // Accommodation
  {'group': _accommodation, 'title': 'Source boutique heritage or design hotel',    'priority': 'high'},
  {'group': _accommodation, 'title': 'Confirm room with local character / view',    'priority': 'medium'},
  {'group': _accommodation, 'title': 'Book city-centre riad or historic property',  'priority': 'high'},

  // Experiences
  {'group': _experiences,   'title': 'Book private local history & art tour',       'priority': 'high'},
  {'group': _experiences,   'title': 'Arrange cooking class with local chef',       'priority': 'high'},
  {'group': _experiences,   'title': 'Reserve museum / gallery private access',     'priority': 'medium'},
  {'group': _experiences,   'title': 'Source traditional performance or show',      'priority': 'medium'},
  {'group': _experiences,   'title': 'Arrange local market & food tour',            'priority': 'low'},

  // Logistics
  {'group': _logistics,     'title': 'Book flights with optimal routing',           'priority': 'high'},
  {'group': _logistics,     'title': 'Arrange private city transfer on arrival',    'priority': 'high'},
  {'group': _logistics,     'title': 'Organise inter-city train or transport',      'priority': 'medium'},

  // Finance
  {'group': _finance,       'title': 'Prepare cultural trip budget summary',        'priority': 'high'},
  {'group': _finance,       'title': 'Send deposit invoice to client',              'priority': 'high'},
  {'group': _finance,       'title': 'Collect final payment',                       'priority': 'medium'},

  // Client Delivery
  {'group': _delivery,      'title': 'Build themed cultural day-by-day itinerary',  'priority': 'high'},
  {'group': _delivery,      'title': 'Prepare destination reading list & context',  'priority': 'low'},
  {'group': _delivery,      'title': 'Send final itinerary & documents',            'priority': 'high'},
  {'group': _delivery,      'title': 'Post-trip debrief call',                      'priority': 'low'},
];
