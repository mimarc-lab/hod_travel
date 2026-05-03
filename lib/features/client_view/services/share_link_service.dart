import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates and manages shareable links for client itineraries.
///
/// URL format: /share/{trip-name-slug}--{uuid}
/// The slug is decorative; the UUID is the actual DB token used for lookup.
/// ClientShareScreen always extracts the last 36 characters as the UUID.
class ShareLinkService {
  static const String _baseUrl = 'https://hod-travel.vercel.app';

  /// Inserts a share token row and returns a readable URL.
  static Future<String> createShareUrl(
    String tripId, {
    String tripName = '',
  }) async {
    final client = Supabase.instance.client;
    final data = await client
        .from('share_tokens')
        .insert({
          'trip_id':    tripId,
          'created_by': client.auth.currentUser?.id,
        })
        .select('id')
        .single();

    final uuid = data['id'] as String;
    final slug = tripName.isNotEmpty ? '${_slugify(tripName)}--' : '';
    return '$_baseUrl/share/$slug$uuid';
  }

  /// Creates a share token and copies the readable URL to the clipboard.
  static Future<String> copyToClipboard(
    String tripId, {
    String tripName = '',
  }) async {
    final url = await createShareUrl(tripId, tripName: tripName);
    await Clipboard.setData(ClipboardData(text: url));
    return url;
  }

  /// Extracts the UUID token from a URL path segment.
  /// Handles both plain UUIDs and slugged format "name--uuid".
  static String extractToken(String pathSegment) {
    if (pathSegment.length == 36) return pathSegment;
    if (pathSegment.length > 36) {
      return pathSegment.substring(pathSegment.length - 36);
    }
    return pathSegment;
  }

  static String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
}
