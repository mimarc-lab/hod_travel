import 'client_traveler_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums — all carry dbValue, label, and fromDb factory
// ─────────────────────────────────────────────────────────────────────────────

enum TripType {
  family, executive, multigenerational, couple, group, solo, other;

  String get label => switch (this) {
    TripType.family            => 'Family',
    TripType.executive         => 'Executive',
    TripType.multigenerational => 'Multigenerational',
    TripType.couple            => 'Couple',
    TripType.group             => 'Group',
    TripType.solo              => 'Solo',
    TripType.other             => 'Other',
  };

  String get dbValue => switch (this) {
    TripType.multigenerational => 'multigenerational',
    _ => name,
  };

  static TripType? fromDb(String? v) => v == null ? null :
    TripType.values.firstWhere((e) => e.dbValue == v, orElse: () => TripType.other);
}

enum PacingPreference {
  slow, balanced, full;

  String get label => switch (this) {
    PacingPreference.slow     => 'Slow — fewer activities, deeper immersion',
    PacingPreference.balanced => 'Balanced',
    PacingPreference.full     => 'Full — maximum experiences daily',
  };

  String get dbValue => name;

  static PacingPreference? fromDb(String? v) => v == null ? null :
    PacingPreference.values.firstWhere((e) => e.dbValue == v, orElse: () => PacingPreference.balanced);
}

enum PrivacyPreference {
  veryPrivate, standard, social;

  String get label => switch (this) {
    PrivacyPreference.veryPrivate => 'Very Private',
    PrivacyPreference.standard    => 'Standard',
    PrivacyPreference.social      => 'Social',
  };

  String get dbValue => switch (this) {
    PrivacyPreference.veryPrivate => 'very_private',
    PrivacyPreference.standard    => 'standard',
    PrivacyPreference.social      => 'social',
  };

  static PrivacyPreference? fromDb(String? v) => v == null ? null :
    PrivacyPreference.values.firstWhere((e) => e.dbValue == v, orElse: () => PrivacyPreference.standard);
}

enum LuxuryLevel {
  ultra, high, comfortable;

  String get label => switch (this) {
    LuxuryLevel.ultra       => 'Ultra Luxury',
    LuxuryLevel.high        => 'High End',
    LuxuryLevel.comfortable => 'Comfortable',
  };

  String get dbValue => name;

  static LuxuryLevel? fromDb(String? v) => v == null ? null :
    LuxuryLevel.values.firstWhere((e) => e.dbValue == v, orElse: () => LuxuryLevel.high);
}

enum GuidePreference {
  privateOnly, smallGroupOk, flexible;

  String get label => switch (this) {
    GuidePreference.privateOnly  => 'Private Only',
    GuidePreference.smallGroupOk => 'Small Group OK',
    GuidePreference.flexible     => 'Flexible',
  };

  String get dbValue => switch (this) {
    GuidePreference.privateOnly  => 'private_only',
    GuidePreference.smallGroupOk => 'small_group_ok',
    GuidePreference.flexible     => 'flexible',
  };

  static GuidePreference? fromDb(String? v) => v == null ? null :
    GuidePreference.values.firstWhere((e) => e.dbValue == v, orElse: () => GuidePreference.flexible);
}

enum StructurePreference {
  highlyStructured, balanced, flexible;

  String get label => switch (this) {
    StructurePreference.highlyStructured => 'Highly Structured',
    StructurePreference.balanced         => 'Balanced',
    StructurePreference.flexible         => 'Flexible / Spontaneous',
  };

  String get dbValue => switch (this) {
    StructurePreference.highlyStructured => 'highly_structured',
    StructurePreference.balanced         => 'balanced',
    StructurePreference.flexible         => 'flexible',
  };

  static StructurePreference? fromDb(String? v) => v == null ? null :
    StructurePreference.values.firstWhere((e) => e.dbValue == v, orElse: () => StructurePreference.balanced);
}

enum AccommodationType {
  hotel, villa, mixed;

  String get label => switch (this) {
    AccommodationType.hotel => 'Hotel',
    AccommodationType.villa => 'Villa / Private Residence',
    AccommodationType.mixed => 'Mixed',
  };

  String get dbValue => name;

  static AccommodationType? fromDb(String? v) => v == null ? null :
    AccommodationType.values.firstWhere((e) => e.dbValue == v, orElse: () => AccommodationType.hotel);
}

