import '../../data/models/supplier_enrichment_model.dart';
import '../../data/models/supplier_model.dart';
import 'firecrawl_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExtractionMapper — converts raw Firecrawl results into a SupplierEnrichment.
// Kept separate from both the service and the UI.
// ─────────────────────────────────────────────────────────────────────────────

class ExtractionMapper {
  /// Map a structured accommodation extract result to a SupplierEnrichment.
  static SupplierEnrichment fromExtract(FirecrawlExtractResult result) {
    final f = result.fields;
    final name    = result.string('property_name');
    final city    = result.string('city');
    final country = result.string('country');
    final rawType = result.string('property_type');

    return SupplierEnrichment(
      sourceUrl:    result.url,
      sourceDomain: _domain(result.url),

      // Identity
      name:         name,
      category:     _mapAccommodationCategory(rawType),
      propertyType: rawType,
      shortSummary: result.string('short_summary'),

      // Location
      city:          city,
      regionOrState: result.string('region_or_state'),
      country:       country,
      location:      result.string('address'),
      latitude:      result.doubleField('latitude'),
      longitude:     result.doubleField('longitude'),

      // Contact
      website:      result.string('website_url') ?? result.url,
      contactName:  result.string('contact_name'),
      contactEmail: result.string('contact_email'),
      contactPhone: result.string('contact_phone'),
      whatsapp:     result.string('whatsapp'),

      // Capacity
      numberOfRooms:         result.intField('number_of_rooms'),
      numberOfSuites:        result.intField('number_of_suites'),
      numberOfVillas:        result.intField('number_of_villas'),
      bedroomConfigurations: result.stringList('bedroom_configurations'),
      roomTypes:             result.stringList('room_types'),
      maxOccupancy:          result.string('max_occupancy'),

      // Family
      familyFriendly: result.boolField('family_friendly'),
      childrenPolicy: result.string('children_policy'),

      // Dining
      diningOutlets: result.stringList('dining_outlets'),

      // Wellness & facilities
      spa:              result.boolField('spa'),
      wellnessFeatures: result.stringList('wellness_features'),
      pool:             result.boolField('pool'),
      beachAccess:      result.boolField('beach_access'),
      skiAccess:        result.boolField('ski_access'),

      // Activities & highlights
      activitiesOnSite:      result.stringList('activities_on_site'),
      highlights:            result.stringList('notable_amenities'),
      accessibilityFeatures: result.stringList('accessibility_features'),
      tags:                  result.stringList('tags'),

      // Operations
      airportTransferAvailable: result.boolField('airport_transfer_available'),
      checkInTime:              result.string('check_in_time'),
      checkOutTime:             result.string('check_out_time'),
      cancellationPolicy:       result.string('cancellation_policy'),

      // Pricing
      pricingText: result.string('pricing_text'),
      currency:    result.string('currency'),

      // Media
      imageUrls:    result.stringList('image_urls'),
      brochureUrls: result.stringList('brochure_urls'),

      // Extraction metadata
      sourcePagesUsed: result.stringList('source_pages_used'),
      extractionNotes: result.string('extraction_notes'),

      completeness: _scoreCompleteness(f, _accommodationFields),
    );
  }

  /// Map a structured experience extract result to a SupplierEnrichment.
  static SupplierEnrichment fromExperienceExtract(
      FirecrawlExtractResult result) {
    final f = result.fields;
    final name    = result.string('experience_name') ?? result.string('provider_name');
    final city    = result.string('destination_city');
    final country = result.string('destination_country');

    return SupplierEnrichment(
      sourceUrl:    result.url,
      sourceDomain: _domain(result.url),

      // Identity
      name:         name,
      category:     _mapExperienceCategory(result.string('category')),
      propertyType: result.string('category'),
      shortSummary: result.string('short_summary'),

      // Location (experience uses destination_* prefix)
      city:          city,
      regionOrState: result.string('destination_region'),
      country:       country,
      location:      result.string('exact_location'),

      // Contact / provider
      website:      result.string('provider_website') ?? result.url,
      contactName:  result.string('contact_name'),
      contactEmail: result.string('contact_email'),
      contactPhone: result.string('contact_phone'),

      // Tags & media
      tags:      result.stringList('tags'),
      imageUrls: result.stringList('image_urls'),

      // Extraction metadata
      sourcePagesUsed: result.stringList('source_pages_used'),
      extractionNotes: result.string('extraction_notes'),

      // Pricing & cancellation
      pricingText:        result.string('pricing_text'),
      currency:           result.string('currency'),
      cancellationPolicy: result.string('cancellation_policy'),

      // Experience-specific
      duration:             result.string('duration'),
      recommendedTimeOfDay: result.string('recommended_time_of_day'),
      privateOrShared:      result.string('private_or_shared'),
      minimumGuests:        result.intField('minimum_guests'),
      maximumGuests:        result.intField('maximum_guests'),
      ageRestrictions:      result.string('age_restrictions'),
      familyFriendly:       result.boolField('child_friendly'),
      physicalDifficulty:   result.string('physical_difficulty'),
      accessibilityNotes:   result.string('accessibility_notes'),
      inclusions:           result.stringList('inclusions'),
      exclusions:           result.stringList('exclusions'),
      languagesAvailable:   result.stringList('languages_available'),
      operatingDays:        result.stringList('operating_days'),
      startTimes:           result.stringList('start_times'),
      pickupAvailable:      result.boolField('pickup_available'),
      transferIncluded:     result.boolField('transfer_included'),
      weatherDependency:    result.boolField('weather_dependency'),

      completeness: _scoreCompleteness(f, _experienceFields),
    );
  }

