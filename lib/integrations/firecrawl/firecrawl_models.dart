// ─────────────────────────────────────────────────────────────────────────────
// Result wrapper — avoids exceptions crossing the service boundary
// ─────────────────────────────────────────────────────────────────────────────

sealed class FirecrawlResult<T> {
  const FirecrawlResult();
}

final class FirecrawlSuccess<T> extends FirecrawlResult<T> {
  final T data;
  const FirecrawlSuccess(this.data);
}

final class FirecrawlFailure<T> extends FirecrawlResult<T> {
  final FirecrawlError error;
  const FirecrawlFailure(this.error);
}

// ─────────────────────────────────────────────────────────────────────────────
// Error model
// ─────────────────────────────────────────────────────────────────────────────

enum FirecrawlErrorType {
  missingApiKey,
  invalidUrl,
  networkError,
  rateLimited,
  serverError,
  emptyResponse,
  parseError,
  unknown,
}

class FirecrawlError {
  final FirecrawlErrorType type;
  final String message;
  final int? statusCode;

  const FirecrawlError({
    required this.type,
    required this.message,
    this.statusCode,
  });

  String get userMessage {
    switch (type) {
      case FirecrawlErrorType.missingApiKey:
        return 'Firecrawl API key is not configured. Add it via --dart-define=FIRECRAWL_API_KEY=fc-xxx.';
      case FirecrawlErrorType.invalidUrl:
        return 'The URL provided is not valid. Please check and try again.';
      case FirecrawlErrorType.networkError:
        return 'Could not reach Firecrawl. Check your internet connection.';
      case FirecrawlErrorType.rateLimited:
        return 'Firecrawl rate limit reached. Please wait a moment and try again.';
      case FirecrawlErrorType.serverError:
        return 'Firecrawl returned an error (HTTP $statusCode). Please try again.';
      case FirecrawlErrorType.emptyResponse:
        return message.contains('timed out')
            ? 'Extraction is taking too long. Try again or use a different URL.'
            : 'No content could be extracted from this URL.';
      case FirecrawlErrorType.parseError:
        return 'Extracted data could not be parsed. The page structure may be unusual.';
      case FirecrawlErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scrape result — clean markdown content + metadata
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlScrapeResult {
  final String url;
  final String? markdownContent;
  final String? title;
  final String? description;

  const FirecrawlScrapeResult({
    required this.url,
    this.markdownContent,
    this.title,
    this.description,
  });

  factory FirecrawlScrapeResult.fromJson(String url, Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    return FirecrawlScrapeResult(
      url: url,
      markdownContent: data['markdown'] as String?,
      title: metadata['title'] as String?,
      description: metadata['description'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extract result — structured supplier data fields
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlExtractResult {
  final String url;
  final Map<String, dynamic> fields;

  const FirecrawlExtractResult({required this.url, required this.fields});

  factory FirecrawlExtractResult.fromJson(String url, Map<String, dynamic> json) {
    // Firecrawl v1 extract response: { success, data: { ... } }
    final data = json['data'];
    final Map<String, dynamic> fields;
    if (data is List && data.isNotEmpty) {
      fields = (data.first as Map<String, dynamic>?)?.cast<String, dynamic>() ?? {};
    } else if (data is Map) {
      fields = data.cast<String, dynamic>();
    } else {
      fields = {};
    }
    return FirecrawlExtractResult(url: url, fields: fields);
  }

  String? string(String key) {
    final v = fields[key];
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  List<String> stringList(String key) {
    final v = fields[key];
    if (v is List) return v.whereType<String>().where((s) => s.isNotEmpty).toList();
    return [];
  }

  bool? boolField(String key) {
    final v = fields[key];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  int? intField(String key) {
    final v = fields[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(RegExp(r'[^\d]'), ''));
    return null;
  }

  double? doubleField(String key) {
    final v = fields[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result — candidate URLs from a web search
// ─────────────────────────────────────────────────────────────────────────────

class FirecrawlSearchResult {
  final String url;
  final String? title;
  final String? snippet;

  const FirecrawlSearchResult({
    required this.url,
    this.title,
    this.snippet,
  });

  factory FirecrawlSearchResult.fromJson(Map<String, dynamic> json) {
    return FirecrawlSearchResult(
      url: json['url'] as String? ?? '',
      title: json['title'] as String?,
      snippet: json['description'] as String? ?? json['snippet'] as String?,
    );
  }
}
