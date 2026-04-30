import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierType — top-level taxonomy (replaces the old flat SupplierCategory)
// ─────────────────────────────────────────────────────────────────────────────

enum SupplierType {
  accommodation,
  dining,
  transport,
  guide,
  experienceProvider,
  specialistServices,
  venue,
  other;

  String get label => switch (this) {
    SupplierType.accommodation      => 'Accommodation',
    SupplierType.dining             => 'Dining',
    SupplierType.transport          => 'Transport',
    SupplierType.guide              => 'Guides',
    SupplierType.experienceProvider => 'Experience Providers',
    SupplierType.specialistServices => 'Specialist Services',
    SupplierType.venue              => 'Venues',
    SupplierType.other              => 'Other',
  };

  IconData get icon => switch (this) {
    SupplierType.accommodation      => Icons.hotel_rounded,
    SupplierType.dining             => Icons.restaurant_rounded,
    SupplierType.transport          => Icons.directions_car_rounded,
    SupplierType.guide              => Icons.person_pin_circle_outlined,
    SupplierType.experienceProvider => Icons.explore_rounded,
    SupplierType.specialistServices => Icons.support_agent_outlined,
    SupplierType.venue              => Icons.location_city_outlined,
    SupplierType.other              => Icons.category_outlined,
  };

  Color get color => switch (this) {
    SupplierType.accommodation      => const Color(0xFF7C6FAB),
    SupplierType.dining             => const Color(0xFFD4845A),
    SupplierType.transport          => const Color(0xFF4A90A4),
    SupplierType.guide              => const Color(0xFF5A9E6F),
    SupplierType.experienceProvider => const Color(0xFFC9A96E),
    SupplierType.specialistServices => const Color(0xFFB05A8A),
    SupplierType.venue              => const Color(0xFF5B8DB8),
    SupplierType.other              => const Color(0xFF8A8A8A),
  };

  String get dbValue => switch (this) {
    SupplierType.accommodation      => 'accommodation',
    SupplierType.dining             => 'dining',
    SupplierType.transport          => 'transport',
    SupplierType.guide              => 'guide',
    SupplierType.experienceProvider => 'experience_provider',
    SupplierType.specialistServices => 'specialist_services',
    SupplierType.venue              => 'venue',
    SupplierType.other              => 'other',
  };

