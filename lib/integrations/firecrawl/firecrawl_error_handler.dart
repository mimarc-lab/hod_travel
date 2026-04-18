import 'package:http/http.dart' as http;
import 'firecrawl_config.dart';
import 'firecrawl_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlErrorHandler — static guard helpers shared by all Firecrawl services.
//
// Each method returns a typed FirecrawlFailure when a precondition fails,
// or null when it is safe to proceed — enabling if-case early-exit patterns:
//
//   if (FirecrawlErrorHandler.checkApiKey<T>() case final err?) return err;
// ─────────────────────────────────────────────────────────────────────────────

abstract final class FirecrawlErrorHandler {
  /// Fails when no API key is configured.
  static FirecrawlResult<T>? checkApiKey<T>() {
    if (!FirecrawlConfig.isConfigured) {
      return const FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.missingApiKey,
        message: 'No API key configured',
      ));
    }
    return null;
  }

  /// Fails when [url] is not a valid http/https URL.
  static FirecrawlResult<T>? checkUrl<T>(String url) {
    if (!_isValidUrl(url)) {
      return const FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.invalidUrl,
        message: 'Invalid URL format',
      ));
    }
    return null;
  }

  /// Fails for HTTP 429 or any non-200 status; null if the caller should
  /// continue to parse the response body.
  static FirecrawlResult<T>? checkHttpStatus<T>(http.Response response) {
    if (response.statusCode == 429) {
      return FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.rateLimited,
        message: 'Rate limited',
        statusCode: 429,
      ));
    }
    if (response.statusCode != 200) {
      return FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.serverError,
        message: 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      ));
    }
    return null;
  }

  /// Wraps a caught network exception as a FirecrawlFailure.
  static FirecrawlFailure<T> networkError<T>(Exception e) => FirecrawlFailure(
        FirecrawlError(
            type: FirecrawlErrorType.networkError, message: e.toString()),
      );

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'https' || uri.scheme == 'http');
    } catch (_) {
      return false;
    }
  }
}
