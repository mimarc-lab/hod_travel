import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_questionnaire_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestionnaireSummaryService
//
// Produces AI-ready structured output from questionnaire responses + dossier.
// Used by the AI suggestion layer to build context for trip planning prompts.
// Internal fields are explicitly excluded.
// ─────────────────────────────────────────────────────────────────────────────

class QuestionnaireSummaryService {
  static Map<String, dynamic> buildAiContext(
    ClientQuestionnaireResponse response,
    ClientDossier dossier,
  ) {
    final r = response.responses;

    return {
      'client': dossier.displayName,
      'source': response.sourceLabel,
      'completed_at': response.completedAt.toIso8601String(),

      'travel_style': _compact({
        'pacing':     r['trip_pacing'],
        'privacy':    r['privacy_level'],
        'luxury':     r['luxury_expectation'],
        'structure':  r['structure_vs_flexibility'],
        'guide':      r['guide_preference'],
        'motivations': r['travel_motivations'],
      }),

      'accommodation': _compact({
        'type':      r['property_type'],
        'bedding':   r['bedding_preferences'],
        'wellness':  r['wellness_importance'],
        'amenities': r['amenity_priorities'],
        'notes':     r['accommodation_notes'],
      }),

      'dining': _compact({
        'style':         r['dining_style'],
        'cuisines':      r['cuisine_preferences'],
        'restrictions':  r['dietary_restrictions'],
        'allergies':     r['allergies'],
        'dislikes':      r['dining_dislikes'],
        'alcohol':       r['alcohol_preference'],
        'notes':         r['dining_notes'],
      }),

      'experiences': _compact({
        'cultural_interest':     r['cultural_interest'],
        'adventure_interest':    r['adventure_interest'],
        'relaxation_interest':   r['relaxation_interest'],
        'intellectual_interest': r['intellectual_interest'],
        'shopping_interest':     r['shopping_interest'],
        'highlights':            r['experience_highlights'],
        'avoid':                 r['experience_dislikes'],
      }),

      'group': _compact({
        'composition':   r['group_composition'],
        'children':      r['children_needs'],
        'dynamic':       r['group_dynamic'],
        'accessibility': r['accessibility_needs'],
      }),

      'wellness': _compact({
        'heat_tolerance':    r['heat_tolerance'],
        'walking_tolerance': r['walking_tolerance'],
        'late_starts':       r['prefers_late_starts'],
        'dislikes_crowds':   r['dislikes_crowds'],
        'treatments':        r['wellness_treatments'],
        'comfort_notes':     r['comfort_notes'],
      }),

      'logistics': _compact({
        'transport':        r['transport_preference'],
        'photography':      r['photography_sensitivity'],
        'security':         r['security_needs'],
        'special_requests': r['special_requests'],
      }),
    };
  }