  static SupplierType? fromDb(String? raw) => switch (raw) {
    'accommodation'       => SupplierType.accommodation,
    'dining'              => SupplierType.dining,
    'transport'           => SupplierType.transport,
    'guide'               => SupplierType.guide,
    'experience_provider' => SupplierType.experienceProvider,
    'specialist_services' => SupplierType.specialistServices,
    'venue'               => SupplierType.venue,
    'other'               => SupplierType.other,
    _                     => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier subtype options per SupplierType
// ─────────────────────────────────────────────────────────────────────────────

const Map<SupplierType, List<String>> kSupplierSubtypes = {
  SupplierType.accommodation: [
    'hotel', 'villa', 'resort', 'lodge',
  ],
  SupplierType.dining: [
    'restaurant', 'private_dining', 'catering',
  ],
  SupplierType.transport: [
    'airport_transfer', 'chauffeur', 'helicopter',
    'yacht', 'private_aviation', 'rail',
  ],
  SupplierType.guide: [
    'city_guide', 'cultural_expert', 'naturalist', 'translator',
  ],
  SupplierType.experienceProvider: [
    'diving', 'rafting', 'cultural_activity', 'adventure', 'food_experience',
  ],
  SupplierType.specialistServices: [
    'butler', 'private_chef', 'sommelier', 'mixologist',
    'host_mc', 'security', 'wellness',
  ],
  SupplierType.venue: [
    'event_venue', 'private_estate', 'ceremony_location', 'meeting_space',
  ],
  SupplierType.other: ['other'],
};

/// Display-friendly label for a subtype DB value.
String subtypeLabel(String raw) =>
    raw.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');

// ─────────────────────────────────────────────────────────────────────────────
// SupplierCategory — legacy enum kept for backward compatibility
// ─────────────────────────────────────────────────────────────────────────────

enum SupplierCategory {
  hotel,
  villa,
  guide,
  transport,
  restaurant,
  experience,
  concierge,
  other,
}

// ─────────────────────────────────────────────────────────────────────────────
// Supplier model
// ─────────────────────────────────────────────────────────────────────────────

class Supplier {
  final String id;
  final String? teamId;
  final String name;
  final SupplierCategory category;       // legacy — kept for backward compat
  final SupplierType? supplierType;      // new top-level taxonomy
  final String? supplierSubtype;         // new fine-grained classification
  final String? location;
  final String city;
  final String country;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final bool preferred;
  final double internalRating;           // 0.0–5.0
  final String? notes;
  final String? website;
  final List<String> tags;              // populated via supplier_tag_links join

  const Supplier({
    required this.id,
    this.teamId,
    required this.name,
    required this.category,
    this.supplierType,
    this.supplierSubtype,
    required this.city,
    required this.country,
    this.location,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.preferred = false,
    this.internalRating = 3.0,
    this.notes,
    this.website,
    this.tags = const [],
  });

  /// Effective supplier type — prefers the new supplierType; falls back to a
  /// mapping from the legacy category so older records still filter correctly.
  SupplierType get effectiveSupplierType =>
      supplierType ?? _categoryToType(category);

  static SupplierType _categoryToType(SupplierCategory cat) => switch (cat) {
    SupplierCategory.hotel      => SupplierType.accommodation,
    SupplierCategory.villa      => SupplierType.accommodation,
    SupplierCategory.restaurant => SupplierType.dining,
    SupplierCategory.transport  => SupplierType.transport,
    SupplierCategory.guide      => SupplierType.guide,
    SupplierCategory.experience => SupplierType.experienceProvider,
    SupplierCategory.concierge  => SupplierType.specialistServices,
    SupplierCategory.other      => SupplierType.other,
  };

  Supplier copyWith({
    String? name,
    SupplierCategory? category,
    SupplierType? supplierType,
    bool clearSupplierType = false,
    String? supplierSubtype,
    bool clearSupplierSubtype = false,
    String? location,
    bool clearLocation = false,
    String? city,
    String? country,
    String? contactName,
    bool clearContactName = false,
    String? contactEmail,
    bool clearContactEmail = false,
    String? contactPhone,
    bool clearContactPhone = false,
    bool? preferred,
    double? internalRating,
    String? notes,
    bool clearNotes = false,
    String? website,
    bool clearWebsite = false,
    List<String>? tags,
  }) {
    return Supplier(
      id:             id,
      teamId:         teamId,
      name:           name            ?? this.name,
      category:       category        ?? this.category,
      supplierType:   clearSupplierType   ? null : (supplierType   ?? this.supplierType),
      supplierSubtype: clearSupplierSubtype ? null : (supplierSubtype ?? this.supplierSubtype),
      location:       clearLocation       ? null : (location       ?? this.location),
      city:           city            ?? this.city,
      country:        country         ?? this.country,
      contactName:    clearContactName    ? null : (contactName    ?? this.contactName),
      contactEmail:   clearContactEmail   ? null : (contactEmail   ?? this.contactEmail),
      contactPhone:   clearContactPhone   ? null : (contactPhone   ?? this.contactPhone),
      preferred:      preferred       ?? this.preferred,
      internalRating: internalRating  ?? this.internalRating,
      notes:          clearNotes          ? null : (notes          ?? this.notes),
      website:        clearWebsite        ? null : (website        ?? this.website),
      tags:           tags            ?? this.tags,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy SupplierCategory display extensions
// ─────────────────────────────────────────────────────────────────────────────

extension SupplierCategoryDisplay on SupplierCategory {
  String get label {
    switch (this) {
      case SupplierCategory.hotel:      return 'Hotel';
      case SupplierCategory.villa:      return 'Villa';
      case SupplierCategory.guide:      return 'Guide';
      case SupplierCategory.transport:  return 'Transport';
      case SupplierCategory.restaurant: return 'Restaurant';
      case SupplierCategory.experience: return 'Experience';
      case SupplierCategory.concierge:  return 'Concierge';
      case SupplierCategory.other:      return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case SupplierCategory.hotel:      return Icons.hotel_rounded;
      case SupplierCategory.villa:      return Icons.villa_outlined;
      case SupplierCategory.guide:      return Icons.person_pin_circle_outlined;
      case SupplierCategory.transport:  return Icons.directions_car_outlined;
      case SupplierCategory.restaurant: return Icons.restaurant_outlined;
      case SupplierCategory.experience: return Icons.star_border_rounded;
      case SupplierCategory.concierge:  return Icons.support_agent_outlined;
      case SupplierCategory.other:      return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case SupplierCategory.hotel:      return const Color(0xFF7C6FAB);
      case SupplierCategory.villa:      return const Color(0xFFB87A5A);
      case SupplierCategory.guide:      return const Color(0xFF5A9E6F);
      case SupplierCategory.transport:  return const Color(0xFF4A90A4);
      case SupplierCategory.restaurant: return const Color(0xFFD4845A);
      case SupplierCategory.experience: return const Color(0xFFC9A96E);
      case SupplierCategory.concierge:  return const Color(0xFFB05A8A);
      case SupplierCategory.other:      return const Color(0xFF8A8A8A);
    }
  }

  String get dbValue {
    switch (this) {
      case SupplierCategory.hotel:      return 'hotel';
      case SupplierCategory.villa:      return 'villa';
      case SupplierCategory.guide:      return 'guide';
      case SupplierCategory.transport:  return 'transport';
      case SupplierCategory.restaurant: return 'restaurant';
      case SupplierCategory.experience: return 'experience';
      case SupplierCategory.concierge:  return 'concierge';
      case SupplierCategory.other:      return 'other';
    }
  }

  static SupplierCategory fromDb(String raw) => switch (raw) {
    'hotel'      => SupplierCategory.hotel,
    'villa'      => SupplierCategory.villa,
    'guide'      => SupplierCategory.guide,
    'transport'  => SupplierCategory.transport,
    'restaurant' => SupplierCategory.restaurant,
    'experience' => SupplierCategory.experience,
    'concierge'  => SupplierCategory.concierge,
    _            => SupplierCategory.other,
  };
}
