import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/ai_suggestion_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _sourceType(AiSuggestion s) =>
    s.sourceContext['source_type'] as String? ?? 'ai_draft';

String _fitLevel(AiSuggestion s) =>
    s.sourceContext['fit_level'] as String? ?? 'good_alternative';

// ── AiSuggestionCard ──────────────────────────────────────────────────────────

class AiSuggestionCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;
  final VoidCallback onMarkDone;
  final VoidCallback onReview;

  const AiSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onApprove,
    required this.onDismiss,
    required this.onMarkDone,
    required this.onReview,
  });

  // Types that open an editor on approval (task → board, itinerary → itinerary tab).
  static bool _isActionable(AiSuggestionType t) =>
      t == AiSuggestionType.taskSuggestion ||
      t == AiSuggestionType.draftItinerary ||
      t == AiSuggestionType.signatureExperience;

  String _approveLabel(AiSuggestionType t) {
    if (t == AiSuggestionType.taskSuggestion) return 'Add to Board';
    if (t == AiSuggestionType.draftItinerary ||
        t == AiSuggestionType.signatureExperience) {
      return 'Add to Itinerary';
    }
    return 'Approve';
  }

  @override
  Widget build(BuildContext context) {
    final type = suggestion.type;
    final isApproved = suggestion.status == AiSuggestionStatus.approved;
    final isDismissed = suggestion.status == AiSuggestionStatus.dismissed;
    final isApplied = suggestion.status == AiSuggestionStatus.applied;
    final sourceType = _sourceType(suggestion);
    final fitLevel = _fitLevel(suggestion);
    final isSignature = sourceType == 'dreammaker_signature';
    final actionable = _isActionable(type);

    final accentColor = isSignature ? const Color(0xFFB8955A) : type.color;

    final cardContent = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left accent strip ──────────────────────────────────────
              Container(width: 3, color: accentColor),
              // ── Card body ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(11, 12, 12, 0),
                      child: Row(
                        children: [
                          _TypeBadge(type: type),
                          const SizedBox(width: 6),
                          // Source badge — shown for all non-trivial sources
                          if (sourceType != 'ai_draft')
                            _SourceBadge(sourceType: sourceType),
                          const Spacer(),
                          // Fit pill — only for best_fit and strong_match
                          if (fitLevel == 'best_fit' ||
                              fitLevel == 'strong_match')
                            _FitPill(fitLevel: fitLevel),
                          // Status pill
                          if (isApproved)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _StatusPill(
                                'Approved',
                                AppColors.statusDone,
                                AppColors.statusDoneText,
                              ),
                            ),
                          if (isApplied)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _StatusPill(
                                'Applied',
                                AppColors.statusDone,
                                AppColors.statusDoneText,
                              ),
                            ),
                          if (isDismissed)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _StatusPill(
                                'Dismissed',
                                AppColors.statusNotStarted,
                                AppColors.statusNotStartedText,
                              ),
                            ),
                          // Review / edit icon
                          if (!isDismissed)
                            InkWell(
                              onTap: onReview,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Title ────────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Text(
                        suggestion.title,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),

                    // ── Description ──────────────────────────────────────────────────
                    if (suggestion.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                        child: Text(
                          suggestion.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),

                    // ── Rationale ────────────────────────────────────────────────────
                    if (suggestion.rationale != null &&
                        suggestion.rationale!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSignature
                                ? const Color(
                                    0xFFFDF8F0,
                                  ) // warm gold tint for signature
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: isSignature
                                ? Border.all(
                                    color: const Color(0xFFEDD9A3),
                                    width: 0.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isSignature
                                    ? Icons.diamond_outlined
                                    : Icons.lightbulb_outline_rounded,
                                size: 12,
                                color: isSignature
                                    ? const Color(0xFFB8955A)
                                    : AppColors.accent,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  suggestion.rationale!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Action buttons ────────────────────────────────────────────────
                    if (!isDismissed && !isApplied)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Row(
                          children: [
                            // Primary action:
                            //  • Actionable types (task/itinerary): labelled "Add to Board"
                            //    / "Add to Itinerary" — opens the editor in one tap.
                            //  • Approved non-actionable: "Re-open" to review again.
                            //  • Pending non-actionable: "Approve".
                            if (!isApproved)
                              _ActionButton(
                                label: _approveLabel(type),
                                icon: actionable
                                    ? Icons.add_rounded
                                    : Icons.check_rounded,
                                color: AppColors.statusDoneText,
                                bg: AppColors.statusDone,
                                onTap: onApprove,
                              ),
                            if (isApproved && !actionable)
                              _ActionButton(
                                label: 'Review',
                                icon: Icons.open_in_new_rounded,
                                color: AppColors.accent,
                                bg: AppColors.accentFaint,
                                onTap: onReview,
                              ),
                            const SizedBox(width: 6),
                            _ActionButton(
                              label: 'Dismiss',
                              icon: Icons.close_rounded,
                              color: AppColors.textSecondary,
                              bg: AppColors.surfaceAlt,
                              onTap: onDismiss,
                            ),
                            const Spacer(),
                            // Tertiary: user already handled this manually
                            GestureDetector(
                              onTap: onMarkDone,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Already added',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (isDismissed || isApplied) const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return isDismissed
        ? Opacity(opacity: 0.45, child: cardContent)
        : cardContent;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final AiSuggestionType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: type.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: type.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Source origin badge — DreamMaker Signature in gold; others in neutral tones.
class _SourceBadge extends StatelessWidget {
  final String sourceType;
  const _SourceBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = switch (sourceType) {
      'dreammaker_signature' => (
        'DM Signature',
        const Color(0xFFF7EDD8),
        const Color(0xFFB8955A),
        Icons.diamond_outlined,
      ),
      'gap_fill' => (
        'Gap Fill',
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        Icons.warning_amber_rounded,
      ),
      'supplier' => (
        'Supplier',
        const Color(0xFFECFEFF),
        const Color(0xFF0891B2),
        Icons.storefront_rounded,
      ),
      'operational' => (
        'Operational',
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
        Icons.task_alt_rounded,
      ),
      _ => (
        'AI Draft',
        const Color(0xFFF5F3FF),
        const Color(0xFF7C3AED),
        Icons.auto_awesome_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fit level pill — only rendered for best_fit and strong_match.
class _FitPill extends StatelessWidget {
  final String fitLevel;
  const _FitPill({required this.fitLevel});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (fitLevel) {
      'best_fit' => ('Best Fit', const Color(0xFF059669)),
      'strong_match' => ('Strong Match', const Color(0xFF2563EB)),
      _ => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusPill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
