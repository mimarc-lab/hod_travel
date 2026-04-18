import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firecrawl_client.dart';
import 'firecrawl_config.dart';
import 'firecrawl_error_handler.dart';
import 'firecrawl_extract_service.dart';
import 'firecrawl_models.dart';
import 'firecrawl_search_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlService — public facade that composes the split services.
//
// Existing callers (EnrichmentProvider) continue to use this class unchanged.
// Internally each method delegates to the appropriate focused service.
//
// Also retains scrapeUrl() which is a lightweight one-shot operation that
// doesn't warrant its own service file.
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlService {
  final FirecrawlClient _client;
  late final FirecrawlExtractService _extract;
  late final FirecrawlSearchService _search;

  FirecrawlService({http.Client? client})
      : _client = FirecrawlClient(client: client) {
    _extract = FirecrawlExtractService(_client);
    _search  = FirecrawlSearchService(_client);
  }

  void dispose() => _client.dispose();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Scrape a URL and return clean markdown content + metadata.
  Future<FirecrawlResult<FirecrawlScrapeResult>> scrapeUrl(String url) async {
    if (FirecrawlErrorHandler.checkApiKey<FirecrawlScrapeResult>()
        case final err?) { return err; }
    if (FirecrawlErrorHandler.checkUrl<FirecrawlScrapeResult>(url)
        case final err?) { return err; }
    try {
      final response = await _client.post(
        FirecrawlConfig.scrapeEndpoint,
        {'url': url, 'formats': ['markdown']},
      );
      if (FirecrawlErrorHandler.checkHttpStatus<FirecrawlScrapeResult>(response)
          case final err?) { return err; }
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = FirecrawlScrapeResult.fromJson(url, json);
        if (result.markdownContent == null ||
            result.markdownContent!.isEmpty) {
          return const FirecrawlFailure(FirecrawlError(
            type: FirecrawlErrorType.emptyResponse,
            message: 'No content extracted',
          ));
        }
        return FirecrawlSuccess(result);
      } on Exception {
        return const FirecrawlFailure(FirecrawlError(
          type: FirecrawlErrorType.parseError,
          message: 'Could not parse scrape response',
        ));
      }
    } on Exception catch (e) {
      return FirecrawlErrorHandler.networkError(e);
    }
  }

  /// Extract structured accommodation fields from a URL.
  Future<FirecrawlResult<FirecrawlExtractResult>> extractSupplierData(
          String url) =>
      _extract.extractAccommodation(url);

  /// Extract structured experience/activity fields from a URL.
  Future<FirecrawlResult<FirecrawlExtractResult>> extractExperienceData(
          String url) =>
      _extract.extractExperience(url);

  /// Search the web for supplier candidates matching a text query.
  Future<FirecrawlResult<List<FirecrawlSearchResult>>> searchSuppliers(
          String query) =>
      _search.search(query);
}
