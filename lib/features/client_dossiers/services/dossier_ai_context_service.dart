import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_traveler_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DossierAiContextService
//
// Transforms a ClientDossier into structured, AI-ready context maps and
// a formatted prompt string.  Internal notes are excluded — only preference
// and behavioral data is exposed to AI pipelines.
// ─────────────────────────────────────────────────────────────────────────────

abstract class DossierAiContextService {
  /// Returns a structured map of non-internal preference data ready for
  /// injection into AI prompts or system messages.
  static Map<String, dynamic> buildContext(ClientDossier d) {
    return {
      'client': _buildClientBlock(d),
      'travelers': _buildTravelersBlock(d.travelers),
      'travel_style': _buildStyleBlock(d),
      'accommodation': _buildAccommodationBlock(d),
      'dining': _buildDiningBlock(d),
      'experiences': _buildExperiencesBlock(d),
      'behavioral': _buildBehavioralBlock(d),
    };
  }

  /// Returns a human-readable preference summary suitable for insertion
  /// into an AI prompt as a system context block.
  static String buildPromptContext(ClientDossier d) {
    final buf = StringBuffer();

    buf.writeln('=== CLIENT PROFILE: ${d.displayName} ===');
    if (d.typicalTripType != null) {
      buf.writeln('Trip type: ${d.typicalTripType!.label}');
    }
    if (d.homeBase != null) buf.writeln('Base: ${d.homeBase}');
    if (d.travelers.isNotEmpty) {
      final names = d.travelers.map((t) => '${t.name} (${t.role.label})').join(', ');
      buf.writeln('Travelers: $names');
    }
    buf.writeln();

    buf.writeln('TRAVEL STYLE');
    if (d.pacingPreference != null)    buf.writeln('  Pacing: ${d.pacingPreference!.label}');
    if (d.privacyPreference != null)   buf.writeln('  Privacy: ${d.privacyPreference!.label}');
    if (d.luxuryLevel != null)         buf.writeln('  Luxury level: ${d.luxuryLevel!.label}');
    if (d.guidePreference != null)     buf.writeln('  Guide: ${d.guidePreference!.label}');
    if (d.structurePreference != null) buf.writeln('  Structure: ${d.structurePreference!.label}');
    buf.writeln();

    buf.writeln('ACCOMMODATION');
    if (d.accommodationType != null)  buf.writeln('  Type: ${d.accommodationType!.label}');
    if (d.wellnessImportance != null) buf.writeln('  Wellness: ${d.wellnessImportance!.label}');
    if (d.amenityPreferences.isNotEmpty) {
      buf.writeln('  Amenities: ${d.amenityPreferences.join(', ')}');
    }
    if (d.beddingPreferences != null) buf.writeln('  Bedding: ${d.beddingPreferences}');
    buf.writeln();

    buf.writeln('DINING');
    if (d.diningStyle != null)        buf.writeln('  Style: ${d.diningStyle!.label}');
    if (d.cuisinePreferences.isNotEmpty) {
      buf.writeln('  Cuisines: ${d.cuisinePreferences.join(', ')}');
    }
    if (d.dietaryRestrictions.isNotEmpty) {
      buf.writeln('  Dietary: ${d.dietaryRestrictions.join(', ')}');
    }
    if (d.allergies.isNotEmpty) {
      buf.writeln('  ALLERGIES: ${d.allergies.join(', ')}');
    }
    if (d.diningDislikes.isNotEmpty) {
      buf.writeln('  Dislikes: ${d.diningDislikes.join(', ')}');
    }
    if (d.alcoholPreference != null) buf.writeln('  Alcohol: ${d.alcoholPreference}');
    buf.writeln();

    buf.writeln('EXPERIENCE INTERESTS (1=low 5=high)');
    buf.writeln('  Cultural: ${d.culturalInterest}  '
        'Adventure: ${d.adventureInterest}  '
        'Intellectual: ${d.intellectualInterest}  '
        'Relaxation: ${d.relaxationInterest}  '
        'Shopping: ${d.shoppingInterest}');
    buf.writeln();

    buf.writeln('BEHAVIORAL');
    if (d.prefersLateStarts) buf.writeln('  Prefers late morning starts.');
    if (d.dislikesCrowds)    buf.writeln('  Sensitive to crowds — avoid busy venues.');
    if (d.heatTolerance != null)     buf.writeln('  Heat: ${d.heatTolerance!.label}');
    if (d.walkingTolerance != null)  buf.writeln('  Walking: ${d.walkingTolerance!.label}');
    if (d.accessibilityNotes != null) buf.writeln('  Accessibility: ${d.accessibilityNotes}');
    if (d.photographySensitivity != null) buf.writeln('  Photography: ${d.photographySensitivity}');
    if (d.securitySensitivity != null)    buf.writeln('  Security: ${d.securitySensitivity}');

    return buf.toString();
  }

