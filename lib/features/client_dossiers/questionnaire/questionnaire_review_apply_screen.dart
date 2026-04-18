import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_questionnaire_model.dart';
import '../providers/client_dossier_provider.dart';
import 'dossier_update_service.dart';
import 'questionnaire_to_dossier_mapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QuestionnaireReviewApplyScreen
//
// After submitting a questionnaire, shows a comparison of questionnaire
// answers vs current dossier values.  User selects which fields to apply;
// on confirm the dossier is updated and the response marked as applied.
// ─────────────────────────────────────────────────────────────────────────────

class QuestionnaireReviewApplyScreen extends StatefulWidget {
  final ClientQuestionnaireResponse response;
  final ClientDossier dossier;
  final ClientDossierProvider provider;

  const QuestionnaireReviewApplyScreen({
    super.key,
    required this.response,
    required this.dossier,
    required this.provider,
  });

  @override
  State<QuestionnaireReviewApplyScreen> createState() =>
      _QuestionnaireReviewApplyScreenState();
}

class _QuestionnaireReviewApplyScreenState
    extends State<QuestionnaireReviewApplyScreen> {
  late List<DossierFieldProposal> _proposals;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _proposals = QuestionnaireToDossierMapper.buildProposals(
      widget.response.responses,
      widget.dossier,
    );
  }

  int get _selectedCount => DossierUpdateService.countSelected(_proposals);

  Future<void> _applySelected() async {
    if (_selectedCount == 0) return;
    setState(() => _applying = true);
    try {
      final updated = DossierUpdateService.apply(widget.dossier, _proposals);
      await widget.provider.updateDossier(updated);
      await widget.provider.markApplied(widget.response.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _toggleAll(bool select) {
    setState(() {
      for (final p in _proposals) {
        p.apply = select;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<DossierFieldProposal>>{};
    for (final p in _proposals) {
      bySection.putIfAbsent(p.sectionLabel, () => []).add(p);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              size: 20, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review & Apply',
                style: AppTextStyles.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(widget.dossier.displayName,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (_proposals.isNotEmpty) ...[
            TextButton(
              onPressed: () => _toggleAll(true),
              child: Text('All',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () => _toggleAll(false),
              child: Text('None',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          _SummaryBar(
            totalProposals: _proposals.length,
            selectedCount: _selectedCount,
          ),

          // Proposals list
          Expanded(
            child: _proposals.isEmpty
                ? _EmptyState()
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      for (final section in bySection.entries) ...[
                        _SectionHeader(label: section.key),
                        const SizedBox(height: 10),
                        for (final p in section.value) ...[
                          _ProposalRow(
                            proposal: p,
                            onToggle: (v) => setState(() => p.apply = v),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
          ),

          // Apply button
          _ApplyBar(
            selectedCount: _selectedCount,
            applying: _applying,
            onApply: _selectedCount > 0 ? _applySelected : null,
            onSkip: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int totalProposals;
  final int selectedCount;

  const _SummaryBar(
      {required this.totalProposals, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$totalProposals field${totalProposals == 1 ? '' : 's'} mapped from questionnaire. '
              '$selectedCount selected to apply.',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Proposal row — shows current vs proposed with toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ProposalRow extends StatelessWidget {
  final DossierFieldProposal proposal;
  final ValueChanged<bool> onToggle;

  const _ProposalRow({required this.proposal, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final bool same = proposal.currentDisplay == proposal.proposedDisplay;

    return GestureDetector(
      onTap: () => onToggle(!proposal.apply),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: proposal.apply ? AppColors.accentFaint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: proposal.apply ? AppColors.accentLight : AppColors.border,
            width: proposal.apply ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle checkbox
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: proposal.apply ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: proposal.apply ? AppColors.accent : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: proposal.apply
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proposal.questionLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),

                  // Current value
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ValueLabel(label: 'Current', isProposed: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proposal.currentDisplay ?? 'Not set',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: proposal.currentDisplay != null
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                            fontStyle: proposal.currentDisplay == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Proposed value
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ValueLabel(label: 'New', isProposed: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proposal.proposedDisplay,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: same
                                ? AppColors.textMuted
                                : AppColors.accent,
                            fontWeight: same
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (same)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Same',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueLabel extends StatelessWidget {
  final String label;
  final bool isProposed;
  const _ValueLabel({required this.label, required this.isProposed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isProposed ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color:
                isProposed ? AppColors.accentLight : AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color:
              isProposed ? AppColors.accent : AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No mappable answers found.',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(
              'The questionnaire answers don\'t map to any dossier fields, '
              'or no questions were answered.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apply bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class _ApplyBar extends StatelessWidget {
  final int selectedCount;
  final bool applying;
  final VoidCallback? onApply;
  final VoidCallback onSkip;

  const _ApplyBar({
    required this.selectedCount,
    required this.applying,
    required this.onApply,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text('Skip'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: applying ? null : onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.buttonRadius),
              ),
            ),
            child: applying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    selectedCount > 0
                        ? 'Apply $selectedCount field${selectedCount == 1 ? '' : 's'}'
                        : 'Nothing selected',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
