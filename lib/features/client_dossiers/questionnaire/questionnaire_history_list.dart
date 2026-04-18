import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_questionnaire_model.dart';
import '../providers/client_dossier_provider.dart';
import '../screens/client_questionnaire_screen.dart';
import 'questionnaire_review_apply_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestionnaireHistoryList
//
// Widget embedded in the dossier detail screen showing all past questionnaire
// responses with status badges.  Tapping a submitted response opens the
// review/apply screen; tapping a draft resumes editing.
// ─────────────────────────────────────────────────────────────────────────────

class QuestionnaireHistoryList extends StatelessWidget {
  final List<ClientQuestionnaireResponse> responses;
  final bool isLoading;
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final VoidCallback onRefresh;

  const QuestionnaireHistoryList({
    super.key,
    required this.responses,
    required this.isLoading,
    required this.dossier,
    required this.provider,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.base),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2)),
      );
    }

    if (responses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Text('No questionnaires completed yet.',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
      );
    }

    return Column(
      children: responses
          .map((r) => _HistoryRow(
                response: r,
                dossier: dossier,
                provider: provider,
                onRefresh: onRefresh,
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History row
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final ClientQuestionnaireResponse response;
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final VoidCallback onRefresh;

  const _HistoryRow({
    required this.response,
    required this.dossier,
    required this.provider,
    required this.onRefresh,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (response.isDraft) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClientQuestionnaireScreen(
          dossier: dossier,
          provider: provider,
          existing: response,
        ),
      ));
      onRefresh();
      return;
    }

    if (response.isSubmitted) {
      final applied = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => QuestionnaireReviewApplyScreen(
          response: response,
          dossier: dossier,
          provider: provider,
        ),
      ));
      if (applied == true) onRefresh();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy').format(response.completedAt);
    final count = response.responses.values
        .where((v) => v != null && v.toString().isNotEmpty)
        .length;
    final isTappable =
        response.isDraft || response.isSubmitted;

    return GestureDetector(
      onTap: isTappable ? () => _handleTap(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isTappable ? AppColors.border : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              response.isApplied
                  ? Icons.assignment_turned_in_rounded
                  : response.isDraft
                      ? Icons.edit_note_rounded
                      : Icons.assignment_outlined,
              size: 16,
              color: _iconColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: AppTextStyles.labelSmall
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    '${response.sourceLabel} · $count answers',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (response.isApplied && response.appliedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Applied ${DateFormat('d MMM').format(response.appliedAt!)}',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF2E7D32), fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusBadge(status: response.status),
            if (isTappable) ...[
              const SizedBox(width: 6),
              Icon(
                response.isDraft
                    ? Icons.edit_rounded
                    : Icons.chevron_right_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _iconColor {
    if (response.isApplied) return const Color(0xFF2E7D32);
    if (response.isDraft) return AppColors.textMuted;
    return AppColors.accent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ResponseStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color text) = switch (status) {
      ResponseStatus.draft     => (const Color(0xFFF5F5F5), AppColors.textMuted),
      ResponseStatus.submitted => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      ResponseStatus.reviewed  => (const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      ResponseStatus.applied   => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(status.label,
          style: AppTextStyles.labelSmall.copyWith(
              color: text, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
