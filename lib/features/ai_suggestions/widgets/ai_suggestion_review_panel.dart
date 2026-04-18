import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/ai_suggestion_model.dart';
import '../providers/ai_suggestion_provider.dart';
import '../services/suggestion_apply_service.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens the review sheet for a suggestion.
/// Returns the [SuggestionApplyResult] if the user taps Apply, or null.
Future<SuggestionApplyResult?> showSuggestionReviewPanel(
  BuildContext context, {
  required AiSuggestion suggestion,
  required AiSuggestionProvider provider,
}) {
  return showModalBottomSheet<SuggestionApplyResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewSheet(suggestion: suggestion, provider: provider),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final AiSuggestion suggestion;
  final AiSuggestionProvider provider;

  const _ReviewSheet({required this.suggestion, required this.provider});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late Map<String, dynamic> _payload;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _payload = Map<String, dynamic>.from(widget.suggestion.proposedPayload);
    // Create a controller for every string-valued key in the payload
    for (final entry in _payload.entries) {
      if (entry.value is String || entry.value is num) {
        _controllers[entry.key] =
            TextEditingController(text: entry.value.toString());
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _syncPayload() {
    for (final entry in _controllers.entries) {
      _payload[entry.key] = entry.value.text;
    }
  }

  Future<void> _approve() async {
    _syncPayload();
    await widget.provider.updatePayload(widget.suggestion.id, _payload);
    await widget.provider.approve(widget.suggestion.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _apply() async {
    _syncPayload();
    await widget.provider.updatePayload(widget.suggestion.id, _payload);
    final result = widget.provider.apply(widget.suggestion.id);
    await widget.provider.markApplied(widget.suggestion.id);
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _dismiss() async {
    await widget.provider.dismiss(widget.suggestion.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    final type       = suggestion.type;
    final isApproved = suggestion.status == AiSuggestionStatus.approved;
    final sourceType = suggestion.sourceContext['source_type'] as String? ?? 'ai_draft';
    final fitLevel   = suggestion.sourceContext['fit_level']   as String? ?? 'good_alternative';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _DragHandle(),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, 0, AppSpacing.base, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: type.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(type.icon, size: 18, color: type.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type label + source badge + fit pill
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(type.label,
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: type.color)),
                            if (sourceType != 'ai_draft')
                              _ReviewSourceBadge(sourceType: sourceType),
                            if (fitLevel == 'best_fit' ||
                                fitLevel == 'strong_match')
                              _ReviewFitPill(fitLevel: fitLevel),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(suggestion.title,
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  // Description
                  if (suggestion.description.isNotEmpty) ...[
                    _SectionLabel('Description'),
                    const SizedBox(height: 4),
                    Text(suggestion.description,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                  ],

                  // Rationale
                  if (suggestion.rationale != null &&
                      suggestion.rationale!.isNotEmpty) ...[
                    _SectionLabel('Rationale'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentFaint,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.accentLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(suggestion.rationale!,
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Editable payload fields
                  if (_controllers.isNotEmpty) ...[
                    _SectionLabel('Edit Details'),
                    const SizedBox(height: 8),
                    ..._controllers.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PayloadField(
                            label: _humanise(entry.key),
                            controller: entry.value,
                          ),
                        )),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, 12, AppSpacing.base, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  // Dismiss
                  OutlinedButton.icon(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      textStyle: AppTextStyles.labelSmall,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const Spacer(),
                  // Approve / Apply
                  if (!isApproved)
                    FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check_rounded, size: 14),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusDoneText,
                        foregroundColor: Colors.white,
                        textStyle: AppTextStyles.labelSmall,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  if (isApproved) ...[
                    OutlinedButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Save Edits'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        textStyle: AppTextStyles.labelSmall,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('Apply'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        textStyle: AppTextStyles.labelSmall,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _humanise(String key) {
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
          color: AppColors.textMuted, letterSpacing: 0.8),
    );
  }
}

class _ReviewSourceBadge extends StatelessWidget {
  final String sourceType;
  const _ReviewSourceBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (sourceType) {
      'dreammaker_signature' => ('DM Signature', const Color(0xFFF7EDD8), const Color(0xFFB8955A)),
      'gap_fill'             => ('Gap Fill',      const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'supplier'             => ('Supplier',      const Color(0xFFECFEFF), const Color(0xFF0891B2)),
      'operational'          => ('Operational',   const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      _                      => ('AI Draft',      const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _ReviewFitPill extends StatelessWidget {
  final String fitLevel;
  const _ReviewFitPill({required this.fitLevel});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (fitLevel) {
      'best_fit'     => ('Best Fit',     const Color(0xFF059669)),
      'strong_match' => ('Strong Match', const Color(0xFF2563EB)),
      _              => ('',             Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _PayloadField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _PayloadField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: AppTextStyles.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}
