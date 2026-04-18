// =============================================================================
// TripDestination — one city/country entry for a trip.
// Multiple rows per trip, ordered by sort_order.
// =============================================================================

class TripDestination {
  final String id;
  final String tripId;
  final String? city;
  final String? country;
  final int sortOrder;
  final DateTime createdAt;

  const TripDestination({
    required this.id,
    required this.tripId,
    this.city,
    this.country,
    required this.sortOrder,
    required this.createdAt,
  });

  String get label {
    if (city != null && country != null) return '$city, $country';
    return city ?? country ?? '';
  }

  factory TripDestination.fromMap(Map<String, dynamic> m) => TripDestination(
        id:        m['id'] as String,
        tripId:    m['trip_id'] as String,
        city:      m['city'] as String?,
        country:   m['country'] as String?,
        sortOrder: m['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'trip_id':    tripId,
        'city':       city,
        'country':    country,
        'sort_order': sortOrder,
      };

  TripDestination copyWith({
    String? city,
    String? country,
    int? sortOrder,
  }) =>
      TripDestination(
        id:        id,
        tripId:    tripId,
        city:      city ?? this.city,
        country:   country ?? this.country,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}
