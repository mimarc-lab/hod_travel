import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firecrawl_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FirecrawlClient — raw HTTP transport only.
//
// Responsibilities: headers, timeouts, POST/GET.
// No parsing, no business logic, no error mapping.
// Callers parse responses and map errors themselves.
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlClient {
  final http.Client _http;

  FirecrawlClient({http.Client? client}) : _http = client ?? http.Client();

  void dispose() => _http.close();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${FirecrawlConfig.apiKey}',
        'Content-Type': 'application/json',
      };

  /// POST [body] as JSON to [endpoint]. Throws on timeout/network failure.
  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) =>
      _http
          .post(
            Uri.parse(endpoint),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: FirecrawlConfig.timeoutSeconds));

  /// GET [url] with auth headers. Shorter timeout for poll requests.
  Future<http.Response> get(String url) =>
      _http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
}
