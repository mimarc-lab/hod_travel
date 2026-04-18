import 'package:flutter/material.dart';
import 'supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierEnrichment — intermediate model between Firecrawl result and Supplier
//
// Not a Supplier — it's the raw extracted data before the user reviews and
// decides whether to create a new supplier or merge into an existing one.
// ─────────────────────────────────────────────────────────────────────────────

class SupplierEnrichment {
  final String sourceUrl;
  final String sourceDomain;

  // ── Core identity ──────────────────────────────────────────────────────────

  final String? name;
  final SupplierCategory? category;
  final String? propertyType; // raw string from extraction (hotel, villa, lodge…)
  final String? shortSummary;

  // ── Location ───────────────────────────────────────────────────────────────

  final String? city;
  final String? regionOrState;
  final String? country;
  final String? location; // full address
  final double? latitude;
  final double? longitude;

  // ── Contact ────────────────────────────────────────────────────────────────

  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? whatsapp;
  final String? website;

  // ── Accommodation capacity ─────────────────────────────────────────────────

  final int? numberOfRooms;
  final int? numberOfSuites;
  final int? numberOfVillas;
  final List<String> bedroomConfigurations;
  final List<String> roomTypes;
  final String? maxOccupancy;

  // ── Family & children ──────────────────────────────────────────────────────

  final bool? familyFriendly;
  final String? childrenPolicy;

  // ── Food & beverage ────────────────────────────────────────────────────────

  final List<String> diningOutlets;

  // ── Wellness & facilities ──────────────────────────────────────────────────

  final bool? spa;
  final List<String> wellnessFeatures;
  final bool? pool;
  final bool? beachAccess;
  final bool? skiAccess;

  // ── Activities & amenities ─────────────────────────────────────────────────

  final List<String> activitiesOnSite;
  final List<String> highlights; // key selling points / notable amenities
  final List<String> accessibilityFeatures;
  final List<String> tags;

  // ── Experience / activity fields ───────────────────────────────────────────
  // Populated when the extraction schema is ExtractionSchema.experience.

  final String? duration;
  final String? recommendedTimeOfDay;
  final String? privateOrShared;
  final int? minimumGuests;
  final int? maximumGuests;
  final String? ageRestrictions;
  final String? physicalDifficulty;
  final String? accessibilityNotes;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<String> languagesAvailable;
  final List<String> operatingDays;
  final List<String> startTimes;
  final bool? pickupAvailable;
  final bool? transferIncluded;
  final bool? weatherDependency;

  // ── Operations ────────────────────────────────────────────────────────────

  final bool? airportTransferAvailable;
  final String? checkInTime;
  final String? checkOutTime;
  final String? cancellationPolicy;

  // ── Pricing ────────────────────────────────────────────────────────────────

  final String? pricingText;
  final String? currency;

  // ── Media ─────────────────────────────────────────────────────────────────

  final List<String> imageUrls;
  final List<String> brochureUrls;

  // ── Legacy / raw content ───────────────────────────────────────────────────

  /// Long-form description / notes (maps to Supplier.notes)
  final String? summary;

  /// Raw markdown content from a scrape (used if extract was not run)
  final String? rawMarkdown;

  // ── Extraction metadata ────────────────────────────────────────────────────

  final List<String> sourcePagesUsed;
  final String? extractionNotes;

  /// 0.0–1.0 completeness estimate
  final double completeness;

  const SupplierEnrichment({
    required this.sourceUrl,
    required this.sourceDomain,
    this.name,
    this.category,
    this.propertyType,
    this.shortSummary,
    this.city,
    this.regionOrState,
    this.country,
    this.location,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.whatsapp,
    this.website,
    this.numberOfRooms,
    this.numberOfSuites,
    this.numberOfVillas,
    this.bedroomConfigurations = const [],
    this.roomTypes = const [],
    this.maxOccupancy,
    this.familyFriendly,
    this.childrenPolicy,
    this.diningOutlets = const [],
    this.spa,
    this.wellnessFeatures = const [],
    this.pool,
    this.beachAccess,
    this.skiAccess,
    this.activitiesOnSite = const [],
    this.highlights = const [],
    this.accessibilityFeatures = const [],
    this.tags = const [],
    this.airportTransferAvailable,
    this.checkInTime,
    this.checkOutTime,
    this.cancellationPolicy,
    this.pricingText,
    this.currency,
    this.imageUrls = const [],
    this.brochureUrls = const [],
    // Experience fields
    this.duration,
    this.recommendedTimeOfDay,
    this.privateOrShared,
    this.minimumGuests,
    this.maximumGuests,
    this.ageRestrictions,
    this.physicalDifficulty,
    this.accessibilityNotes,
    this.inclusions = const [],
    this.exclusions = const [],
    this.languagesAvailable = const [],
    this.operatingDays = const [],
    this.startTimes = const [],
    this.pickupAvailable,
    this.transferIncluded,
    this.weatherDependency,
    // Legacy / raw
    this.summary,
    this.rawMarkdown,
    this.sourcePagesUsed = const [],
    this.extractionNotes,
    this.completeness = 0,
  });

  // ── toSupplierDraft ────────────────────────────────────────────────────────

