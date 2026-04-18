// ─────────────────────────────────────────────────────────────────────────────
// SupabaseConfig — reads credentials from dart-define at build time.
//
// Pass at build / run time:
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJh...
//
// Or store in a .env-style launch configuration — never commit real keys.
// ─────────────────────────────────────────────────────────────────────────────

abstract class SupabaseConfig {
  static const String url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// True when both URL and anon key have been provided at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
