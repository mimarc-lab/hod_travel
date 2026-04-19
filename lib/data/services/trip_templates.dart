// =============================================================================
// TripTemplates
//
// Defines default task sets for each trip template type.
// Each entry maps group name, title, priority, and scheduling metadata.
// Group names must match defaultBoardGroupNames exactly.
//
// 'duration' = estimated_duration_days used by the backward planning engine.
// =============================================================================

/// Template IDs match the values used in create_trip_screen.dart
const _prePlanning   = 'Pre-Planning';
const _accommodation = 'Accommodation';
const _experiences   = 'Experiences';
const _logistics     = 'Logistics';
const _finance       = 'Finance';
const _delivery      = 'Client Delivery';

/// Returns tasks for [templateId] as a list of {group, title, priority, duration} maps.
/// Returns an empty list for 'none' (blank trip).
/// Type is Map<String, dynamic> to support integer duration alongside string fields.
List<Map<String, dynamic>> templateTasks(String? templateId) {
  switch (templateId) {
    case 'luxury_city': return _luxuryCity;
    case 'adventure':   return _adventure;
    case 'beach':       return _beach;
    case 'cultural':    return _cultural;
    default:            return [];
  }
}

// ── Luxury City Break ─────────────────────────────────────────────────────────

const _luxuryCity = <Map<String, dynamic>>[
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client intake call & preferences brief',    'priority': 'high',   'duration': 2},
  {'group': _prePlanning,   'title': 'Send proposal & itinerary draft',            'priority': 'high',   'duration': 3},
  {'group': _prePlanning,   'title': 'Confirm passport validity & visa requirements','priority': 'medium','duration': 2},
  {'group': _prePlanning,   'title': 'Travel insurance confirmation',              'priority': 'medium', 'duration': 1},

  // Accommodation
  {'group': _accommodation, 'title': 'Source luxury 5-star hotel options',        'priority': 'high',   'duration': 4},
  {'group': _accommodation, 'title': 'Confirm suite or premium room category',    'priority': 'high',   'duration': 2},
  {'group': _accommodation, 'title': 'Request early check-in / late check-out',   'priority': 'medium', 'duration': 1},
  {'group': _accommodation, 'title': 'Arrange VIP amenities & welcome gift',      'priority': 'low',    'duration': 2},

  // Experiences
  {'group': _experiences,   'title': 'Book private city tour with expert guide',  'priority': 'high',   'duration': 3},
  {'group': _experiences,   'title': 'Reserve fine-dining restaurant (signature)','priority': 'high',   'duration': 2},
  {'group': _experiences,   'title': 'Arrange spa or wellness session',           'priority': 'medium', 'duration': 2},
  {'group': _experiences,   'title': 'Source exclusive cultural or art experience','priority': 'medium', 'duration': 3},

  // Logistics
  {'group': _logistics,     'title': 'Book business class flights',               'priority': 'high',   'duration': 3},
  {'group': _logistics,     'title': 'Arrange private airport transfer (chauffeur)','priority': 'high',  'duration': 2},
  {'group': _logistics,     'title': 'Organise in-city private car hire',         'priority': 'medium', 'duration': 2},

  // Finance
  {'group': _finance,       'title': 'Prepare itemised budget sheet',             'priority': 'high',   'duration': 2},
  {'group': _finance,       'title': 'Send deposit invoice to client',            'priority': 'high',   'duration': 1},
  {'group': _finance,       'title': 'Collect final balance payment',             'priority': 'medium', 'duration': 2},

  // Client Delivery
  {'group': _delivery,      'title': 'Create digital itinerary document',         'priority': 'high',   'duration': 3},
  {'group': _delivery,      'title': 'Prepare destination & hotel info pack',     'priority': 'medium', 'duration': 2},
  {'group': _delivery,      'title': 'Send final itinerary to client',            'priority': 'high',   'duration': 1},
  {'group': _delivery,      'title': 'Post-trip feedback call',                   'priority': 'low',    'duration': 1},
];

// ── Adventure Expedition ──────────────────────────────────────────────────────

