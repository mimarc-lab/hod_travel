import 'dart:convert';
import 'firecrawl_client.dart';
import 'firecrawl_config.dart';
import 'firecrawl_error_handler.dart';
import 'firecrawl_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlSearchService — web search for supplier candidates.
//
// Single responsibility: POST /v1/search, parse results, return typed list.
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlSearchService {
  final FirecrawlClient _client;

  const FirecrawlSearchService(this._client);

  /// Search the web for supplier candidates matching [query].
  Future<FirecrawlResult<List<FirecrawlSearchResult>>> search(
      String query) async {
    if (FirecrawlErrorHandler.checkApiKey<List<FirecrawlSearchResult>>()
        case final err?) { return err; }

    if (query.trim().isEmpty) {
      return const FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.invalidUrl,
        message: 'Search query cannot be empty',
      ));
    }

    try {
      final response = await _client.post(
        FirecrawlConfig.searchEndpoint,
        {'query': query.trim(), 'limit': FirecrawlConfig.searchLimit},
      );

      if (FirecrawlErrorHandler
              .checkHttpStatus<List<FirecrawlSearchResult>>(response)
          case final err?) { return err; }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        final results = data
            .map((e) =>
                FirecrawlSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        if (results.isEmpty) {
          return const FirecrawlFailure(FirecrawlError(
            type: FirecrawlErrorType.emptyResponse,
            message: 'No results found',
          ));
        }
        return FirecrawlSuccess(results);
      } on Exception {
        return const FirecrawlFailure(FirecrawlError(
          type: FirecrawlErrorType.parseError,
          message: 'Could not parse search response',
        ));
      }
    } on Exception catch (e) {
      return FirecrawlErrorHandler.networkError(e);
    }
  }
}
