import 'user_model.dart';

// DB values: planning | confirmed | in_progress | completed | cancelled
enum TripStatus { planning, confirmed, inProgress, completed, cancelled }

extension TripStatusLabel on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.planning:   return 'Planning';
      case TripStatus.confirmed:  return 'Confirmed';
      case TripStatus.inProgress: return 'In Progress';
      case TripStatus.completed:  return 'Completed';
      case TripStatus.cancelled:  return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case TripStatus.planning:   return 'planning';
      case TripStatus.confirmed:  return 'confirmed';
      case TripStatus.inProgress: return 'in_progress';
      case TripStatus.completed:  return 'completed';
      case TripStatus.cancelled:  return 'cancelled';
    }
  }

  static TripStatus fromDb(String raw) => switch (raw) {
    'confirmed'   => TripStatus.confirmed,
    'in_progress' => TripStatus.inProgress,
    'completed'   => TripStatus.completed,
    'cancelled'   => TripStatus.cancelled,
    _             => TripStatus.planning,
  };
}

class Trip {
  final String id;
  final String? teamId;
  final String name;
  final String clientName;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> destinations;
  final int guestCount;
  final AppUser tripLead;
  final TripStatus status;
  final String? notes;
  final String? dossierId;

  const Trip({
    required this.id,
    this.teamId,
    required this.name,
    required this.clientName,
    this.startDate,
    this.endDate,
    required this.destinations,
    required this.guestCount,
    required this.tripLead,
    required this.status,
    this.notes,
    this.dossierId,
  });

  String get destinationSummary => destinations.join(' · ');

  Trip copyWith({
    String? teamId,
    String? name,
    String? clientName,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    List<String>? destinations,
    int? guestCount,
    AppUser? tripLead,
    TripStatus? status,
    String? notes,
    bool clearNotes = false,
    String? dossierId,
    bool clearDossierId = false,
  }) {
    return Trip(
      id:           id,
      teamId:       teamId       ?? this.teamId,
      name:         name         ?? this.name,
      clientName:   clientName   ?? this.clientName,
      startDate:    clearStartDate ? null : (startDate ?? this.startDate),
      endDate:      clearEndDate   ? null : (endDate   ?? this.endDate),
      destinations: destinations  ?? this.destinations,
      guestCount:   guestCount    ?? this.guestCount,
      tripLead:     tripLead      ?? this.tripLead,
      status:       status        ?? this.status,
      notes:        clearNotes    ? null : (notes ?? this.notes),
      dossierId:    clearDossierId ? null : (dossierId ?? this.dossierId),
    );
  }
}
