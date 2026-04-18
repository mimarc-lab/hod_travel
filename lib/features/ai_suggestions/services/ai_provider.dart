import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_config.dart';

// ── Abstract interface ────────────────────────────────────────────────────────

/// Provider-agnostic AI completion contract.
/// Swap implementations without touching any caller.
abstract class AiProvider {
  /// Send a system + user message pair and return the raw text completion.
  Future<String> complete(String systemPrompt, String userPrompt);
}

// ── Anthropic / Claude implementation ────────────────────────────────────────

class ClaudeAiProvider implements AiProvider {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _maxTokens = 4096;

  final http.Client _http;

  ClaudeAiProvider({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  @override
  Future<String> complete(String systemPrompt, String userPrompt) async {
    final config = AiConfig.instance;
    if (!config.isConfigured) {
      throw AiProviderException(
        'AI is not configured. Please add your Anthropic API key in Settings.',
      );
    }

    final body = jsonEncode({
      'model': config.model,
      'max_tokens': _maxTokens,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
    });

    try {
      final response = await _http.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': config.apiKey!,
          'anthropic-version': _apiVersion,
          'content-type': 'application/json',
          // Required for browser-side (Flutter Web) CORS access
          if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content = json['content'] as List<dynamic>;
        final text = (content.first as Map<String, dynamic>)['text'] as String;
        return text.trim();
      }

      debugPrint('[ClaudeAiProvider] HTTP ${response.statusCode}: ${response.body}');

      // Extract the Anthropic error message if available
      String detail = '';
      try {
        final errJson = jsonDecode(response.body) as Map<String, dynamic>;
        final errObj  = errJson['error'] as Map<String, dynamic>?;
        detail = errObj?['message'] as String? ?? '';
      } catch (_) {}

      throw AiProviderException(
        detail.isNotEmpty
            ? 'AI error (${response.statusCode}): $detail'
            : 'AI request failed (${response.statusCode}). Please try again.',
      );
    } on AiProviderException {
      rethrow;
    } catch (e, st) {
      debugPrint('[ClaudeAiProvider] ERROR: $e\n$st');
      final msg = e.toString();
      if (msg.contains('XMLHttpRequest') || msg.contains('CORS') || msg.contains('cross')) {
        throw AiProviderException(
          'Browser CORS error. Ensure your API key is saved and the app is reloaded.',
        );
      }
      throw AiProviderException(
        'Could not reach AI service ($e). Check your connection and try again.',
      );
    }
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class AiProviderException implements Exception {
  final String message;
  const AiProviderException(this.message);

  @override
  String toString() => 'AiProviderException: $message';
}
