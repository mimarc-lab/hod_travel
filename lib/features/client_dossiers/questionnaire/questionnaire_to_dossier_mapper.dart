import '../../../data/models/client_dossier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DossierFieldProposal
//
// Represents one questionnaire answer mapped to a single dossier field.
// The applyFn closure captures the typed value; DossierUpdateService chains
// these to produce an updated ClientDossier without blind overwrites.
// ─────────────────────────────────────────────────────────────────────────────

class DossierFieldProposal {
  final String fieldKey;
  final String sectionLabel;
  final String questionLabel;
  final String? currentDisplay;
  final String proposedDisplay;
  final ClientDossier Function(ClientDossier) applyFn;
  bool apply;

  DossierFieldProposal({
    required this.fieldKey,
    required this.sectionLabel,
    required this.questionLabel,
    this.currentDisplay,
    required this.proposedDisplay,
    required this.applyFn,
    this.apply = true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// QuestionnaireToDossierMapper
// ─────────────────────────────────────────────────────────────────────────────

class QuestionnaireToDossierMapper {
  static List<DossierFieldProposal> buildProposals(
    Map<String, dynamic> responses,
    ClientDossier dossier,
  ) {
    final proposals = <DossierFieldProposal>[];

    void add(DossierFieldProposal? p) {
      if (p != null) proposals.add(p);
    }

    // ── Travel Style ──────────────────────────────────────────────────────────

    add(_mapEnum(
      responses: responses,
      key: 'trip_pacing',
      section: 'Travel Style',
      label: 'Preferred pace of travel',
      currentDisplay: dossier.pacingPreference?.label,
      convert: _mapPacing,
      applyFn: (v, d) => d.copyWith(pacingPreference: v as PacingPreference),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'privacy_level',
      section: 'Travel Style',
      label: 'Privacy preference',
      currentDisplay: dossier.privacyPreference?.label,
      convert: _mapPrivacy,
      applyFn: (v, d) => d.copyWith(privacyPreference: v as PrivacyPreference),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'luxury_expectation',
      section: 'Travel Style',
      label: 'Luxury expectation',
      currentDisplay: dossier.luxuryLevel?.label,
      convert: _mapLuxury,
      applyFn: (v, d) => d.copyWith(luxuryLevel: v as LuxuryLevel),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'structure_vs_flexibility',
      section: 'Travel Style',
      label: 'Structure vs. flexibility',
      currentDisplay: dossier.structurePreference?.label,
      convert: _mapStructure,
      applyFn: (v, d) => d.copyWith(structurePreference: v as StructurePreference),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'guide_preference',
      section: 'Travel Style',
      label: 'Guide preference',
      currentDisplay: dossier.guidePreference?.label,
      convert: _mapGuide,
      applyFn: (v, d) => d.copyWith(guidePreference: v as GuidePreference),
    ));

    // ── Accommodation ─────────────────────────────────────────────────────────

    add(_mapEnum(
      responses: responses,
      key: 'property_type',
      section: 'Accommodation',
      label: 'Preferred property type',
      currentDisplay: dossier.accommodationType?.label,
      convert: _mapAccommodation,
      applyFn: (v, d) => d.copyWith(accommodationType: v as AccommodationType),
    ));

    add(_mapText(
      responses: responses,
      key: 'bedding_preferences',
      section: 'Accommodation',
      label: 'Bedding preferences',
      currentDisplay: dossier.beddingPreferences,
      applyFn: (v, d) => d.copyWith(beddingPreferences: v),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'wellness_importance',
      section: 'Accommodation',
      label: 'Wellness / spa importance',
      currentDisplay: dossier.wellnessImportance?.label,
      convert: _mapWellness,
      applyFn: (v, d) => d.copyWith(wellnessImportance: v as WellnessImportance),
    ));

    add(_mapList(
      responses: responses,
      key: 'amenity_priorities',
      section: 'Accommodation',
      label: 'Amenity priorities',
      currentDisplay: dossier.amenityPreferences.isNotEmpty
          ? dossier.amenityPreferences.join(', ')
          : null,
      applyFn: (v, d) => d.copyWith(amenityPreferences: v),
    ));

    // ── Dining ────────────────────────────────────────────────────────────────

    add(_mapEnum(
      responses: responses,
      key: 'dining_style',
      section: 'Dining',
      label: 'Dining style',
      currentDisplay: dossier.diningStyle?.label,
      convert: _mapDining,
      applyFn: (v, d) => d.copyWith(diningStyle: v as DiningStyle),
    ));

    add(_mapText(
      responses: responses,
      key: 'cuisine_preferences',
      section: 'Dining',
      label: 'Favourite cuisines',
      currentDisplay: dossier.cuisinePreferences.isNotEmpty
          ? dossier.cuisinePreferences.join(', ')
          : null,
      applyFn: (v, d) => d.copyWith(
          cuisinePreferences: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
    ));

    add(_mapList(
      responses: responses,
      key: 'dietary_restrictions',
      section: 'Dining',
      label: 'Dietary restrictions',
      currentDisplay: dossier.dietaryRestrictions.isNotEmpty
          ? dossier.dietaryRestrictions.join(', ')
          : null,
      applyFn: (v, d) => d.copyWith(dietaryRestrictions: v),
    ));

    add(_mapText(
      responses: responses,
      key: 'allergies',
      section: 'Dining',
      label: 'Food allergies',
      currentDisplay: dossier.allergies.isNotEmpty
          ? dossier.allergies.join(', ')
          : null,
      applyFn: (v, d) => d.copyWith(
          allergies: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
    ));

    add(_mapText(
      responses: responses,
      key: 'dining_dislikes',
      section: 'Dining',
      label: 'Strong food dislikes',
      currentDisplay: dossier.diningDislikes.isNotEmpty
          ? dossier.diningDislikes.join(', ')
          : null,
      applyFn: (v, d) => d.copyWith(
          diningDislikes: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
    ));

    add(_mapText(
      responses: responses,
      key: 'alcohol_preference',
      section: 'Dining',
      label: 'Alcohol preference',
      currentDisplay: dossier.alcoholPreference,
      applyFn: (v, d) => d.copyWith(alcoholPreference: v),
    ));

    // ── Experiences ───────────────────────────────────────────────────────────

    add(_mapScale(
      responses: responses,
      key: 'cultural_interest',
      section: 'Experiences',
      label: 'Cultural / heritage interest',
      currentValue: dossier.culturalInterest,
      applyFn: (v, d) => d.copyWith(culturalInterest: v),
    ));

    add(_mapScale(
      responses: responses,
      key: 'adventure_interest',
      section: 'Experiences',
      label: 'Adventure / active experiences',
      currentValue: dossier.adventureInterest,
      applyFn: (v, d) => d.copyWith(adventureInterest: v),
    ));

    add(_mapScale(
      responses: responses,
      key: 'relaxation_interest',
      section: 'Experiences',
      label: 'Relaxation interest',
      currentValue: dossier.relaxationInterest,
      applyFn: (v, d) => d.copyWith(relaxationInterest: v),
    ));

    add(_mapScale(
      responses: responses,
      key: 'intellectual_interest',
      section: 'Experiences',
      label: 'Intellectual interest',
      currentValue: dossier.intellectualInterest,
      applyFn: (v, d) => d.copyWith(intellectualInterest: v),
    ));

    add(_mapScale(
      responses: responses,
      key: 'shopping_interest',
      section: 'Experiences',
      label: 'Shopping interest',
      currentValue: dossier.shoppingInterest,
      applyFn: (v, d) => d.copyWith(shoppingInterest: v),
    ));

    // ── Family & Travelers ────────────────────────────────────────────────────

    add(_mapText(
      responses: responses,
      key: 'group_composition',
      section: 'Family & Travelers',
      label: 'Group composition',
      currentDisplay: dossier.groupDynamicNotes,
      applyFn: (v, d) => d.copyWith(groupDynamicNotes: v),
    ));

    add(_mapText(
      responses: responses,
      key: 'accessibility_needs',
      section: 'Family & Travelers',
      label: 'Accessibility / mobility needs',
      currentDisplay: dossier.accessibilityNotes,
      applyFn: (v, d) => d.copyWith(accessibilityNotes: v),
    ));

    // ── Wellness & Comfort ────────────────────────────────────────────────────

    add(_mapEnum(
      responses: responses,
      key: 'heat_tolerance',
      section: 'Wellness & Comfort',
      label: 'Heat tolerance',
      currentDisplay: dossier.heatTolerance?.label,
      convert: _mapHeat,
      applyFn: (v, d) => d.copyWith(heatTolerance: v as HeatTolerance),
    ));

    add(_mapEnum(
      responses: responses,
      key: 'walking_tolerance',
      section: 'Wellness & Comfort',
      label: 'Walking tolerance',
      currentDisplay: dossier.walkingTolerance?.label,
      convert: _mapWalking,
      applyFn: (v, d) => d.copyWith(walkingTolerance: v as WalkingTolerance),
    ));

    add(_mapBool(
      responses: responses,
      key: 'prefers_late_starts',
      section: 'Wellness & Comfort',
      label: 'Prefers late morning starts',
      currentValue: dossier.prefersLateStarts,
      applyFn: (v, d) => d.copyWith(prefersLateStarts: v),
    ));

    add(_mapBool(
      responses: responses,
      key: 'dislikes_crowds',
      section: 'Wellness & Comfort',
      label: 'Sensitive to crowds',
      currentValue: dossier.dislikesCrowds,
      applyFn: (v, d) => d.copyWith(dislikesCrowds: v),
    ));

    // ── Logistics ─────────────────────────────────────────────────────────────

    add(_mapText(
      responses: responses,
      key: 'photography_sensitivity',
      section: 'Logistics',
      label: 'Photography / privacy sensitivity',
      currentDisplay: dossier.photographySensitivity,
      applyFn: (v, d) => d.copyWith(photographySensitivity: v),
    ));

    add(_mapText(
      responses: responses,
      key: 'security_needs',
      section: 'Logistics',
      label: 'Security requirements',
      currentDisplay: dossier.securitySensitivity,
      applyFn: (v, d) => d.copyWith(securitySensitivity: v),
    ));

    add(_mapText(
      responses: responses,
      key: 'past_trip_feedback',
      section: 'Logistics',
      label: 'Feedback from past trips',
      currentDisplay: dossier.pastFeedbackNotes,
      applyFn: (v, d) => d.copyWith(pastFeedbackNotes: v),
    ));

    return proposals;
  }

  // ── Field helpers ───────────────────────────────────────────────────────────

  static DossierFieldProposal? _mapEnum({
    required Map<String, dynamic> responses,
    required String key,
    required String section,
    required String label,
    required String? currentDisplay,
    required Object? Function(String) convert,
    required ClientDossier Function(Object, ClientDossier) applyFn,
  }) {
    final raw = responses[key] as String?;
    if (raw == null || raw.isEmpty) return null;
    final converted = convert(raw);
    if (converted == null) return null;
    final convertedEnum = converted as dynamic;
    return DossierFieldProposal(
      fieldKey: key,
      sectionLabel: section,
      questionLabel: label,
      currentDisplay: currentDisplay,
      proposedDisplay: convertedEnum.label as String,
      applyFn: (d) => applyFn(converted, d),
    );
  }

  static DossierFieldProposal? _mapText({
    required Map<String, dynamic> responses,
    required String key,
    required String section,
    required String label,
    required String? currentDisplay,
    required ClientDossier Function(String, ClientDossier) applyFn,
  }) {
    final raw = responses[key] as String?;
    if (raw == null || raw.trim().isEmpty) return null;
    return DossierFieldProposal(
      fieldKey: key,
      sectionLabel: section,
      questionLabel: label,
      currentDisplay: currentDisplay,
      proposedDisplay: raw.trim(),
      applyFn: (d) => applyFn(raw.trim(), d),
    );
  }

  static DossierFieldProposal? _mapList({
    required Map<String, dynamic> responses,
    required String key,
    required String section,
    required String label,
    required String? currentDisplay,
    required ClientDossier Function(List<String>, ClientDossier) applyFn,
  }) {
    final raw = responses[key];
    if (raw == null) return null;
    final list = (raw is List)
        ? raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : [raw.toString()];
    if (list.isEmpty) return null;
    return DossierFieldProposal(
      fieldKey: key,
      sectionLabel: section,
      questionLabel: label,
      currentDisplay: currentDisplay,
      proposedDisplay: list.join(', '),
      applyFn: (d) => applyFn(list, d),
    );
  }

  static DossierFieldProposal? _mapScale({
    required Map<String, dynamic> responses,
    required String key,
    required String section,
    required String label,
    required int currentValue,
    required ClientDossier Function(int, ClientDossier) applyFn,
  }) {
    final raw = responses[key];
    if (raw == null) return null;
    final value = (raw is int) ? raw : int.tryParse(raw.toString());
    if (value == null || value < 1 || value > 5) return null;
    final labels = {1: 'None', 2: 'Low', 3: 'Medium', 4: 'High', 5: 'Very High'};
    return DossierFieldProposal(
      fieldKey: key,
      sectionLabel: section,
      questionLabel: label,
      currentDisplay: '$currentValue / 5',
      proposedDisplay: '$value / 5 — ${labels[value]}',
      applyFn: (d) => applyFn(value, d),
    );
  }

  static DossierFieldProposal? _mapBool({
    required Map<String, dynamic> responses,
    required String key,
    required String section,
    required String label,
    required bool currentValue,
    required ClientDossier Function(bool, ClientDossier) applyFn,
  }) {
    final raw = responses[key];
    if (raw == null) return null;
    final value = raw is bool ? raw : raw.toString() == 'true';
    return DossierFieldProposal(
      fieldKey: key,
      sectionLabel: section,
      questionLabel: label,
      currentDisplay: currentValue ? 'Yes' : 'No',
      proposedDisplay: value ? 'Yes' : 'No',
      applyFn: (d) => applyFn(value, d),
    );
  }

  // ── Enum converters ─────────────────────────────────────────────────────────

  static PacingPreference? _mapPacing(String v) => switch (v) {
    'Slow & Immersive' => PacingPreference.slow,
    'Balanced'         => PacingPreference.balanced,
    'Action-Packed'    => PacingPreference.full,
    _                  => null,
  };

  static PrivacyPreference? _mapPrivacy(String v) => switch (v) {
    'Very Private'   => PrivacyPreference.veryPrivate,
    'Standard'       => PrivacyPreference.standard,
    'Open / Social'  => PrivacyPreference.social,
    _                => null,
  };

  static LuxuryLevel? _mapLuxury(String v) {
    if (v.startsWith('Ultra'))       return LuxuryLevel.ultra;
    if (v.startsWith('High'))        return LuxuryLevel.high;
    if (v.startsWith('Comfortable')) return LuxuryLevel.comfortable;
    return null;
  }

  static StructurePreference? _mapStructure(String v) => switch (v) {
    'Highly Structured' => StructurePreference.highlyStructured,
    'Balanced'          => StructurePreference.balanced,
    'Spontaneous'       => StructurePreference.flexible,
    _                   => null,
  };

  static GuidePreference? _mapGuide(String v) => switch (v) {
    'Private Only'    => GuidePreference.privateOnly,
    'Small Group OK'  => GuidePreference.smallGroupOk,
    'No Preference'   => GuidePreference.flexible,
    _                 => null,
  };

  static AccommodationType? _mapAccommodation(String v) => switch (v) {
    'Hotel'                    => AccommodationType.hotel,
    'Villa / Private Residence' => AccommodationType.villa,
    'Mixed'                    => AccommodationType.mixed,
    _                          => null,
  };

  static WellnessImportance? _mapWellness(String v) {
    if (v.startsWith('Essential')) return WellnessImportance.essential;
    if (v == 'Preferred')         return WellnessImportance.preferred;
    if (v.startsWith('Not'))      return WellnessImportance.notImportant;
    return null;
  }

  static DiningStyle? _mapDining(String v) {
    if (v.startsWith('Fine'))   return DiningStyle.fineDining;
    if (v.startsWith('Casual')) return DiningStyle.casual;
    if (v.startsWith('Mix'))    return DiningStyle.mixed;
    return null;
  }

  static HeatTolerance? _mapHeat(String v) {
    if (v.startsWith('Low'))    return HeatTolerance.low;
    if (v == 'Medium')          return HeatTolerance.medium;
    if (v.startsWith('High'))   return HeatTolerance.high;
    return null;
  }

  static WalkingTolerance? _mapWalking(String v) => switch (v) {
    'Limited'   => WalkingTolerance.limited,
    'Moderate'  => WalkingTolerance.moderate,
    'Extensive' => WalkingTolerance.extensive,
    _           => null,
  };
}
