import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiMemoryConnectionCheck — temporary diagnostic widget
//
// Drop this anywhere in the app to verify the 3 Phase 20 tables exist and
// are reachable.  Remove after confirming.
// ─────────────────────────────────────────────────────────────────────────────

class AiMemoryConnectionCheck extends StatefulWidget {
  const AiMemoryConnectionCheck({super.key});

  @override
  State<AiMemoryConnectionCheck> createState() =>
      _AiMemoryConnectionCheckState();
}

class _AiMemoryConnectionCheckState extends State<AiMemoryConnectionCheck> {
  final _tables = [
    'suggestion_feedback_events',
    'inferred_preference_signals',
    'ai_memory_records',
  ];

  Map<String, String> _results = {};
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = {};
    });

    final client = Supabase.instance.client;

    for (final table in _tables) {
      try {
        await client.from(table).select('id').limit(1);
        _results[table] = 'OK';
      } on PostgrestException catch (e) {
        _results[table] = 'ERROR: ${e.message}';
      } catch (e) {
        _results[table] = 'ERROR: $e';
      }
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded, size: 16),
                const SizedBox(width: 8),
                Text('AI Memory Tables',
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_running)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  GestureDetector(
                    onTap: _run,
                    child: const Icon(Icons.refresh_rounded,
                        size: 16, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._tables.map((t) {
              final result = _results[t];
              final ok = result == 'OK';
              final pending = result == null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      pending
                          ? Icons.radio_button_unchecked
                          : ok
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                      size: 14,
                      color: pending
                          ? AppColors.textMuted
                          : ok
                              ? const Color(0xFF4CAF50)
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t,
                              style: AppTextStyles.labelSmall
                                  .copyWith(fontWeight: FontWeight.w600)),
                          if (result != null && !ok)
                            Text(result,
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: Colors.red, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
