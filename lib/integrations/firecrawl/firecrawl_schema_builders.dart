// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlSchemaBuilders — extraction schemas and prompts per supplier category.
//
// Add new categories here when the feature is ready. Accommodation is the only
// fully-built schema. Other categories have prompt stubs for future expansion.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class FirecrawlSchemaBuilders {
  // ── Accommodation (hotels, villas, lodges, resorts, camps) ─────────────────

  static const String accommodationPrompt =
      'Extract structured accommodation data from this website for use in a '
      'luxury travel management platform. The property may be a hotel, villa, '
      'lodge, resort, private home, safari camp, or similar. '
      'Return only factual information visible on the page or closely related '
      'pages. Do not guess or infer values that are not clearly stated. '
      'If a field is not present, omit it or return null.';

  static const Map<String, dynamic> accommodationSchema = {
    'type': 'object',
    'properties': {

      // ── Identity ────────────────────────────────────────────────────────────
      'property_name': {
        'type': ['string', 'null'],
        'description': 'Official property name as displayed on the website',
      },
      'property_type': {
        'type': ['string', 'null'],
        'description':
            'Type of accommodation. One of: hotel, villa, lodge, resort, camp, '
            'private home, apartment, other',
      },
      'short_summary': {
        'type': ['string', 'null'],
        'description':
            '2–3 sentence description of the property suitable for a travel database',
      },

      // ── Location ────────────────────────────────────────────────────────────
      'city': {
        'type': ['string', 'null'],
        'description': 'City or nearest town',
      },
      'region_or_state': {
        'type': ['string', 'null'],
        'description': 'Region, state, province, or island group',
      },
      'country': {
        'type': ['string', 'null'],
        'description': 'Country name',
      },
      'address': {
        'type': ['string', 'null'],
        'description': 'Full street address if available',
      },
      'latitude': {
        'type': ['number', 'null'],
        'description': 'GPS latitude in decimal degrees',
      },
      'longitude': {
        'type': ['number', 'null'],
        'description': 'GPS longitude in decimal degrees',
      },
      'website_url': {
        'type': ['string', 'null'],
        'description': 'Official website URL',
      },

      // ── Contact ─────────────────────────────────────────────────────────────
      'contact_name': {
        'type': ['string', 'null'],
        'description': 'Name of the primary contact or reservations manager',
      },
      'contact_email': {
        'type': ['string', 'null'],
        'description': 'Primary reservations or contact email',
      },
      'contact_phone': {
        'type': ['string', 'null'],
        'description': 'Primary phone number including country code',
      },
      'whatsapp': {
        'type': ['string', 'null'],
        'description': 'WhatsApp number if different from main phone',
      },

      // ── Capacity & room types ────────────────────────────────────────────────
      'number_of_rooms': {
        'type': ['integer', 'null'],
        'description': 'Total number of rooms (excluding suites)',
      },
      'number_of_suites': {
        'type': ['integer', 'null'],
        'description': 'Total number of suites',
      },
      'number_of_villas': {
        'type': ['integer', 'null'],
        'description': 'Total number of villas or standalone units',
      },
      'bedroom_configurations': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Available bedroom configurations e.g. "1-bedroom villa", "2-bedroom suite"',
      },
      'room_types': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Named room/suite/villa categories offered',
      },
      'max_occupancy': {
        'type': ['string', 'null'],
        'description':
            'Maximum total guests the property can accommodate, e.g. "18 guests"',
      },

      // ── Family ──────────────────────────────────────────────────────────────
      'family_friendly': {
        'type': ['boolean', 'null'],
        'description': 'Whether the property explicitly welcomes families with children',
      },
      'children_policy': {
        'type': ['string', 'null'],
        'description': 'Children policy details or age restrictions',
      },

      // ── Dining ──────────────────────────────────────────────────────────────
      'dining_outlets': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Named restaurants, bars, or dining experiences on-site',
      },

      // ── Wellness ────────────────────────────────────────────────────────────
      'spa': {
        'type': ['boolean', 'null'],
        'description': 'Whether a spa is available on site',
      },
      'wellness_features': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Wellness offerings e.g. yoga, meditation, fitness centre, hydrotherapy',
      },
      'pool': {
        'type': ['boolean', 'null'],
        'description': 'Whether a swimming pool is available',
      },
      'beach_access': {
        'type': ['boolean', 'null'],
        'description': 'Whether the property has direct beach access',
      },
      'ski_access': {
        'type': ['boolean', 'null'],
        'description': 'Whether the property has ski-in/ski-out or direct piste access',
      },

      // ── Activities & amenities ───────────────────────────────────────────────
      'activities_on_site': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Activities guests can do at or arranged by the property '
            'e.g. game drives, snorkelling, cooking classes',
      },
      'notable_amenities': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Key facilities and amenities e.g. helipad, wine cellar, private cinema',
      },
      'accessibility_features': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Accessibility provisions e.g. wheelchair access, roll-in shower',
      },

      // ── Operations ──────────────────────────────────────────────────────────
      'airport_transfer_available': {
        'type': ['boolean', 'null'],
        'description': 'Whether airport or airstrip transfers are offered',
      },
      'check_in_time': {
        'type': ['string', 'null'],
        'description': 'Standard check-in time e.g. "15:00"',
      },
      'check_out_time': {
        'type': ['string', 'null'],
        'description': 'Standard check-out time e.g. "11:00"',
      },
      'cancellation_policy': {
        'type': ['string', 'null'],
        'description': 'Cancellation terms as stated on the website',
      },

      // ── Pricing ─────────────────────────────────────────────────────────────
      'pricing_text': {
        'type': ['string', 'null'],
        'description':
            'Any pricing information visible: nightly rates, "from" prices, '
            'rate descriptions (do not guess)',
      },
      'currency': {
        'type': ['string', 'null'],
        'description': 'ISO 4217 currency code if pricing is shown e.g. USD, EUR, ZAR',
      },

      // ── Media ───────────────────────────────────────────────────────────────
      'image_urls': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Absolute URLs of property images found on the page',
      },
      'brochure_urls': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'URLs of downloadable PDF brochures or fact sheets',
      },

      // ── Tags ────────────────────────────────────────────────────────────────
      'tags': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Keyword tags useful for filtering in a travel database '
            'e.g. luxury, boutique, romantic, safari, overwater, adults-only',
      },

      // ── Extraction metadata ─────────────────────────────────────────────────
      'source_pages_used': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'URLs of pages visited to gather this data',
      },
      'extraction_notes': {
        'type': ['string', 'null'],
        'description':
            'Any caveats about extraction quality or ambiguous data encountered',
      },
    },
  };

  // ── Experience (tours, activities, safaris, charters) ──────────────────────

  static const String experiencePrompt =
      'Extract structured experience and activity data from this website for '
      'use in a luxury travel management platform. The experience may be a '
      'private tour, cooking class, helicopter flight, diving trip, safari '
      'outing, cultural activity, yacht charter, or similar. '
      'Return only factual information visible on the page or closely related '
      'pages. Do not guess or infer values that are not clearly stated. '
      'If a field is not present, omit it or return null.';

  static const Map<String, dynamic> experienceSchema = {
    'type': 'object',
    'properties': {

      // ── Identity ────────────────────────────────────────────────────────────
      'experience_name': {
        'type': ['string', 'null'],
        'description': 'Official name of the experience or activity',
      },
      'category': {
        'type': ['string', 'null'],
        'description':
            'Type of experience. One of: private tour, cooking class, '
            'helicopter flight, diving trip, safari outing, cultural activity, '
            'yacht charter, family experience, water sport, wildlife, adventure, other',
      },
      'short_summary': {
        'type': ['string', 'null'],
        'description':
            '2–3 sentence description suitable for a luxury travel database',
      },

      // ── Location ────────────────────────────────────────────────────────────
      'destination_city': {
        'type': ['string', 'null'],
        'description': 'City or nearest town where the experience takes place',
      },
      'destination_region': {
        'type': ['string', 'null'],
        'description': 'Region, state, province, or island group',
      },
      'destination_country': {
        'type': ['string', 'null'],
        'description': 'Country name',
      },
      'exact_location': {
        'type': ['string', 'null'],
        'description':
            'Specific meeting point, departure location, or venue address',
      },

      // ── Provider ────────────────────────────────────────────────────────────
      'provider_name': {
        'type': ['string', 'null'],
        'description': 'Name of the company or operator offering the experience',
      },
      'provider_website': {
        'type': ['string', 'null'],
        'description': 'Official website URL of the provider',
      },
      'contact_name': {
        'type': ['string', 'null'],
        'description': 'Name of the booking contact or operations manager',
      },
      'contact_email': {
        'type': ['string', 'null'],
        'description': 'Booking or enquiry email address',
      },
      'contact_phone': {
        'type': ['string', 'null'],
        'description': 'Contact phone number including country code',
      },

      // ── Logistics ───────────────────────────────────────────────────────────
      'duration': {
        'type': ['string', 'null'],
        'description':
            'How long the experience lasts e.g. "3 hours", "full day", "7 nights"',
      },
      'recommended_time_of_day': {
        'type': ['string', 'null'],
        'description':
            'Best or typical time e.g. "early morning", "sunset", "overnight"',
      },
      'private_or_shared': {
        'type': ['string', 'null'],
        'description':
            'Whether the experience is private, shared/group, or both options available',
      },
      'minimum_guests': {
        'type': ['integer', 'null'],
        'description': 'Minimum number of guests required',
      },
      'maximum_guests': {
        'type': ['integer', 'null'],
        'description': 'Maximum number of guests permitted',
      },
      'operating_days': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Days of the week when available e.g. ["Monday", "Wednesday", "Friday"] '
            'or ["Daily"]',
      },
      'start_times': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Available departure or start times e.g. ["06:00", "09:00"]',
      },

      // ── Guests ──────────────────────────────────────────────────────────────
      'age_restrictions': {
        'type': ['string', 'null'],
        'description':
            'Age requirements or restrictions e.g. "minimum age 12", "adults only"',
      },
      'child_friendly': {
        'type': ['boolean', 'null'],
        'description': 'Whether the experience is suitable for children',
      },
      'physical_difficulty': {
        'type': ['string', 'null'],
        'description':
            'Physical effort required e.g. "easy", "moderate", "strenuous"',
      },
      'accessibility_notes': {
        'type': ['string', 'null'],
        'description':
            'Any accessibility information or limitations for guests with disabilities',
      },

      // ── Inclusions ──────────────────────────────────────────────────────────
      'inclusions': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'What is included in the price e.g. "guide", "equipment", "lunch", "transfers"',
      },
      'exclusions': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'What is NOT included e.g. "gratuities", "park fees", "drinks"',
      },
      'languages_available': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Languages in which the experience is conducted',
      },

      // ── Transfers ───────────────────────────────────────────────────────────
      'pickup_available': {
        'type': ['boolean', 'null'],
        'description': 'Whether hotel or location pickup is offered',
      },
      'transfer_included': {
        'type': ['boolean', 'null'],
        'description': 'Whether transfers are included in the price',
      },

      // ── Conditions ──────────────────────────────────────────────────────────
      'weather_dependency': {
        'type': ['boolean', 'null'],
        'description':
            'Whether the experience is subject to cancellation or change due to weather',
      },
      'cancellation_policy': {
        'type': ['string', 'null'],
        'description': 'Cancellation and refund terms as stated on the page',
      },

      // ── Pricing ─────────────────────────────────────────────────────────────
      'pricing_text': {
        'type': ['string', 'null'],
        'description':
            'Any pricing visible: per person rates, "from" prices, private rates '
            '(do not guess)',
      },
      'currency': {
        'type': ['string', 'null'],
        'description': 'ISO 4217 currency code if pricing is shown e.g. USD, EUR, KES',
      },

      // ── Media ───────────────────────────────────────────────────────────────
      'image_urls': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'Absolute URLs of experience images found on the page',
      },

      // ── Tags ────────────────────────────────────────────────────────────────
      'tags': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description':
            'Keyword tags for filtering e.g. luxury, outdoor, cultural, '
            'romantic, adventure, family, wildlife, water, sunset',
      },

      // ── Extraction metadata ─────────────────────────────────────────────────
      'source_pages_used': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
        'description': 'URLs of pages visited to gather this data',
      },
      'extraction_notes': {
        'type': ['string', 'null'],
        'description':
            'Any caveats about extraction quality or ambiguous data encountered',
      },
    },
  };

  // ── Future category stubs — prompts only, schemas TBD ─────────────────────

  static const String restaurantPrompt =
      'Extract structured dining venue data from this website for a luxury '
      'travel management platform. Focus on restaurant name, cuisine type, '
      'location, contact, opening hours, reservation policy, dress code, '
      'and notable dishes or experiences.';

  static const String transportPrompt =
      'Extract structured ground or air transport provider data from this '
      'website. Focus on operator name, vehicle or aircraft types, routes '
      'served, booking contact, and service details.';

  static const String guidePrompt =
      'Extract structured local guide or concierge service data from this '
      'website. Focus on guide or company name, specialisations, languages '
      'spoken, service areas, certifications, and booking contact.';
}
