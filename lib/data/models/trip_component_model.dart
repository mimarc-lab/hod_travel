import 'package:flutter/material.dart';

// ── ComponentType ─────────────────────────────────────────────────────────────

enum ComponentType {
  accommodation,
  experience,
  dining,
  transport,
  guide,
  flight,
  train,
  yacht,
  specialArrangement,
  other;

  String get dbValue {
    switch (this) {
      case ComponentType.accommodation:      return 'accommodation';
      case ComponentType.experience:         return 'experience';
      case ComponentType.dining:             return 'dining';
      case ComponentType.transport:          return 'transport';
      case ComponentType.guide:              return 'guide';
      case ComponentType.flight:             return 'flight';
      case ComponentType.train:              return 'train';
      case ComponentType.yacht:              return 'yacht';
      case ComponentType.specialArrangement: return 'special_arrangement';
      case ComponentType.other:              return 'other';
    }
  }

  String get label {
    switch (this) {
      case ComponentType.accommodation:      return 'Accommodation';
      case ComponentType.experience:         return 'Experience';
      case ComponentType.dining:             return 'Dining';
      case ComponentType.transport:          return 'Transport';
      case ComponentType.guide:              return 'Guide';
      case ComponentType.flight:             return 'Flight';
      case ComponentType.train:              return 'Train';
      case ComponentType.yacht:              return 'Yacht';
      case ComponentType.specialArrangement: return 'Special Arrangement';
      case ComponentType.other:              return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ComponentType.accommodation:      return Icons.hotel_rounded;
      case ComponentType.experience:         return Icons.explore_rounded;
      case ComponentType.dining:             return Icons.restaurant_rounded;
      case ComponentType.transport:          return Icons.directions_car_rounded;
      case ComponentType.guide:              return Icons.person_pin_rounded;
      case ComponentType.flight:             return Icons.flight_rounded;
      case ComponentType.train:              return Icons.train_rounded;
      case ComponentType.yacht:              return Icons.sailing_rounded;
      case ComponentType.specialArrangement: return Icons.star_rounded;
      case ComponentType.other:              return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ComponentType.accommodation:      return const Color(0xFF7C3AED); // violet
      case ComponentType.experience:         return const Color(0xFF0891B2); // cyan
      case ComponentType.dining:             return const Color(0xFFEA580C); // orange
      case ComponentType.transport:          return const Color(0xFF0369A1); // blue
      case ComponentType.guide:              return const Color(0xFF059669); // green
      case ComponentType.flight:             return const Color(0xFF2563EB); // blue
      case ComponentType.train:              return const Color(0xFF7C3AED); // violet
      case ComponentType.yacht:              return const Color(0xFF0E7490); // teal
      case ComponentType.specialArrangement: return const Color(0xFFC9A96E); // gold
      case ComponentType.other:              return const Color(0xFF6B7280); // grey
    }
  }

  Color get bgColor => color.withAlpha(20);
}

ComponentType componentTypeFromDb(String v) {
  switch (v) {
    case 'accommodation':      return ComponentType.accommodation;
    case 'experience':         return ComponentType.experience;
    case 'dining':             return ComponentType.dining;
    case 'transport':          return ComponentType.transport;
    case 'guide':              return ComponentType.guide;
    case 'flight':             return ComponentType.flight;
    case 'train':              return ComponentType.train;
    case 'yacht':              return ComponentType.yacht;
    case 'special_arrangement': return ComponentType.specialArrangement;
    default:                   return ComponentType.other;
  }
}

// ── ComponentStatus ───────────────────────────────────────────────────────────

enum ComponentStatus {
  proposed,
  approved,
  confirmed,
  booked,
  cancelled;

  String get dbValue {
    switch (this) {
      case ComponentStatus.proposed:  return 'proposed';
      case ComponentStatus.approved:  return 'approved';
      case ComponentStatus.confirmed: return 'confirmed';
      case ComponentStatus.booked:    return 'booked';
      case ComponentStatus.cancelled: return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case ComponentStatus.proposed:  return 'Proposed';
      case ComponentStatus.approved:  return 'Approved';
      case ComponentStatus.confirmed: return 'Confirmed';
      case ComponentStatus.booked:    return 'Booked';
      case ComponentStatus.cancelled: return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case ComponentStatus.proposed:  return const Color(0xFF6B7280);
      case ComponentStatus.approved:  return const Color(0xFF1D4ED8);
      case ComponentStatus.confirmed: return const Color(0xFF065F46);
      case ComponentStatus.booked:    return const Color(0xFF0369A1);
      case ComponentStatus.cancelled: return const Color(0xFF991B1B);
    }
  }

  Color get bgColor {
    switch (this) {
      case ComponentStatus.proposed:  return const Color(0xFFE5E7EB);
      case ComponentStatus.approved:  return const Color(0xFFDBEAFE);
      case ComponentStatus.confirmed: return const Color(0xFFD1FAE5);
      case ComponentStatus.booked:    return const Color(0xFFE0F2FE);
      case ComponentStatus.cancelled: return const Color(0xFFFEE2E2);
    }
  }

  bool get requiresLinkingPrompt =>
      this == ComponentStatus.confirmed || this == ComponentStatus.booked;
}

ComponentStatus componentStatusFromDb(String v) {
  switch (v) {
    case 'approved':  return ComponentStatus.approved;
    case 'confirmed': return ComponentStatus.confirmed;
    case 'booked':    return ComponentStatus.booked;
    case 'cancelled': return ComponentStatus.cancelled;
    default:          return ComponentStatus.proposed;
  }
}

// ── TripComponent ─────────────────────────────────────────────────────────────

class TripComponent {
  final String id;
  final String tripId;
  final String teamId;
  final ComponentType componentType;
  final ComponentStatus status;
  final String title;
  final String? supplierId;
  final String? supplierName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final String? locationName;
  final String? address;
  final String? notesInternal;
  final String? notesClient;
  final String? costItemId;
  final String? itineraryItemId;
  final String? runSheetItemId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripComponent({
    required this.id,
    required this.tripId,
    required this.teamId,
    required this.componentType,
    required this.status,
    required this.title,
    this.supplierId,
    this.supplierName,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.locationName,
    this.address,
    this.notesInternal,
    this.notesClient,
    this.costItemId,
    this.itineraryItemId,
    this.runSheetItemId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  TripComponent copyWith({
    ComponentType? componentType,
    ComponentStatus? status,
    String? title,
    String? supplierId,
    String? supplierName,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    String? locationName,
    String? address,
    String? notesInternal,
    String? notesClient,
    String? costItemId,
    String? itineraryItemId,
    String? runSheetItemId,
  }) => TripComponent(
    id: id,
    tripId: tripId,
    teamId: teamId,
    componentType: componentType ?? this.componentType,
    status: status ?? this.status,
    title: title ?? this.title,
    supplierId: supplierId ?? this.supplierId,
    supplierName: supplierName ?? this.supplierName,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    locationName: locationName ?? this.locationName,
    address: address ?? this.address,
    notesInternal: notesInternal ?? this.notesInternal,
    notesClient: notesClient ?? this.notesClient,
    costItemId: costItemId ?? this.costItemId,
    itineraryItemId: itineraryItemId ?? this.itineraryItemId,
    runSheetItemId: runSheetItemId ?? this.runSheetItemId,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  bool get isLinkedToItinerary  => itineraryItemId != null;
  bool get isLinkedToBudget     => costItemId != null;
  bool get isLinkedToRunSheet   => runSheetItemId != null;
}