const _adventure = <Map<String, dynamic>>[
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client fitness & experience level assessment','priority': 'high',  'duration': 2},
  {'group': _prePlanning,   'title': 'Research destination entry requirements',    'priority': 'high',   'duration': 3},
  {'group': _prePlanning,   'title': 'Confirm travel vaccinations & health advice','priority': 'high',   'duration': 2},
  {'group': _prePlanning,   'title': 'Adventure travel insurance policy',          'priority': 'high',   'duration': 2},

  // Accommodation
  {'group': _accommodation, 'title': 'Source eco-lodge or expedition camp',        'priority': 'high',   'duration': 4},
  {'group': _accommodation, 'title': 'Confirm sleeping bag / equipment rental',   'priority': 'medium', 'duration': 2},
  {'group': _accommodation, 'title': 'Book base camp or mountain hut permits',    'priority': 'high',   'duration': 3},

  // Experiences
  {'group': _experiences,   'title': 'Book licensed adventure guide / outfitter', 'priority': 'high',   'duration': 3},
  {'group': _experiences,   'title': 'Arrange trekking / climbing permits',       'priority': 'high',   'duration': 4},
  {'group': _experiences,   'title': 'Source wildlife or nature day excursion',   'priority': 'medium', 'duration': 2},
  {'group': _experiences,   'title': 'Confirm safety briefing & emergency protocol','priority': 'high',  'duration': 2},

  // Logistics
  {'group': _logistics,     'title': 'Book flights including domestic legs',      'priority': 'high',   'duration': 3},
  {'group': _logistics,     'title': 'Arrange ground transport to trailhead',     'priority': 'high',   'duration': 2},
  {'group': _logistics,     'title': 'Pack & ship specialist equipment if needed','priority': 'medium', 'duration': 3},

  // Finance
  {'group': _finance,       'title': 'Prepare expedition cost breakdown',         'priority': 'high',   'duration': 2},
  {'group': _finance,       'title': 'Collect deposit from client',               'priority': 'high',   'duration': 1},
  {'group': _finance,       'title': 'Confirm permit & park fee payments',        'priority': 'medium', 'duration': 2},

  // Client Delivery
  {'group': _delivery,      'title': 'Build day-by-day expedition itinerary',     'priority': 'high',   'duration': 3},
  {'group': _delivery,      'title': 'Prepare kit list & packing guide',          'priority': 'medium', 'duration': 2},
  {'group': _delivery,      'title': 'Share emergency contacts & safety plan',    'priority': 'high',   'duration': 2},
  {'group': _delivery,      'title': 'Post-trip debrief & review',                'priority': 'low',    'duration': 1},
];

// ── Beach & Island ────────────────────────────────────────────────────────────

const _beach = <Map<String, dynamic>>[
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client brief — beach vs island hopping',    'priority': 'high',   'duration': 2},
  {'group': _prePlanning,   'title': 'Send tropical destination proposal',         'priority': 'high',   'duration': 3},
  {'group': _prePlanning,   'title': 'Check visa & entry requirements',            'priority': 'medium', 'duration': 2},
  {'group': _prePlanning,   'title': 'Confirm travel & medical insurance',         'priority': 'medium', 'duration': 1},

  // Accommodation
  {'group': _accommodation, 'title': 'Source overwater villa or beachfront resort','priority': 'high',   'duration': 4},
  {'group': _accommodation, 'title': 'Confirm ocean-view room or villa category',  'priority': 'high',   'duration': 2},
  {'group': _accommodation, 'title': 'Request honeymoon / anniversary amenities',  'priority': 'low',    'duration': 1},
  {'group': _accommodation, 'title': 'Book additional island properties if hopping','priority': 'medium', 'duration': 3},

  // Experiences
  {'group': _experiences,   'title': 'Arrange private snorkelling or diving trip', 'priority': 'high',   'duration': 3},
  {'group': _experiences,   'title': 'Book sunset yacht or catamaran cruise',      'priority': 'high',   'duration': 2},
  {'group': _experiences,   'title': 'Source island-hopping speedboat transfers',  'priority': 'medium', 'duration': 2},
  {'group': _experiences,   'title': 'Reserve beachfront fine-dining dinner',      'priority': 'medium', 'duration': 2},

  // Logistics
  {'group': _logistics,     'title': 'Book long-haul & connecting island flights', 'priority': 'high',   'duration': 3},
  {'group': _logistics,     'title': 'Arrange seaplane or speedboat airport transfer','priority': 'high', 'duration': 2},
  {'group': _logistics,     'title': 'Confirm inter-island transfers',             'priority': 'medium', 'duration': 2},

  // Finance
  {'group': _finance,       'title': 'Prepare resort & activities budget',         'priority': 'high',   'duration': 2},
  {'group': _finance,       'title': 'Issue deposit invoice',                      'priority': 'high',   'duration': 1},
  {'group': _finance,       'title': 'Final balance collection before departure',  'priority': 'medium', 'duration': 2},

  // Client Delivery
  {'group': _delivery,      'title': 'Create island-by-island digital itinerary', 'priority': 'high',   'duration': 3},
  {'group': _delivery,      'title': 'Prepare resort info & local tips pack',      'priority': 'medium', 'duration': 2},
  {'group': _delivery,      'title': 'Send final documents to client',             'priority': 'high',   'duration': 1},
  {'group': _delivery,      'title': 'Post-trip feedback & review call',           'priority': 'low',    'duration': 1},
];

