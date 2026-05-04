import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/supabase/app_db.dart';
import '../../data/models/run_sheet_view_mode.dart';
import '../../data/models/trip_model.dart';
import '../../data/repositories/trip_repository.dart';
import 'run_sheet_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RunSheetShareScreen
//
// Public entry point for shared run sheet links.
// URL: /run-sheet/{tripId}?token={token}
//
// Validates the token, resolves the view mode, fetches the trip, then renders
// RunSheetScreen with canShare: false so the share button is suppressed.
// ─────────────────────────────────────────────────────────────────────────────

class RunSheetShareScreen extends StatefulWidget {
  final String tripId;
  final String token;

  const RunSheetShareScreen({
    super.key,
    required this.tripId,
    required this.token,
  });

  @override
  State<RunSheetShareScreen> createState() => _RunSheetShareScreenState();
}

class _RunSheetShareScreenState extends State<RunSheetShareScreen> {
  _ScreenState _state = const _Loading();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repos = AppRepositories.instance;
      if (repos == null) {
        _setError('Service unavailable. Please try again.');
        return;
      }

      // 1 — Validate token
      final tokenRecord = await repos.runSheetShares.fetchByToken(widget.token);
      if (tokenRecord == null) {
        _setError('This link is invalid or has been removed.');
        return;
      }
      if (tokenRecord.isExpired) {
        _setError('This share link has expired.');
        return;
      }
      if (tokenRecord.tripId != widget.tripId) {
        _setError('This link is invalid.');
        return;
      }

      final viewMode = tokenRecord.viewMode;

      // 2 — Fetch trip row
      final client = Supabase.instance.client;
      final tripRow = await client
          .from('trips')
          .select()
          .eq('id', widget.tripId)
          .maybeSingle();

      if (tripRow == null) {
        _setError('The run sheet could not be found.');
        return;
      }

      // 3 — Fetch destinations
      final destRows = await client
          .from('trip_destinations')
          .select('city')
          .eq('trip_id', widget.tripId)
          .order('sort_order');

      final destinations = (destRows as List)
          .map((r) => (r as Map<String, dynamic>)['city'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();

      final trip = tripFromRow(tripRow, {}, destinations: destinations);

      if (mounted) setState(() => _state = _Ready(trip, viewMode));
    } catch (_) {
      _setError('Unable to load run sheet. Please try again.');
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _state = _Error(message));
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _Loading()                           => const _LoadingScaffold(),
      _Error(:final message)               => _ErrorScaffold(message: message),
      _Ready(:final trip, :final viewMode) => RunSheetScreen(
          trip:     trip,
          viewMode: viewMode,
          canShare: false,
        ),
    };
  }
}

// ── State types ───────────────────────────────────────────────────────────────

sealed class _ScreenState { const _ScreenState(); }
class _Loading extends _ScreenState { const _Loading(); }
class _Error   extends _ScreenState { final String message; const _Error(this.message); }
class _Ready   extends _ScreenState {
  final Trip             trip;
  final RunSheetViewMode viewMode;
  const _Ready(this.trip, this.viewMode);
}

// ── Scaffold helpers ──────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
    ),
  );
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
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