  static String buildPromptContext(
    ClientQuestionnaireResponse response,
    ClientDossier dossier,
  ) {
    final r = response.responses;
    final buf = StringBuffer();

    buf.writeln('CLIENT PREFERENCE PROFILE — ${dossier.displayName}');
    buf.writeln('Source: ${response.sourceLabel} · ${_fmtDate(response.completedAt)}');
    buf.writeln();

    _section(buf, 'TRAVEL STYLE', {
      'Pacing':     r['trip_pacing'],
      'Privacy':    r['privacy_level'],
      'Luxury':     r['luxury_expectation'],
      'Structure':  r['structure_vs_flexibility'],
      'Guide':      r['guide_preference'],
      'Motivations': r['travel_motivations'],
    });

    _section(buf, 'ACCOMMODATION', {
      'Property type': r['property_type'],
      'Bedding':       r['bedding_preferences'],
      'Wellness':      r['wellness_importance'],
      'Amenities':     _listStr(r['amenity_priorities']),
      'Notes':         r['accommodation_notes'],
    });

    _section(buf, 'DINING', {
      'Style':         r['dining_style'],
      'Cuisines':      r['cuisine_preferences'],
      'Restrictions':  _listStr(r['dietary_restrictions']),
      'Allergies':     r['allergies'],
      'Dislikes':      r['dining_dislikes'],
      'Alcohol':       r['alcohol_preference'],
    });

    _section(buf, 'EXPERIENCES', {
      'Cultural':    _scoreLabel(r['cultural_interest']),
      'Adventure':   _scoreLabel(r['adventure_interest']),
      'Relaxation':  _scoreLabel(r['relaxation_interest']),
      'Intellectual': _scoreLabel(r['intellectual_interest']),
      'Shopping':    _scoreLabel(r['shopping_interest']),
      'Loved':       r['experience_highlights'],
      'Avoid':       r['experience_dislikes'],
    });

    _section(buf, 'GROUP PROFILE', {
      'Composition':   r['group_composition'],
      'Children':      r['children_needs'],
      'Accessibility': r['accessibility_needs'],
    });

    _section(buf, 'WELLNESS & COMFORT', {
      'Heat tolerance':    r['heat_tolerance'],
      'Walking tolerance': r['walking_tolerance'],
      'Late starts':       r['prefers_late_starts'] == true ? 'Yes' : null,
      'Avoids crowds':     r['dislikes_crowds'] == true ? 'Yes' : null,
      'Treatments':        r['wellness_treatments'],
    });

    _section(buf, 'LOGISTICS', {
      'Transport':        r['transport_preference'],
      'Photography':      r['photography_sensitivity'],
      'Security':         r['security_needs'],
      'Special requests': r['special_requests'],
    });

    return buf.toString().trim();
  }

  static List<String> buildSignals(
    ClientQuestionnaireResponse response,
  ) {
    final r = response.responses;
    final signals = <String>[];

    _addSignal(signals, r['trip_pacing'], {
      'Slow & Immersive': 'Pace it slow — fewer activities, deeper experiences',
      'Action-Packed':    'Pack the itinerary — client prefers maximum experiences',
    });

    _addSignal(signals, r['privacy_level'], {
      'Very Private': 'Prioritise exclusive, private experiences and venues',
    });

    if (r['dislikes_crowds'] == true) {
      signals.add('AVOID: Crowds and tourist-heavy venues');
    }
    if (r['prefers_late_starts'] == true) {
      signals.add('Schedule activities from 10am or later');
    }

    _addSignal(signals, r['heat_tolerance'], {
      'Low — prefers cool': 'Avoid hot climates or schedule for cooler seasons',
    });

    _addSignal(signals, r['walking_tolerance'], {
      'Limited': 'Minimise walking — arrange transport between sites',
    });

    final allergies = r['allergies'] as String?;
    if (allergies != null && allergies.isNotEmpty) {
      signals.add('ALLERGY ALERT: $allergies');
    }

    final restrictions = r['dietary_restrictions'];
    if (restrictions is List && restrictions.isNotEmpty) {
      signals.add('Dietary: ${restrictions.join(', ')}');
    }

    return signals;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _compact(Map<String, dynamic> map) {
    return Map.fromEntries(
        map.entries.where((e) => e.value != null && e.value.toString().isNotEmpty));
  }

  static void _section(StringBuffer buf, String title, Map<String, dynamic> fields) {
    final entries = fields.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();
    if (entries.isEmpty) return;
    buf.writeln('$title:');
    for (final e in entries) {
      buf.writeln('  ${e.key}: ${e.value}');
    }
    buf.writeln();
  }

  static void _addSignal(
      List<String> signals, dynamic value, Map<String, String> map) {
    if (value == null) return;
    final msg = map[value.toString()];
    if (msg != null) signals.add(msg);
  }

  static String? _listStr(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.join(', ');
    return v.toString();
  }

  static String? _scoreLabel(dynamic v) {
    if (v == null) return null;
    final n = v is int ? v : int.tryParse(v.toString());
    if (n == null) return null;
    const labels = {1: 'None', 2: 'Low', 3: 'Medium', 4: 'High', 5: 'Very High'};
    return '$n/5 — ${labels[n]}';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
