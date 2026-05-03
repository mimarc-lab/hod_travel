import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates and manages shareable links for client itineraries.
///
/// Token is a UUID stored in the `share_tokens` table.
/// Anon RLS policies allow the public page to validate the token and
/// read trip / itinerary data without authentication.
class ShareLinkService {
  /// Replace with your deployed web app domain.
  static const String _baseUrl = 'https://hod-travel.vercel.app';

  /// Inserts a share token row for [tripId] and returns the full URL.
  /// Throws on network / permission error.
  static Future<String> createShareUrl(String tripId) async {
    final client = Supabase.instance.client;
    final data = await client
        .from('share_tokens')
        .insert({
          'trip_id':    tripId,
          'created_by': client.auth.currentUser?.id,
        })
        .select('id')
        .single();
    final token = data['id'] as String;
    return '$_baseUrl/share/$token';
  }

  /// Creates a share token and copies the URL to the clipboard.
  /// Returns the URL so callers can display it.
  static Future<String> copyToClipboard(String tripId) async {
    final url = await createShareUrl(tripId);
    await Clipboard.setData(ClipboardData(text: url));
    return url;
  }
}