// ── Cultural Immersion ────────────────────────────────────────────────────────

const _cultural = <Map<String, dynamic>>[
  // Pre-Planning
  {'group': _prePlanning,   'title': 'Client cultural interests & pace preference','priority': 'high',   'duration': 2},
  {'group': _prePlanning,   'title': 'Send curated cultural itinerary proposal',   'priority': 'high',   'duration': 3},
  {'group': _prePlanning,   'title': 'Check entry & visa requirements',            'priority': 'medium', 'duration': 2},
  {'group': _prePlanning,   'title': 'Confirm travel insurance',                   'priority': 'medium', 'duration': 1},

  // Accommodation
  {'group': _accommodation, 'title': 'Source boutique heritage or design hotel',   'priority': 'high',   'duration': 4},
  {'group': _accommodation, 'title': 'Confirm room with local character / view',   'priority': 'medium', 'duration': 2},
  {'group': _accommodation, 'title': 'Book city-centre riad or historic property', 'priority': 'high',   'duration': 3},

  // Experiences
  {'group': _experiences,   'title': 'Book private local history & art tour',      'priority': 'high',   'duration': 3},
  {'group': _experiences,   'title': 'Arrange cooking class with local chef',      'priority': 'high',   'duration': 2},
  {'group': _experiences,   'title': 'Reserve museum / gallery private access',    'priority': 'medium', 'duration': 2},
  {'group': _experiences,   'title': 'Source traditional performance or show',     'priority': 'medium', 'duration': 2},
  {'group': _experiences,   'title': 'Arrange local market & food tour',           'priority': 'low',    'duration': 2},

  // Logistics
  {'group': _logistics,     'title': 'Book flights with optimal routing',          'priority': 'high',   'duration': 3},
  {'group': _logistics,     'title': 'Arrange private city transfer on arrival',   'priority': 'high',   'duration': 2},
  {'group': _logistics,     'title': 'Organise inter-city train or transport',     'priority': 'medium', 'duration': 2},

  // Finance
  {'group': _finance,       'title': 'Prepare cultural trip budget summary',       'priority': 'high',   'duration': 2},
  {'group': _finance,       'title': 'Send deposit invoice to client',             'priority': 'high',   'duration': 1},
  {'group': _finance,       'title': 'Collect final payment',                      'priority': 'medium', 'duration': 2},

  // Client Delivery
  {'group': _delivery,      'title': 'Build themed cultural day-by-day itinerary', 'priority': 'high',   'duration': 3},
  {'group': _delivery,      'title': 'Prepare destination reading list & context', 'priority': 'low',    'duration': 2},
  {'group': _delivery,      'title': 'Send final itinerary & documents',           'priority': 'high',   'duration': 1},
  {'group': _delivery,      'title': 'Post-trip debrief call',                     'priority': 'low',    'duration': 1},
];
