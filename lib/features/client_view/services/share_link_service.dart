import 'dart:math';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates and manages shareable links for client itineraries.
///
/// URL format: /share/{trip-name-slug}-{4-char-hex}
/// The slug is stored in share_tokens.slug and used for DB lookup.
class ShareLinkService {
  static const String _baseUrl = 'https://hod-travel.vercel.app';

  static final _random = Random();

  /// Inserts a share token row and returns a clean readable URL.
  static Future<String> createShareUrl(
    String tripId, {
    String tripName = '',
  }) async {
    final client = Supabase.instance.client;
    final slug = _generateSlug(tripName);

    final data = await client
        .from('share_tokens')
        .insert({
          'trip_id':    tripId,
          'created_by': client.auth.currentUser?.id,
          'slug':       slug,
        })
        .select('slug')
        .single();

    final token = data['slug'] as String;
    return '$_baseUrl/share/$token';
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

  static String _generateSlug(String tripName) {
    final base = tripName.isNotEmpty ? _slugify(tripName) : 'itinerary';
    final suffix = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$base-$suffix';
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
