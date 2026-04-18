import 'dart:convert';
import 'firecrawl_client.dart';
import 'firecrawl_config.dart';
import 'firecrawl_error_handler.dart';
import 'firecrawl_models.dart';
import 'firecrawl_schema_builders.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlExtractService — structured data extraction from supplier URLs.
//
// Handles the full extraction lifecycle:
//   POST /v1/extract → async job polling via GET /v1/extract/{id} → parse result
//
// Uses FirecrawlSchemaBuilders for prompts/schemas.
// Uses FirecrawlErrorHandler for precondition guards.
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlExtractService {
  final FirecrawlClient _client;

  const FirecrawlExtractService(this._client);

  /// Extract structured accommodation fields from [url].
  Future<FirecrawlResult<FirecrawlExtractResult>> extractAccommodation(
      String url) async {
    if (FirecrawlErrorHandler.checkApiKey<FirecrawlExtractResult>()
        case final err?) { return err; }
    if (FirecrawlErrorHandler.checkUrl<FirecrawlExtractResult>(url)
        case final err?) { return err; }
    return _extract(
      url,
      FirecrawlSchemaBuilders.accommodationPrompt,
      FirecrawlSchemaBuilders.accommodationSchema,
    );
  }

  /// Extract structured experience/activity fields from [url].
  Future<FirecrawlResult<FirecrawlExtractResult>> extractExperience(
      String url) async {
    if (FirecrawlErrorHandler.checkApiKey<FirecrawlExtractResult>()
        case final err?) { return err; }
    if (FirecrawlErrorHandler.checkUrl<FirecrawlExtractResult>(url)
        case final err?) { return err; }
    return _extract(
      url,
      FirecrawlSchemaBuilders.experiencePrompt,
      FirecrawlSchemaBuilders.experienceSchema,
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<FirecrawlResult<FirecrawlExtractResult>> _extract(
    String url,
    String prompt,
    Map<String, dynamic> schema,
  ) async {
    try {
      final response = await _client.post(
        FirecrawlConfig.extractEndpoint,
        {'urls': [url], 'prompt': prompt, 'schema': schema},
      );

      if (FirecrawlErrorHandler.checkHttpStatus<FirecrawlExtractResult>(response)
          case final err?) { return err; }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Async job: Firecrawl may return {success: true, id: "extract_..."} for
      // pages that need multi-step crawling. Poll until complete.
      final jobId = json['id'] as String?;
      if (jobId != null) { return _pollJob(url, jobId); }

      return _parseBody(url, response.body);
    } on Exception catch (e) {
      return FirecrawlErrorHandler.networkError(e);
    }
  }

  /// Polls GET /v1/extract/{id} every 3 s for up to 90 s.
  Future<FirecrawlResult<FirecrawlExtractResult>> _pollJob(
      String url, String jobId) async {
    const interval = Duration(seconds: 3);
    const maxAttempts = 30;

    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);
      try {
        final response =
            await _client.get('${FirecrawlConfig.extractEndpoint}/$jobId');

        if (FirecrawlErrorHandler.checkHttpStatus<FirecrawlExtractResult>(
                response)
            case final err?) { return err; }

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as String? ?? '';

        if (status == 'failed') {
          return const FirecrawlFailure(FirecrawlError(
            type: FirecrawlErrorType.serverError,
            message: 'Extraction job failed',
          ));
        }
        if (status == 'completed') { return _parseBody(url, response.body); }
        // status == 'processing' | 'pending' → keep polling
      } on Exception {
        // Transient poll error — retry on next cycle
      }
    }

    return const FirecrawlFailure(FirecrawlError(
      type: FirecrawlErrorType.emptyResponse,
      message: 'Extraction timed out waiting for results',
    ));
  }

  FirecrawlResult<FirecrawlExtractResult> _parseBody(String url, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final result = FirecrawlExtractResult.fromJson(url, json);
      if (result.fields.isEmpty) {
        return const FirecrawlFailure(FirecrawlError(
          type: FirecrawlErrorType.emptyResponse,
          message: 'No structured data extracted',
        ));
      }
      return FirecrawlSuccess(result);
    } on Exception {
      return const FirecrawlFailure(FirecrawlError(
        type: FirecrawlErrorType.parseError,
        message: 'Could not parse extract response',
      ));
    }
  }
}