enum DiningStyle {
  fineDining, casual, mixed;

  String get label => switch (this) {
    DiningStyle.fineDining => 'Fine Dining Preferred',
    DiningStyle.casual     => 'Casual & Relaxed',
    DiningStyle.mixed      => 'Mixed',
  };

  String get dbValue => switch (this) {
    DiningStyle.fineDining => 'fine_dining',
    DiningStyle.casual     => 'casual',
    DiningStyle.mixed      => 'mixed',
  };

  static DiningStyle? fromDb(String? v) => v == null ? null :
    DiningStyle.values.firstWhere((e) => e.dbValue == v, orElse: () => DiningStyle.mixed);
}

enum WellnessImportance {
  essential, preferred, notImportant;

  String get label => switch (this) {
    WellnessImportance.essential    => 'Essential',
    WellnessImportance.preferred    => 'Preferred',
    WellnessImportance.notImportant => 'Not a Priority',
  };

  String get dbValue => switch (this) {
    WellnessImportance.essential    => 'essential',
    WellnessImportance.preferred    => 'preferred',
    WellnessImportance.notImportant => 'not_important',
  };

  static WellnessImportance? fromDb(String? v) => v == null ? null :
    WellnessImportance.values.firstWhere((e) => e.dbValue == v, orElse: () => WellnessImportance.preferred);
}

enum HeatTolerance {
  low, medium, high;

  String get label => switch (this) {
    HeatTolerance.low    => 'Low — prefers cool climates',
    HeatTolerance.medium => 'Medium',
    HeatTolerance.high   => 'High — comfortable in heat',
  };

  String get dbValue => name;

  static HeatTolerance? fromDb(String? v) => v == null ? null :
    HeatTolerance.values.firstWhere((e) => e.dbValue == v, orElse: () => HeatTolerance.medium);
}

enum WalkingTolerance {
  limited, moderate, extensive;

  String get label => switch (this) {
    WalkingTolerance.limited   => 'Limited',
    WalkingTolerance.moderate  => 'Moderate',
    WalkingTolerance.extensive => 'Extensive',
  };

  String get dbValue => name;

  static WalkingTolerance? fromDb(String? v) => v == null ? null :
    WalkingTolerance.values.firstWhere((e) => e.dbValue == v, orElse: () => WalkingTolerance.moderate);
}

// ─────────────────────────────────────────────────────────────────────────────
// ClientDossier — the long-term client profile
// ─────────────────────────────────────────────────────────────────────────────

class ClientDossier {
  final String id;
  final String teamId;
  final String primaryClientName;
  final String? familyName;
  final String? email;
  final String? phone;
  final String? nationality;
  final String? homeBase;

  // Trip context
  final TripType? typicalTripType;
  final String? groupDynamicNotes;

  // Travel style
  final PacingPreference? pacingPreference;
  final PrivacyPreference? privacyPreference;
  final LuxuryLevel? luxuryLevel;
  final GuidePreference? guidePreference;
  final StructurePreference? structurePreference;

  // Accommodation
  final AccommodationType? accommodationType;
  final String? beddingPreferences;
  final WellnessImportance? wellnessImportance;
  final List<String> amenityPreferences;

  // Dining
  final List<String> cuisinePreferences;
  final List<String> diningDislikes;
  final List<String> dietaryRestrictions;
  final List<String> allergies;
  final DiningStyle? diningStyle;
  final String? alcoholPreference;

  // Experiences — 1 (none) to 5 (very high)
  final int culturalInterest;
  final int adventureInterest;
  final int intellectualInterest;
  final int relaxationInterest;
  final int shoppingInterest;

  // Behavioral
  final bool prefersLateStarts;
  final bool dislikesCrowds;
  final HeatTolerance? heatTolerance;
  final WalkingTolerance? walkingTolerance;
  final String? accessibilityNotes;
  final String? securitySensitivity;
  final String? photographySensitivity;

  // Internal only — never exposed in client-facing views
  final String? internalNotes;
  final String? pastFeedbackNotes;
  final String? serviceStyleNotes;
  final List<String> operationalFlags;

  // Loaded associations
  final List<ClientTraveler> travelers;

