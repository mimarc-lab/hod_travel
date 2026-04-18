import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/ai_memory_record.dart';
import '../../../data/repositories/ai_memory_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InferredPreferencesPanel
//
// Displays learned preference signals for a client inside the dossier detail
// screen. Loads asynchronously; shows nothing if no signals exist yet.
// ─────────────────────────────────────────────────────────────────────────────

class InferredPreferencesPanel extends StatefulWidget {
  final String dossierId;
  final AiMemoryRepository repo;

  const InferredPreferencesPanel({
    super.key,
    required this.dossierId,
    required this.repo,
  });

  @override
  State<InferredPreferencesPanel> createState() =>
      _InferredPreferencesPanelState();
}

class _InferredPreferencesPanelState extends State<InferredPreferencesPanel> {
  List<InferredPreferenceSignal> _signals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final signals =
          await widget.repo.fetchSignalsForDossier(widget.dossierId);
      if (mounted) setState(() => _signals = signals);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2)),
      );
    }

    if (_signals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology_outlined,
                size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              'AI-Learned Preferences',
              style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentFaint,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Text('${_signals.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.accent, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _signals.map((s) => _SignalChip(signal: s)).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signal chip
// ─────────────────────────────────────────────────────────────────────────────

class _SignalChip extends StatelessWidget {
  final InferredPreferenceSignal signal;
  const _SignalChip({required this.signal});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color text) = switch (signal.confidence) {
      SignalConfidence.strong   => (
          const Color(0xFFE8F5E9),
          const Color(0xFF4CAF50),
          const Color(0xFF2E7D32)),
      SignalConfidence.moderate => (
          AppColors.accentFaint,
          AppColors.accentLight,
          AppColors.accent),
      SignalConfidence.emerging => (
          AppColors.surfaceAlt,
          AppColors.border,
          AppColors.textSecondary),
    };

    return Tooltip(
      message: signal.evidenceSummary ?? '${signal.evidenceCount} data points',
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _confidenceDot(signal.confidence),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  signal.humanLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted, fontSize: 9),
                ),
                Text(
                  signal.signalValue,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _confidenceDot(SignalConfidence confidence) {
    final color = switch (confidence) {
      SignalConfidence.strong   => const Color(0xFF4CAF50),
      SignalConfidence.moderate => AppColors.accent,
      SignalConfidence.emerging => AppColors.textMuted,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
