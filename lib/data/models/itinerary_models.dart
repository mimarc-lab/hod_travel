import 'package:flutter/material.dart';
import 'approval_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ItemType { hotel, experience, transport, dining, note, flight }

enum TimeBlock { morning, afternoon, evening, allDay }

enum ItemStatus { draft, approved, confirmed }

// ─────────────────────────────────────────────────────────────────────────────
// TripDay
// ─────────────────────────────────────────────────────────────────────────────

class TripDay {
  final String id;
  final String tripId;
  final String? teamId;
  final int dayNumber;
  final DateTime? date;   // nullable in schema
  final String city;
  final String? title;    // optional heading for the day
  final String? label;    // short sub-label (kept for backward compat)

  const TripDay({
    required this.id,
    required this.tripId,
    this.teamId,
    required this.dayNumber,
    this.date,
    required this.city,
    this.title,
    this.label,
  });

  TripDay copyWith({
    String? city,
    DateTime? date,
    bool clearDate = false,
    String? title,
    bool clearTitle = false,
    String? label,
    bool clearLabel = false,
  }) {
    return TripDay(
      id:        id,
      tripId:    tripId,
      teamId:    teamId,
      dayNumber: dayNumber,
      date:      clearDate ? null : (date ?? this.date),
      city:      city  ?? this.city,
      title:     clearTitle ? null : (title ?? this.title),
      label:     clearLabel ? null : (label ?? this.label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ItineraryItem
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryItem {
  final String id;
  final String tripDayId;
  final String? teamId;
  final ItemType type;
  final String title;
  final String? description;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final TimeBlock timeBlock;
  final String? location;
  final String? supplierId;    // FK → suppliers.id
  final String? supplierName;  // display-only, populated from join
  final ItemStatus status;
  final ApprovalStatus approvalStatus;
  final String? linkedTaskId;
  final String? notes;
  final double? latitude;
  final double? longitude;

  const ItineraryItem({
    required this.id,
    required this.tripDayId,
    this.teamId,
    required this.type,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    required this.timeBlock,
    this.location,
    this.supplierId,
    this.supplierName,
    required this.status,
    this.approvalStatus = ApprovalStatus.draft,
    this.linkedTaskId,
    this.notes,
    this.latitude,
    this.longitude,
  });

  ItineraryItem copyWith({
    ItemType? type,
    String? title,
    String? description,
    bool clearDescription = false,
    TimeOfDay? startTime,
    bool clearStartTime = false,
    TimeOfDay? endTime,
    bool clearEndTime = false,
    TimeBlock? timeBlock,
    String? location,
    bool clearLocation = false,
    String? supplierId,
    bool clearSupplierId = false,
    String? supplierName,
    bool clearSupplierName = false,
    ItemStatus? status,
    ApprovalStatus? approvalStatus,
    String? notes,
    bool clearNotes = false,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
  }) {
    return ItineraryItem(
      id:           id,
      tripDayId:    tripDayId,
      teamId:       teamId,
      type:         type          ?? this.type,
      title:        title         ?? this.title,
      description:  clearDescription  ? null : (description  ?? this.description),
      startTime:    clearStartTime    ? null : (startTime    ?? this.startTime),
      endTime:      clearEndTime      ? null : (endTime      ?? this.endTime),
      timeBlock:    timeBlock     ?? this.timeBlock,
      location:     clearLocation     ? null : (location     ?? this.location),
      supplierId:   clearSupplierId   ? null : (supplierId   ?? this.supplierId),
      supplierName: clearSupplierName ? null : (supplierName ?? this.supplierName),
      status:       status        ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      linkedTaskId: linkedTaskId,
      notes:        clearNotes        ? null : (notes        ?? this.notes),
      latitude:     clearLatitude     ? null : (latitude     ?? this.latitude),
      longitude:    clearLongitude    ? null : (longitude    ?? this.longitude),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Display helpers
// ─────────────────────────────────────────────────────────────────────────────

extension ItemTypeLabel on ItemType {
  String get label {
    switch (this) {
      case ItemType.hotel:      return 'Hotel';
      case ItemType.experience: return 'Experience';
      case ItemType.transport:  return 'Transport';
      case ItemType.dining:     return 'Dining';
      case ItemType.note:       return 'Note';
      case ItemType.flight:     return 'Flight';
    }
  }

  IconData get icon {
    switch (this) {
      case ItemType.hotel:      return Icons.hotel_rounded;
      case ItemType.experience: return Icons.star_border_rounded;
      case ItemType.transport:  return Icons.directions_car_outlined;
      case ItemType.dining:     return Icons.restaurant_outlined;
      case ItemType.note:       return Icons.note_outlined;
      case ItemType.flight:     return Icons.flight_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ItemType.hotel:      return const Color(0xFF7C6FAB);
      case ItemType.experience: return const Color(0xFFC9A96E);
      case ItemType.transport:  return const Color(0xFF4A90A4);
      case ItemType.dining:     return const Color(0xFFD4845A);
      case ItemType.note:       return const Color(0xFF8EA67B);
      case ItemType.flight:     return const Color(0xFF5B8DB8);
    }
  }

  String get dbValue {
    switch (this) {
      case ItemType.hotel:      return 'hotel';
      case ItemType.experience: return 'experience';
      case ItemType.transport:  return 'transport';
      case ItemType.dining:     return 'dining';
      case ItemType.note:       return 'note';
      case ItemType.flight:     return 'flight';
    }
  }

  static ItemType fromDb(String raw) => switch (raw) {
    'hotel'      => ItemType.hotel,
    'experience' => ItemType.experience,
    'transport'  => ItemType.transport,
    'dining'     => ItemType.dining,
    'flight'     => ItemType.flight,
    _            => ItemType.note,
  };
}

extension TimeBlockLabel on TimeBlock {
  String get label {
    switch (this) {
      case TimeBlock.morning:   return 'Morning';
      case TimeBlock.afternoon: return 'Afternoon';
      case TimeBlock.evening:   return 'Evening';
      case TimeBlock.allDay:    return 'All Day';
    }
  }

  String get dbValue {
    switch (this) {
      case TimeBlock.morning:   return 'morning';
      case TimeBlock.afternoon: return 'afternoon';
      case TimeBlock.evening:   return 'evening';
      case TimeBlock.allDay:    return 'custom';
    }
  }

  static TimeBlock fromDb(String raw) => switch (raw) {
    'afternoon' => TimeBlock.afternoon,
    'evening'   => TimeBlock.evening,
    'custom'    => TimeBlock.allDay,
    _           => TimeBlock.morning,
  };
}

extension ItemStatusLabel on ItemStatus {
  String get label {
    switch (this) {
      case ItemStatus.draft:     return 'Draft';
      case ItemStatus.approved:  return 'Approved';
      case ItemStatus.confirmed: return 'Confirmed';
    }
  }

  Color get color {
    switch (this) {
      case ItemStatus.draft:     return const Color(0xFF9E9E9E);
      case ItemStatus.approved:  return const Color(0xFF4A90A4);
      case ItemStatus.confirmed: return const Color(0xFF5A9E6F);
    }
  }

  String get dbValue {
    switch (this) {
      case ItemStatus.draft:     return 'draft';
      case ItemStatus.approved:  return 'approved';
      case ItemStatus.confirmed: return 'confirmed';
    }
  }

  static ItemStatus fromDb(String raw) => switch (raw) {
    'approved'  => ItemStatus.approved,
    'confirmed' => ItemStatus.confirmed,
    _           => ItemStatus.draft,
  };
}