  // Metadata
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientDossier({
    required this.id,
    required this.teamId,
    required this.primaryClientName,
    this.familyName,
    this.email,
    this.phone,
    this.nationality,
    this.homeBase,
    this.typicalTripType,
    this.groupDynamicNotes,
    this.pacingPreference,
    this.privacyPreference,
    this.luxuryLevel,
    this.guidePreference,
    this.structurePreference,
    this.accommodationType,
    this.beddingPreferences,
    this.wellnessImportance,
    this.amenityPreferences = const [],
    this.cuisinePreferences  = const [],
    this.diningDislikes      = const [],
    this.dietaryRestrictions = const [],
    this.allergies           = const [],
    this.diningStyle,
    this.alcoholPreference,
    this.culturalInterest     = 3,
    this.adventureInterest    = 3,
    this.intellectualInterest = 3,
    this.relaxationInterest   = 3,
    this.shoppingInterest     = 3,
    this.prefersLateStarts  = false,
    this.dislikesCrowds     = false,
    this.heatTolerance,
    this.walkingTolerance,
    this.accessibilityNotes,
    this.securitySensitivity,
    this.photographySensitivity,
    this.internalNotes,
    this.pastFeedbackNotes,
    this.serviceStyleNotes,
    this.operationalFlags = const [],
    this.travelers        = const [],
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName =>
      (familyName != null && familyName!.isNotEmpty) ? familyName! : primaryClientName;

  bool get hasAnyPreferences =>
      pacingPreference != null || privacyPreference != null ||
      luxuryLevel != null || accommodationType != null ||
      cuisinePreferences.isNotEmpty || dietaryRestrictions.isNotEmpty;

  factory ClientDossier.fromMap(
    Map<String, dynamic> r, {
    List<ClientTraveler> travelers = const [],
  }) {
    List<String> asList(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return ClientDossier(
      id:                     r['id'] as String,
      teamId:                 r['team_id'] as String,
      primaryClientName:      r['primary_client_name'] as String,
      familyName:             r['family_name'] as String?,
      email:                  r['email'] as String?,
      phone:                  r['phone'] as String?,
      nationality:            r['nationality'] as String?,
      homeBase:               r['home_base'] as String?,
      typicalTripType:        TripType.fromDb(r['typical_trip_type'] as String?),
      groupDynamicNotes:      r['group_dynamic_notes'] as String?,
      pacingPreference:       PacingPreference.fromDb(r['pacing_preference'] as String?),
      privacyPreference:      PrivacyPreference.fromDb(r['privacy_preference'] as String?),
      luxuryLevel:            LuxuryLevel.fromDb(r['luxury_level'] as String?),
      guidePreference:        GuidePreference.fromDb(r['guide_preference'] as String?),
      structurePreference:    StructurePreference.fromDb(r['structure_preference'] as String?),
      accommodationType:      AccommodationType.fromDb(r['accommodation_type'] as String?),
      beddingPreferences:     r['bedding_preferences'] as String?,
      wellnessImportance:     WellnessImportance.fromDb(r['wellness_importance'] as String?),
      amenityPreferences:     asList(r['amenity_preferences']),
      cuisinePreferences:     asList(r['cuisine_preferences']),
      diningDislikes:         asList(r['dining_dislikes']),
      dietaryRestrictions:    asList(r['dietary_restrictions']),
      allergies:              asList(r['allergies']),
      diningStyle:            DiningStyle.fromDb(r['dining_style'] as String?),
      alcoholPreference:      r['alcohol_preference'] as String?,
      culturalInterest:       (r['cultural_interest']     as num?)?.toInt() ?? 3,
      adventureInterest:      (r['adventure_interest']    as num?)?.toInt() ?? 3,
      intellectualInterest:   (r['intellectual_interest'] as num?)?.toInt() ?? 3,
      relaxationInterest:     (r['relaxation_interest']   as num?)?.toInt() ?? 3,
      shoppingInterest:       (r['shopping_interest']     as num?)?.toInt() ?? 3,
      prefersLateStarts:      r['prefers_late_starts']  as bool? ?? false,
      dislikesCrowds:         r['dislikes_crowds']       as bool? ?? false,
      heatTolerance:          HeatTolerance.fromDb(r['heat_tolerance'] as String?),
      walkingTolerance:       WalkingTolerance.fromDb(r['walking_tolerance'] as String?),
      accessibilityNotes:     r['accessibility_notes']      as String?,
      securitySensitivity:    r['security_sensitivity']     as String?,
      photographySensitivity: r['photography_sensitivity']  as String?,
      internalNotes:          r['internal_notes']           as String?,
      pastFeedbackNotes:      r['past_feedback_notes']      as String?,
      serviceStyleNotes:      r['service_style_notes']      as String?,
      operationalFlags:       asList(r['operational_flags']),
      travelers:              travelers,
      createdBy:              r['created_by'] as String?,
      createdAt:              DateTime.parse(r['created_at'] as String),
      updatedAt:              DateTime.parse(r['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap({String? teamId}) => {
    if (teamId != null) 'team_id': teamId,
    'primary_client_name':    primaryClientName,
    'family_name':            familyName,
    'email':                  email,
    'phone':                  phone,
    'nationality':            nationality,
    'home_base':              homeBase,
    'typical_trip_type':      typicalTripType?.dbValue,
    'group_dynamic_notes':    groupDynamicNotes,
    'pacing_preference':      pacingPreference?.dbValue,
    'privacy_preference':     privacyPreference?.dbValue,
    'luxury_level':           luxuryLevel?.dbValue,
    'guide_preference':       guidePreference?.dbValue,
    'structure_preference':   structurePreference?.dbValue,
    'accommodation_type':     accommodationType?.dbValue,
    'bedding_preferences':    beddingPreferences,
    'wellness_importance':    wellnessImportance?.dbValue,
    'amenity_preferences':    amenityPreferences,
    'cuisine_preferences':    cuisinePreferences,
    'dining_dislikes':        diningDislikes,
    'dietary_restrictions':   dietaryRestrictions,
    'allergies':              allergies,
    'dining_style':           diningStyle?.dbValue,
    'alcohol_preference':     alcoholPreference,
    'cultural_interest':      culturalInterest,
    'adventure_interest':     adventureInterest,
    'intellectual_interest':  intellectualInterest,
    'relaxation_interest':    relaxationInterest,
    'shopping_interest':      shoppingInterest,
    'prefers_late_starts':    prefersLateStarts,
    'dislikes_crowds':        dislikesCrowds,
    'heat_tolerance':         heatTolerance?.dbValue,
    'walking_tolerance':      walkingTolerance?.dbValue,
    'accessibility_notes':    accessibilityNotes,
    'security_sensitivity':   securitySensitivity,
    'photography_sensitivity':photographySensitivity,
    'internal_notes':         internalNotes,
    'past_feedback_notes':    pastFeedbackNotes,
    'service_style_notes':    serviceStyleNotes,
    'operational_flags':      operationalFlags,
  };

  ClientDossier copyWith({
    String? primaryClientName,
    String? familyName,
    bool clearFamilyName = false,
    String? email,
    bool clearEmail = false,
    String? phone,
    bool clearPhone = false,
    String? nationality,
    bool clearNationality = false,
    String? homeBase,
    bool clearHomeBase = false,
    TripType? typicalTripType,
    bool clearTripType = false,
    String? groupDynamicNotes,
    bool clearGroupDynamicNotes = false,
    PacingPreference? pacingPreference,
    bool clearPacing = false,
    PrivacyPreference? privacyPreference,
    bool clearPrivacy = false,
    LuxuryLevel? luxuryLevel,
    bool clearLuxury = false,
    GuidePreference? guidePreference,
    bool clearGuide = false,
    StructurePreference? structurePreference,
    bool clearStructure = false,
    AccommodationType? accommodationType,
    bool clearAccommodation = false,
    String? beddingPreferences,
    bool clearBedding = false,
    WellnessImportance? wellnessImportance,
    bool clearWellness = false,
    List<String>? amenityPreferences,
    List<String>? cuisinePreferences,
    List<String>? diningDislikes,
    List<String>? dietaryRestrictions,
    List<String>? allergies,
    DiningStyle? diningStyle,
    bool clearDiningStyle = false,
    String? alcoholPreference,
    bool clearAlcohol = false,
    int? culturalInterest,
    int? adventureInterest,
    int? intellectualInterest,
    int? relaxationInterest,
    int? shoppingInterest,
    bool? prefersLateStarts,
    bool? dislikesCrowds,
    HeatTolerance? heatTolerance,
    bool clearHeat = false,
    WalkingTolerance? walkingTolerance,
    bool clearWalking = false,
    String? accessibilityNotes,
    bool clearAccessibility = false,
    String? securitySensitivity,
    bool clearSecurity = false,
    String? photographySensitivity,
    bool clearPhotography = false,
    String? internalNotes,
    bool clearInternalNotes = false,
    String? pastFeedbackNotes,
    bool clearPastFeedback = false,
    String? serviceStyleNotes,
    bool clearServiceStyle = false,
    List<String>? operationalFlags,
    List<ClientTraveler>? travelers,
  }) =>
      ClientDossier(
        id:                     id,
        teamId:                 teamId,
        primaryClientName:      primaryClientName      ?? this.primaryClientName,
        familyName:             clearFamilyName        ? null : (familyName ?? this.familyName),
        email:                  clearEmail             ? null : (email ?? this.email),
        phone:                  clearPhone             ? null : (phone ?? this.phone),
        nationality:            clearNationality       ? null : (nationality ?? this.nationality),
        homeBase:               clearHomeBase          ? null : (homeBase ?? this.homeBase),
        typicalTripType:        clearTripType          ? null : (typicalTripType ?? this.typicalTripType),
        groupDynamicNotes:      clearGroupDynamicNotes ? null : (groupDynamicNotes ?? this.groupDynamicNotes),
        pacingPreference:       clearPacing            ? null : (pacingPreference ?? this.pacingPreference),
        privacyPreference:      clearPrivacy           ? null : (privacyPreference ?? this.privacyPreference),
        luxuryLevel:            clearLuxury            ? null : (luxuryLevel ?? this.luxuryLevel),
        guidePreference:        clearGuide             ? null : (guidePreference ?? this.guidePreference),
        structurePreference:    clearStructure         ? null : (structurePreference ?? this.structurePreference),
        accommodationType:      clearAccommodation     ? null : (accommodationType ?? this.accommodationType),
        beddingPreferences:     clearBedding           ? null : (beddingPreferences ?? this.beddingPreferences),
        wellnessImportance:     clearWellness          ? null : (wellnessImportance ?? this.wellnessImportance),
        amenityPreferences:     amenityPreferences     ?? this.amenityPreferences,
        cuisinePreferences:     cuisinePreferences     ?? this.cuisinePreferences,
        diningDislikes:         diningDislikes         ?? this.diningDislikes,
        dietaryRestrictions:    dietaryRestrictions    ?? this.dietaryRestrictions,
        allergies:              allergies              ?? this.allergies,
        diningStyle:            clearDiningStyle       ? null : (diningStyle ?? this.diningStyle),
        alcoholPreference:      clearAlcohol           ? null : (alcoholPreference ?? this.alcoholPreference),
        culturalInterest:       culturalInterest       ?? this.culturalInterest,
        adventureInterest:      adventureInterest      ?? this.adventureInterest,
        intellectualInterest:   intellectualInterest   ?? this.intellectualInterest,
        relaxationInterest:     relaxationInterest     ?? this.relaxationInterest,
        shoppingInterest:       shoppingInterest       ?? this.shoppingInterest,
        prefersLateStarts:      prefersLateStarts      ?? this.prefersLateStarts,
        dislikesCrowds:         dislikesCrowds         ?? this.dislikesCrowds,
        heatTolerance:          clearHeat              ? null : (heatTolerance ?? this.heatTolerance),
        walkingTolerance:       clearWalking           ? null : (walkingTolerance ?? this.walkingTolerance),
        accessibilityNotes:     clearAccessibility     ? null : (accessibilityNotes ?? this.accessibilityNotes),
        securitySensitivity:    clearSecurity          ? null : (securitySensitivity ?? this.securitySensitivity),
        photographySensitivity: clearPhotography       ? null : (photographySensitivity ?? this.photographySensitivity),
        internalNotes:          clearInternalNotes     ? null : (internalNotes ?? this.internalNotes),
        pastFeedbackNotes:      clearPastFeedback      ? null : (pastFeedbackNotes ?? this.pastFeedbackNotes),
        serviceStyleNotes:      clearServiceStyle      ? null : (serviceStyleNotes ?? this.serviceStyleNotes),
        operationalFlags:       operationalFlags       ?? this.operationalFlags,
        travelers:              travelers              ?? this.travelers,
        createdBy:              createdBy,
        createdAt:              createdAt,
        updatedAt:              DateTime.now(),
      );
}
