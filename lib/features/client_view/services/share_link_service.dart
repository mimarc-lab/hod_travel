import 'dart:convert';
import 'package:flutter/services.dart';

/// Generates and manages shareable links for client itineraries.
///
/// Early-stage implementation: token is a base64-encoded trip ID.
/// Future: store tokens in Supabase `share_tokens` table with expiry and
/// serve via an unauthenticated Edge Function or RLS public policy.
class ShareLinkService {
  /// Replace with your deployed web app domain.
  static const String _baseUrl = 'https://app.hodtravel.com';

  /// Encodes a trip ID into a URL-safe token.
  static String generateToken(String tripId) {
    return base64Url.encode(utf8.encode(tripId)).replaceAll('=', '');
  }

  /// Decodes a token back to a trip ID. Returns null if malformed.
  static String? decodeToken(String token) {
    try {
      final padded = token.padRight(token.length + (4 - token.length % 4) % 4, '=');
      return utf8.decode(base64Url.decode(padded));
    } catch (_) {
      return null;
    }
  }

  /// Returns the full shareable URL for a trip.
  static String shareUrl(String tripId) {
    final token = generateToken(tripId);
    return '$_baseUrl/share/$token';
  }

  /// Copies the share URL to the clipboard. Returns the URL.
  static Future<String> copyToClipboard(String tripId) async {
    final url = shareUrl(tripId);
    await Clipboard.setData(ClipboardData(text: url));
    return url;
  }
}
