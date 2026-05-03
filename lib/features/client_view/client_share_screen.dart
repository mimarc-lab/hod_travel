import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/trip_repository.dart';
import 'client_itinerary_screen.dart';
import 'services/share_link_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientShareScreen
//
// Public, unauthenticated view of a shared itinerary.
// Validates the UUID share token against `share_tokens`, fetches the trip
// using anon RLS, then renders ClientItineraryScreen in public-view mode
// (no staff toolbar, no share/export buttons).
// ─────────────────────────────────────────────────────────────────────────────

class ClientShareScreen extends StatefulWidget {
  final String token;

  const ClientShareScreen({super.key, required this.token});

  @override
  State<ClientShareScreen> createState() => _ClientShareScreenState();
}

class _ClientShareScreenState extends State<ClientShareScreen> {
  _ScreenState _state = const _Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;

      // 1 — Validate token (extract UUID from slugged segment if needed)
      final uuid = ShareLinkService.extractToken(widget.token);
      final tokenRow = await client
          .from('share_tokens')
          .select('trip_id, expires_at')
          .eq('id', uuid)
          .maybeSingle();

      if (tokenRow == null) {
        _setError('This link is invalid or has been removed.');
        return;
      }

      final rawExpiry = tokenRow['expires_at'];
      if (rawExpiry != null) {
        final expiry = DateTime.parse(rawExpiry as String);
        if (expiry.isBefore(DateTime.now())) {
          _setError('This share link has expired.');
          return;
        }
      }

      final tripId = tokenRow['trip_id'] as String;

      // 2 — Fetch trip row
      final tripRow = await client
          .from('trips')
          .select()
          .eq('id', tripId)
          .maybeSingle();

      if (tripRow == null) {
        _setError('The shared itinerary could not be found.');
        return;
      }

      // 3 — Fetch destinations
      final destRows = await client
          .from('trip_destinations')
          .select('city')
          .eq('trip_id', tripId)
          .order('sort_order');

      final destinations = (destRows as List)
          .map((r) => (r as Map<String, dynamic>)['city'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();

      // 4 — Build Trip (profiles map empty — trip lead not shown in client view)
      final trip = tripFromRow(
        tripRow,
        {},
        destinations: destinations,
      );

      if (mounted) setState(() => _state = _Ready(trip));
    } catch (_) {
      _setError('Unable to load itinerary. Please try again.');
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _state = _Error(message));
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _Loading()       => const _LoadingScaffold(),
      _Error(:final message) => _ErrorScaffold(message: message),
      _Ready(:final trip)    => Scaffold(
          body: ClientItineraryScreen(trip: trip, isPublicView: true),
        ),
    };
  }
}

// ── State types ───────────────────────────────────────────────────────────────

sealed class _ScreenState { const _ScreenState(); }
class _Loading extends _ScreenState { const _Loading(); }
class _Error   extends _ScreenState { final String message; const _Error(this.message); }
class _Ready   extends _ScreenState { final dynamic trip;   const _Ready(this.trip); }

// ── Scaffold helpers ──────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded,
                  size: 40, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(message,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