  /// Convert to a Supplier draft. Returns null if name is missing.
  Supplier? toSupplierDraft(String id) {
    final n = name;
    if (n == null || n.isEmpty) return null;

    final noteParts = <String>[
      if (shortSummary != null && shortSummary!.isNotEmpty) shortSummary!,
      if (summary != null && summary!.isNotEmpty) summary!,
      // Accommodation fields
      if (pricingText != null) 'Pricing: $pricingText',
      if (checkInTime != null || checkOutTime != null)
        'Check-in: ${checkInTime ?? '—'}  Check-out: ${checkOutTime ?? '—'}',
      if (cancellationPolicy != null) 'Cancellation: $cancellationPolicy',
      if (childrenPolicy != null) 'Children policy: $childrenPolicy',
      if (highlights.isNotEmpty) 'Highlights: ${highlights.join(', ')}',
      if (diningOutlets.isNotEmpty) 'Dining: ${diningOutlets.join(', ')}',
      if (activitiesOnSite.isNotEmpty)
        'Activities: ${activitiesOnSite.join(', ')}',
      // Experience fields
      if (duration != null) 'Duration: $duration',
      if (privateOrShared != null) 'Format: $privateOrShared',
      if (minimumGuests != null || maximumGuests != null)
        'Guests: ${minimumGuests ?? 1}–${maximumGuests ?? '?'}',
      if (physicalDifficulty != null) 'Physical difficulty: $physicalDifficulty',
      if (ageRestrictions != null) 'Age restrictions: $ageRestrictions',
      if (inclusions.isNotEmpty) 'Includes: ${inclusions.join(', ')}',
      if (exclusions.isNotEmpty) 'Excludes: ${exclusions.join(', ')}',
      if (languagesAvailable.isNotEmpty)
        'Languages: ${languagesAvailable.join(', ')}',
      if (operatingDays.isNotEmpty) 'Operating days: ${operatingDays.join(', ')}',
      if (extractionNotes != null) 'Note: $extractionNotes',
      'Imported from: $sourceDomain',
    ];

    return Supplier(
      id: id,
      name: n,
      category: category ?? SupplierCategory.other,
      city: city ?? '',
      country: country ?? '',
      location: location,
      contactName: contactName,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      website: website ?? sourceUrl,
      notes: noteParts.isEmpty ? null : noteParts.join('\n\n'),
      tags: tags,
    );
  }

  // ── Completeness ───────────────────────────────────────────────────────────

  /// Number of non-null/non-empty fields present.
  int get filledFieldCount {
    int n = 0;
    if (name?.isNotEmpty == true) n++;
    if (category != null) n++;
    if (city?.isNotEmpty == true) n++;
    if (country?.isNotEmpty == true) n++;
    if (location?.isNotEmpty == true) n++;
    if (regionOrState?.isNotEmpty == true) n++;
    if (contactName?.isNotEmpty == true) n++;
    if (contactEmail?.isNotEmpty == true) n++;
    if (contactPhone?.isNotEmpty == true) n++;
    if (website?.isNotEmpty == true) n++;
    if (summary?.isNotEmpty == true || shortSummary?.isNotEmpty == true) n++;
    if (highlights.isNotEmpty) n++;
    if (tags.isNotEmpty) n++;
    if (numberOfRooms != null) n++;
    if (roomTypes.isNotEmpty) n++;
    if (diningOutlets.isNotEmpty) n++;
    if (spa != null) n++;
    if (pool != null) n++;
    if (activitiesOnSite.isNotEmpty) n++;
    if (pricingText?.isNotEmpty == true) n++;
    if (imageUrls.isNotEmpty) n++;
    // Experience fields
    if (duration?.isNotEmpty == true) n++;
    if (privateOrShared?.isNotEmpty == true) n++;
    if (minimumGuests != null || maximumGuests != null) n++;
    if (inclusions.isNotEmpty) n++;
    if (exclusions.isNotEmpty) n++;
    if (languagesAvailable.isNotEmpty) n++;
    return n;
  }

  /// Human-readable completeness label.
  String get completenessLabel {
    if (completeness >= 0.75) return 'Rich';
    if (completeness >= 0.45) return 'Partial';
    if (completeness >= 0.15) return 'Minimal';
    return 'Sparse';
  }

  Color get completenessColor {
    if (completeness >= 0.75) return const Color(0xFF065F46);
    if (completeness >= 0.45) return const Color(0xFF92400E);
    if (completeness >= 0.15) return const Color(0xFF6B7280);
    return const Color(0xFF9CA3AF);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentEvent — lightweight audit trail entry
// ─────────────────────────────────────────────────────────────────────────────

enum EnrichmentEventType {
  importedFromUrl,
  enrichedExisting,
  searchDiscovery,
  discarded,
}

extension EnrichmentEventTypeLabel on EnrichmentEventType {
  String get label {
    switch (this) {
      case EnrichmentEventType.importedFromUrl:  return 'Imported from URL';
      case EnrichmentEventType.enrichedExisting: return 'Enriched existing record';
      case EnrichmentEventType.searchDiscovery:  return 'Found via search';
      case EnrichmentEventType.discarded:        return 'Discarded';
    }
  }

  IconData get icon {
    switch (this) {
      case EnrichmentEventType.importedFromUrl:  return Icons.link_rounded;
      case EnrichmentEventType.enrichedExisting: return Icons.auto_fix_high_rounded;
      case EnrichmentEventType.searchDiscovery:  return Icons.search_rounded;
      case EnrichmentEventType.discarded:        return Icons.delete_outline_rounded;
    }
  }
}

class EnrichmentEvent {
  final String id;
  final EnrichmentEventType type;
  final String sourceUrl;
  final String sourceDomain;
  final String? supplierName;
  final String? supplierId;
  final DateTime createdAt;

  const EnrichmentEvent({
    required this.id,
    required this.type,
    required this.sourceUrl,
    required this.sourceDomain,
    this.supplierName,
    this.supplierId,
    required this.createdAt,
  });
}
