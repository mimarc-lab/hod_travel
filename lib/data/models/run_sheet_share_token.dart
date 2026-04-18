import 'run_sheet_view_mode.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetShareToken
//
// Represents a shareable access token for a specific trip + view mode.
// Stored in: run_sheet_share_tokens (Supabase)
//
// SQL (run once in Supabase SQL editor):
//   create table run_sheet_share_tokens (
//     id          uuid primary key default gen_random_uuid(),
//     trip_id     uuid not null references trips(id) on delete cascade,
//     team_id     uuid not null references teams(id) on delete cascade,
//     token       text not null unique
//                   default encode(gen_random_bytes(18), 'base64url'),
//     view_mode   text not null default 'director',
//     label       text,
//     expires_at  timestamptz,
//     created_by  uuid references profiles(id),
//     created_at  timestamptz not null default now(),
//     revoked_at  timestamptz
//   );
//   create index on run_sheet_share_tokens(token)
//     where revoked_at is null;
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetShareToken {
  final String           id;
  final String           tripId;
  final String           teamId;
  final String           token;
  final RunSheetViewMode viewMode;
  final String?          label;      // human-readable label, e.g. "Day 3 driver"
  final DateTime?        expiresAt;
  final String?          createdBy;  // profile id
  final DateTime         createdAt;
  final bool             isRevoked;

  const RunSheetShareToken({
    required this.id,
    required this.tripId,
    required this.teamId,
    required this.token,
    required this.viewMode,
    this.label,
    this.expiresAt,
    this.createdBy,
    required this.createdAt,
    this.isRevoked = false,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isActive => !isRevoked && !isExpired;

  factory RunSheetShareToken.fromJson(Map<String, dynamic> r) =>
      RunSheetShareToken(
        id:        r['id'] as String,
        tripId:    r['trip_id'] as String,
        teamId:    r['team_id'] as String,
        token:     r['token'] as String,
        viewMode:  RunSheetViewModeInfo.fromDb(
                     r['view_mode'] as String? ?? 'director'),
        label:     r['label'] as String?,
        expiresAt: r['expires_at'] != null
            ? DateTime.parse(r['expires_at'] as String)
            : null,
        createdBy: r['created_by'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        isRevoked: r['revoked_at'] != null,
      );

  /// Payload for INSERT — excludes id, token, created_at (DB-generated).
  Map<String, dynamic> toInsertJson() => {
    'trip_id':   tripId,
    'team_id':   teamId,
    'view_mode': viewMode.dbValue,
    if (label     != null) 'label':      label,
    if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    if (createdBy != null) 'created_by': createdBy,
  };
}
