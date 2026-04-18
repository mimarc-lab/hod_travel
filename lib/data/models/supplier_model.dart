import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
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
  final SupplierCategory category;
  final String? location;
  final String city;
  final String country;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final bool preferred;
  final double internalRating; // 0.0–5.0
  final String? notes;
  final String? website;
  final List<String> tags;     // populated via supplier_tag_links join

  const Supplier({
    required this.id,
    this.teamId,
    required this.name,
    required this.category,
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

  Supplier copyWith({
    String? name,
    SupplierCategory? category,
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
      location:       clearLocation       ? null : (location   ?? this.location),
      city:           city            ?? this.city,
      country:        country         ?? this.country,
      contactName:    clearContactName    ? null : (contactName  ?? this.contactName),
      contactEmail:   clearContactEmail   ? null : (contactEmail ?? this.contactEmail),
      contactPhone:   clearContactPhone   ? null : (contactPhone ?? this.contactPhone),
      preferred:      preferred       ?? this.preferred,
      internalRating: internalRating  ?? this.internalRating,
      notes:          clearNotes          ? null : (notes  ?? this.notes),
      website:        clearWebsite        ? null : (website ?? this.website),
      tags:           tags            ?? this.tags,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Display extensions
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