  /// Returns a list of preference signals as short do/don't strings.
  /// Useful for constraint injection in AI pipelines.
  static List<String> buildSignals(ClientDossier d) {
    final signals = <String>[];

    if (d.prefersLateStarts)  signals.add('DO: Schedule activities from 10am+');
    if (d.dislikesCrowds)     signals.add("DON'T: Include crowded tourist venues");
    if (d.privacyPreference == PrivacyPreference.veryPrivate) {
      signals.add('DO: Prioritise privacy — private dining, transfers, entrances');
    }
    if (d.luxuryLevel == LuxuryLevel.ultra) {
      signals.add('DO: Only recommend best-in-class properties and experiences');
    }
    if (d.guidePreference == GuidePreference.privateOnly) {
      signals.add('DO: Private guides only — no group tours');
    }
    if (d.allergies.isNotEmpty) {
      signals.add("DON'T: Include meals with: ${d.allergies.join(', ')}");
    }
    if (d.heatTolerance == HeatTolerance.low) {
      signals.add("DON'T: Schedule outdoor activities during midday heat");
    }
    if (d.walkingTolerance == WalkingTolerance.limited) {
      signals.add("DON'T: Include long walking itineraries or uneven terrain");
    }
    if (d.diningStyle == DiningStyle.fineDining) {
      signals.add('DO: Prioritise Michelin-starred and chef-table experiences');
    }
    if (d.pacingPreference == PacingPreference.slow) {
      signals.add('DO: Max 2 activities per day — allow breathing room');
    }
    if (d.pacingPreference == PacingPreference.full) {
      signals.add('DO: Full days — pack meaningful experiences from morning to evening');
    }

    return signals;
  }

  // ── Private block builders ─────────────────────────────────────────────────

  static Map<String, dynamic> _buildClientBlock(ClientDossier d) => {
    'name':       d.displayName,
    'trip_type':  d.typicalTripType?.label,
    'home_base':  d.homeBase,
    'nationality':d.nationality,
  };

  static List<Map<String, dynamic>> _buildTravelersBlock(List<ClientTraveler> travelers) =>
    travelers.map((t) => {
      'name':       t.name,
      'role':       t.role.label,
      'age_bracket':t.ageBracket?.label,
      'dietary':    t.dietaryNotes,
      'activity':   t.activityNotes,
    }).toList();

  static Map<String, dynamic> _buildStyleBlock(ClientDossier d) => {
    'pacing':    d.pacingPreference?.label,
    'privacy':   d.privacyPreference?.label,
    'luxury':    d.luxuryLevel?.label,
    'guide':     d.guidePreference?.label,
    'structure': d.structurePreference?.label,
  };

  static Map<String, dynamic> _buildAccommodationBlock(ClientDossier d) => {
    'type':      d.accommodationType?.label,
    'wellness':  d.wellnessImportance?.label,
    'bedding':   d.beddingPreferences,
    'amenities': d.amenityPreferences,
  };

  static Map<String, dynamic> _buildDiningBlock(ClientDossier d) => {
    'style':       d.diningStyle?.label,
    'cuisines':    d.cuisinePreferences,
    'dislikes':    d.diningDislikes,
    'dietary':     d.dietaryRestrictions,
    'allergies':   d.allergies,
    'alcohol':     d.alcoholPreference,
  };

  static Map<String, dynamic> _buildExperiencesBlock(ClientDossier d) => {
    'cultural':     d.culturalInterest,
    'adventure':    d.adventureInterest,
    'intellectual': d.intellectualInterest,
    'relaxation':   d.relaxationInterest,
    'shopping':     d.shoppingInterest,
  };

  static Map<String, dynamic> _buildBehavioralBlock(ClientDossier d) => {
    'prefers_late_starts':   d.prefersLateStarts,
    'dislikes_crowds':       d.dislikesCrowds,
    'heat_tolerance':        d.heatTolerance?.label,
    'walking_tolerance':     d.walkingTolerance?.label,
    'accessibility':         d.accessibilityNotes,
    'photography_sensitive': d.photographySensitivity,
    'security':              d.securitySensitivity,
  };
}
