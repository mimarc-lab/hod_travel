import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/models/supplier_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DuplicateDetectionService — business logic for finding potential duplicate
// suppliers before creating a new record from extracted enrichment data.
//
// Three matching signals, preferring precision over recall:
//   1. Shared website domain  (+3) — strongest: same URL = same property
//   2. Exact normalised name  (+2) — catches copy-paste re-imports
//   3. Fuzzy name + same city (+1) — catches slight name variations
//
// Returns matches sorted by score descending. Intentionally simple — not a
// full-text search engine. Catches the common real-world cases.
// ─────────────────────────────────────────────────────────────────────────────

class DuplicateDetectionService {
  const DuplicateDetectionService();

  /// Returns existing suppliers likely to be the same entity as [enrichment],
  /// sorted strongest match first (up to [limit] results).
  List<Supplier> findMatches(
    SupplierEnrichment enrichment,
    List<Supplier> existing, {
    int limit = 3,
  }) {
    final scored = <({int score, Supplier supplier})>[];

    for (final s in existing) {
      int score = 0;
      if (_domainMatch(enrichment, s)) score += 3;
      if (_exactNameMatch(enrichment, s)) score += 2;
      if (_fuzzyNameMatch(enrichment, s) && _cityMatch(enrichment, s)) {
        score += 1;
      }
      if (score > 0) scored.add((score: score, supplier: s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.supplier).toList();
  }

  // ── Signals ─────────────────────────────────────────────────────────────────

  bool _domainMatch(SupplierEnrichment e, Supplier s) {
    final eDomain = e.sourceDomain.trim();
    if (eDomain.isEmpty) return false;
    final sWebsite = s.website;
    if (sWebsite == null || sWebsite.isEmpty) return false;
    try {
      final sDomain =
          Uri.parse(sWebsite).host.replaceFirst(RegExp(r'^www\.'), '');
      return sDomain.isNotEmpty && sDomain == eDomain;
    } catch (_) {
      return false;
    }
  }

  bool _exactNameMatch(SupplierEnrichment e, Supplier s) {
    final eName = _norm(e.name);
    return eName.isNotEmpty && eName == _norm(s.name);
  }

  bool _fuzzyNameMatch(SupplierEnrichment e, Supplier s) {
    final eName = _norm(e.name);
    final sName = _norm(s.name);
    // Require ≥5 chars so generic short words don't cause false matches.
    if (eName.length < 5 || sName.length < 5) return false;
    return eName.contains(sName) || sName.contains(eName);
  }

  bool _cityMatch(SupplierEnrichment e, Supplier s) {
    final eCity = _norm(e.city);
    return eCity.isNotEmpty && eCity == _norm(s.city);
  }

  // ── Normalisation ──────────────────────────────────────────────────────────

  static String _norm(String? s) {
    if (s == null) return '';
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