  /// Map a scrape result (markdown) to a partial SupplierEnrichment.
  /// Less structured — only metadata fields are reliable.
  static SupplierEnrichment fromScrape(FirecrawlScrapeResult result) {
    return SupplierEnrichment(
      sourceUrl:    result.url,
      sourceDomain: _domain(result.url),
      name:         result.title,
      summary:      result.description,
      website:      result.url,
      rawMarkdown:  result.markdownContent,
      completeness: result.title != null ? 0.2 : 0.05,
    );
  }

  // ── Completeness scoring ───────────────────────────────────────────────────

  /// Counts present fields and returns a 0.0–1.0 completeness score.
  /// A field is considered present when it is non-null and non-empty.
  static double _scoreCompleteness(
      Map<String, dynamic> f, List<String> fields) {
    var filled = 0;
    for (final k in fields) {
      final v = f[k];
      if (v == null) continue;
      if (v is bool || v is num) {
        filled++;
      } else if (v is String && v.isNotEmpty) {
        filled++;
      } else if (v is List && v.isNotEmpty) {
        filled++;
      }
    }
    return fields.isEmpty ? 0 : filled / fields.length;
  }

  // Fields used for accommodation completeness scoring.
  static const _accommodationFields = [
    'property_name', 'property_type', 'city', 'country', 'short_summary',
    'contact_name', 'contact_email', 'contact_phone',
    'region_or_state', 'address',
    'number_of_rooms', 'room_types', 'spa', 'pool', 'beach_access',
    'notable_amenities', 'activities_on_site', 'dining_outlets',
    'tags', 'pricing_text', 'image_urls',
  ];

  // Fields used for experience completeness scoring.
  static const _experienceFields = [
    'experience_name', 'category', 'destination_city',
    'destination_country', 'short_summary',
    'contact_name', 'contact_email', 'contact_phone',
    'duration', 'private_or_shared', 'maximum_guests',
    'operating_days', 'start_times',
    'inclusions', 'exclusions', 'tags', 'image_urls',
    'pricing_text', 'cancellation_policy',
  ];

  // ── Category mapping ───────────────────────────────────────────────────────

  static SupplierCategory? _mapAccommodationCategory(String? raw) {
    if (raw == null) return null;
    switch (raw.toLowerCase().trim()) {
      case 'hotel':
      case 'resort':
      case 'lodge':
      case 'camp':
      case 'safari camp':
      case 'tented camp':
        // Camps and lodges are accommodation, not experiences
        return SupplierCategory.hotel;
      case 'villa':
      case 'private home':
      case 'apartment':
        return SupplierCategory.villa;
      case 'guide':
        return SupplierCategory.guide;
      case 'transport':
        return SupplierCategory.transport;
      case 'restaurant':
        return SupplierCategory.restaurant;
      case 'experience':
        return SupplierCategory.experience;
      case 'concierge':
        return SupplierCategory.concierge;
      default:
        return SupplierCategory.other;
    }
  }

  static SupplierCategory? _mapExperienceCategory(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase().trim();
    if (s.contains('safari') || s.contains('wildlife') || s.contains('game')) {
      return SupplierCategory.experience;
    }
    if (s.contains('transport') || s.contains('helicopter') ||
        s.contains('charter') || s.contains('yacht')) {
      return SupplierCategory.transport;
    }
    if (s.contains('cooking') || s.contains('restaurant') ||
        s.contains('dining') || s.contains('food')) {
      return SupplierCategory.restaurant;
    }
    if (s.contains('guide') || s.contains('tour')) {
      return SupplierCategory.guide;
    }
    return SupplierCategory.experience;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
