/// Firecrawl API configuration.
///
/// The API key is read from a compile-time constant injected via --dart-define.
/// To run with Firecrawl enabled:
///
///   flutter run --dart-define=FIRECRAWL_API_KEY=fc-your-key-here
///
/// If the key is empty the app shows a "missing API key" panel
/// instead of making live API calls.
abstract class FirecrawlConfig {
  /// Firecrawl API key — injected at build time via --dart-define.
  static const String apiKey = String.fromEnvironment(
    'FIRECRAWL_API_KEY',
    defaultValue: '',
  );

  static const String baseUrl = 'https://api.firecrawl.dev/v1';

  /// True when a key has been provided and the integration is active.
  static bool get isConfigured => apiKey.isNotEmpty;

  // ── Endpoint paths ──────────────────────────────────────────────────────

  static String get scrapeEndpoint  => '$baseUrl/scrape';
  static String get extractEndpoint => '$baseUrl/extract';
  static String get searchEndpoint  => '$baseUrl/search';

  // ── Request defaults ────────────────────────────────────────────────────

  static const int searchLimit = 5;
  static const int timeoutSeconds = 30;
}
