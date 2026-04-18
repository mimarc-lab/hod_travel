import '../../../data/models/itinerary_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientSafeContentMapper
//
// Single authoritative gate for what reaches the client-facing layer.
// Strengthens the original ClientVisibilityFilter with an explicit set of
// rules and a clean sanitize step.
//
// Rules:
//   visible  — item is shown to the client
//   sanitize — strips internal-only fields before display/export
//
// Never expose: notes, linkedTaskId, approvalStatus, status, teamId
// ─────────────────────────────────────────────────────────────────────────────

abstract class ClientSafeContentMapper {
  // ── Visibility ────────────────────────────────────────────────────────────────

  static bool isVisible(ItineraryItem item) {
    // Notes are shown only when they carry a client-facing description
    if (item.type == ItemType.note) {
      return item.description != null && item.description!.trim().isNotEmpty;
    }
    return true;
  }

  // ── Sanitize ──────────────────────────────────────────────────────────────────

  /// Returns a copy of the item with all internal-only fields stripped.
  static ItineraryItem sanitize(ItineraryItem item) => item.copyWith(
        clearNotes: true,
      );

  // ── Convenience: filter + sanitize a list in one pass ────────────────────────

  static List<ItineraryItem> prepare(List<ItineraryItem> raw) =>
      raw.where(isVisible).map(sanitize).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Keep backward-compatible alias so existing references still compile.
// ─────────────────────────────────────────────────────────────────────────────

typedef ClientVisibilityFilter = ClientSafeContentMapper;
