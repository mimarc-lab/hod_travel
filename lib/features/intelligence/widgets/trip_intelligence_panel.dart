import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/ai_suggestion_model.dart';
import '../../../data/models/signature_experience.dart';
import '../../../data/models/supplier_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/trip_readiness.dart';
import '../../../features/ai_suggestions/providers/ai_suggestion_provider.dart';
import '../../../features/ai_suggestions/services/ai_provider.dart';
import '../../../features/ai_memory/suggestion_feedback_tracker.dart';
import '../../../features/ai_memory/preference_inference_engine.dart';
import '../../../features/ai_suggestions/services/suggestion_apply_service.dart';
import '../../../features/ai_suggestions/itinerary_sequence/itinerary_sequence_review_screen.dart';
import '../../../features/ai_suggestions/widgets/ai_suggestion_card.dart';
import '../../../features/ai_suggestions/widgets/ai_suggestion_review_panel.dart';
import '../../../features/itinerary/providers/itinerary_provider.dart';
import '../../../features/itinerary/widgets/item_editor.dart';
import '../../../features/trip_board/providers/board_provider.dart';
import '../../../features/trip_board/widgets/add_task_dialog.dart';
import '../../../shared/widgets/section_header.dart';
import '../next_action/next_action_model.dart';
import '../next_action/widgets/next_action_card.dart';
import '../trip_health/widgets/health_score_card.dart';
import '../trip_intelligence_provider.dart';
import 'alert_card.dart';
import 'readiness_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripIntelligencePanel
//
// Full intelligence summary for one trip — shown in the Intelligence tab
// of TripBoardScreen. Creates its own TripIntelligenceProvider.
// ─────────────────────────────────────────────────────────────────────────────

class TripIntelligencePanel extends StatefulWidget {
  final Trip trip;
  final BoardProvider?     boardProvider;
  final ItineraryProvider? itineraryProvider;

  const TripIntelligencePanel({
    super.key,
    required this.trip,
    this.boardProvider,
    this.itineraryProvider,
  });

  @override
  State<TripIntelligencePanel> createState() => _TripIntelligencePanelState();
}

class _TripIntelligencePanelState extends State<TripIntelligencePanel> {
  late final TripIntelligenceProvider _provider;
  late final AiSuggestionProvider _aiProvider;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = TripIntelligenceProvider(
      trip:          widget.trip,
      tasks:         repos?.tasks,
      itinerary:     repos?.itinerary,
      budget:        repos?.budget,
      notifications: repos?.notifications,
      teams:         repos?.teams,
    );
    final memoryRepo = repos?.aiMemory;
    final teamId     = repos?.currentTeamId ?? '';
    final tracker    = memoryRepo != null && teamId.isNotEmpty
        ? SuggestionFeedbackTracker(
            repo:            memoryRepo,
            inferenceEngine: PreferenceInferenceEngine(memoryRepo),
            teamId:          teamId,
          )
        : null;

    _aiProvider = AiSuggestionProvider(
      repository:      repos?.aiSuggestions,
      aiProvider:      ClaudeAiProvider(),
      tripId:          widget.trip.id,
      teamId:          teamId,
      feedbackTracker: tracker,
      dossierId:       widget.trip.dossierId,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    _aiProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
          );
        }
        if (_provider.error != null) {
          return Center(
            child: Text(_provider.error!, style: AppTextStyles.bodyMedium),
          );
        }
        return _PanelContent(
          provider:          _provider,
          aiProvider:        _aiProvider,
          trip:              widget.trip,
          boardProvider:     widget.boardProvider,
          itineraryProvider: widget.itineraryProvider,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PanelContent extends StatelessWidget {
  final TripIntelligenceProvider provider;
  final AiSuggestionProvider     aiProvider;
  final Trip                     trip;
  final BoardProvider?           boardProvider;
  final ItineraryProvider?       itineraryProvider;

  const _PanelContent({
    required this.provider,
    required this.aiProvider,
    required this.trip,
    this.boardProvider,
    this.itineraryProvider,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = provider.readiness;
    final alerts = provider.alerts;

    final health      = provider.health;
    final nextActions = provider.nextActions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AI Suggestions ────────────────────────────────────────────────
          _AiSuggestionsSection(
            aiProvider:           aiProvider,
            intelligenceProvider: provider,
            trip:                 trip,
            boardProvider:        boardProvider,
            itineraryProvider:    itineraryProvider,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Trip Health card ──────────────────────────────────────────────
          if (health != null) ...[
            HealthScoreCard(health: health),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // ── Readiness card ────────────────────────────────────────────────
          _ReadinessCard(readiness: readiness),
          const SizedBox(height: AppSpacing.xxl),

          // ── Next Best Actions ─────────────────────────────────────────────
          if (nextActions.isNotEmpty) ...[
            SectionHeader(title: 'Next Best Actions'),
            const SizedBox(height: AppSpacing.md),
            _NextActionList(actions: nextActions),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // ── Alerts list ───────────────────────────────────────────────────
          SectionHeader(
            title: 'Operational Alerts',
            actionLabel: alerts.isEmpty ? null : 'Refresh',
            onAction: provider.reload,
          ),
          const SizedBox(height: AppSpacing.md),

          if (alerts.isEmpty)
            _EmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => AlertCard(alert: alerts[i]),
            ),

          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NextActionList extends StatelessWidget {
  final List<NextAction> actions;
  const _NextActionList({required this.actions});

  @override
  Widget build(BuildContext context) {
    // Show at most 5 ranked actions.
    final shown = actions.take(5).toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shown.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => NextActionCard(action: shown[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ReadinessCard extends StatelessWidget {
  final TripReadiness readiness;

  const _ReadinessCard({required this.readiness});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadinessScoreRing(readiness: readiness, size: 72),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Trip Readiness', style: AppTextStyles.heading2),
                    const SizedBox(width: AppSpacing.sm),
                    ReadinessBadge(readiness: readiness, showScore: false),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (readiness.reasons.isEmpty)
                  Text(
                    'Trip looks good — no major issues detected.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  )
                else
                  ...readiness.reasons.map((r) => ReasonBullet(text: r)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 32, color: Color(0xFF10B981)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No issues detected',
            style: AppTextStyles.heading3
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'All operational checks passed for this trip.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Suggestions Section
// ─────────────────────────────────────────────────────────────────────────────

// ── AI Suggestions Section ────────────────────────────────────────────────────
//
// Stateful so it can:
//   • Load suppliers + signature experiences once on init
//   • Track whether generation has been attempted (for empty state messaging)
//   • Show a loading indicator in the content area during generation

class _AiSuggestionsSection extends StatefulWidget {
  final AiSuggestionProvider     aiProvider;
  final TripIntelligenceProvider intelligenceProvider;
  final Trip                     trip;
  final BoardProvider?           boardProvider;
  final ItineraryProvider?       itineraryProvider;

  const _AiSuggestionsSection({
    required this.aiProvider,
    required this.intelligenceProvider,
    required this.trip,
    this.boardProvider,
    this.itineraryProvider,
  });

  @override
  State<_AiSuggestionsSection> createState() => _AiSuggestionsSectionState();
}

class _AiSuggestionsSectionState extends State<_AiSuggestionsSection> {
  static const _modes = <(AiSuggestionType, String, IconData)>[
    (AiSuggestionType.draftItinerary,         'Draft Items',  Icons.auto_fix_high_rounded),
    (AiSuggestionType.missingGap,             'Find Gaps',    Icons.warning_amber_rounded),
    (AiSuggestionType.supplierRecommendation, 'Suppliers',    Icons.storefront_rounded),
    (AiSuggestionType.signatureExperience,    'Experiences',  Icons.auto_awesome_rounded),
    (AiSuggestionType.taskSuggestion,         'Tasks',        Icons.task_alt_rounded),
    (AiSuggestionType.flowImprovement,        'Flow',         Icons.route_rounded),
  ];

  List<Supplier> _suppliers = [];
  List<SignatureExperience> _signatureExperiences = [];

  /// Whether the user has triggered at least one generation in this session.
  /// Used to show a different empty state after a generation returns nothing.
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _loadSupportingData();
  }

  Future<void> _loadSupportingData() async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId;
    if (repos == null || teamId == null) return;
    try {
      final results = await Future.wait([
        repos.suppliers.fetchAll(teamId),
        repos.signatureExperiences.fetchAll(teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _suppliers            = results[0] as List<Supplier>;
        _signatureExperiences = results[1] as List<SignatureExperience>;
      });
    } catch (_) {
      // Silently degrade — AI will still run without this context
    }
  }

  /// Called when the primary action button is tapped.
  /// • Actionable types (task / itinerary / experience): mark applied and open
  ///   the editor immediately — one tap gets it onto the board.
  /// • Non-actionable types: just mark as approved.
  void _onApprove(AiSuggestion suggestion) {
    final isActionable =
        suggestion.type == AiSuggestionType.taskSuggestion ||
        suggestion.type == AiSuggestionType.draftItinerary ||
        suggestion.type == AiSuggestionType.signatureExperience;

    if (isActionable) {
      widget.aiProvider.markApplied(suggestion.id);
      final result = widget.aiProvider.apply(suggestion.id);
      _handleApplyResult(result);
    } else {
      widget.aiProvider.approve(suggestion.id);
    }
  }

  /// Opens the appropriate editor pre-filled with the suggestion's payload.
  void _handleApplyResult(SuggestionApplyResult result) {
    switch (result.action) {
      case ApplyAction.openTaskEditor:
        final prefill = result.taskPrefill!;
        final bp      = widget.boardProvider;
        if (bp == null || bp.groups.isEmpty) return;
        // Use the first board group as the default destination.
        final group = bp.groups.first;
        showAddTaskDialog(
          context,
          group:           group,
          provider:        bp,
          allGroups:       bp.groups,
          initialName:     prefill.name,
          initialPriority: prefill.priority,
        );

      case ApplyAction.openItemEditor:
        final prefill = result.itemPrefill!;
        final ip      = widget.itineraryProvider;
        if (ip == null) return;
        // Resolve the day: match by day number if provided, else use the first day.
        final days   = widget.intelligenceProvider.cachedDays;
        final target = prefill.dayNumber != null
            ? days.firstWhere(
                (d) => d.dayNumber == prefill.dayNumber,
                orElse: () => days.first,
              )
            : (days.isNotEmpty ? days.first : null);
        if (target == null) return;
        showItemEditor(
          context,
          provider: ip,
          dayId:    target.id,
          prefill:  prefill,
        );

      case ApplyAction.acknowledged:
        // Nothing to open — suggestion already marked applied in the panel.
        break;
    }
  }

  void _generate(AiSuggestionType type) {
    setState(() => _attempted = true);
    widget.aiProvider.generate(
      type:                 type,
      trip:                 widget.trip,
      days:                 widget.intelligenceProvider.cachedDays,
      itemsByDay:           widget.intelligenceProvider.cachedItemsByDay,
      tasks:                widget.intelligenceProvider.cachedTasks,
      suppliers:            _suppliers,
      signatureExperiences: _signatureExperiences,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.aiProvider,
      builder: (context, _) {
        final pending      = widget.aiProvider.pendingSuggestions;
        final isGenerating = widget.aiProvider.isGenerating;
        final error        = widget.aiProvider.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'AI Suggestions',
              actionLabel: pending.isNotEmpty ? 'Clear dismissed' : null,
              onAction: pending.isNotEmpty ? widget.aiProvider.deleteDismissed : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Mode chips ─────────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _modes.map((mode) {
                final (type, label, icon) = mode;
                return _GenerateChip(
                  label:     label,
                  icon:      icon,
                  color:     type.color,
                  bg:        type.backgroundColor,
                  isLoading: isGenerating,
                  onTap:     () => _generate(type),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Assisted Itinerary Sequencing entry point ──────────────────
            _SequenceChip(
              trip:              widget.trip,
              itineraryProvider: widget.itineraryProvider,
              isLoading:         isGenerating,
            ),

            // ── Loading indicator ──────────────────────────────────────────
            if (isGenerating) ...[
              const SizedBox(height: AppSpacing.lg),
              const _GeneratingIndicator(),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Error banner ───────────────────────────────────────────────
            if (error != null && !isGenerating) ...[
              const SizedBox(height: AppSpacing.sm),
              _ErrorBanner(
                message: error,
                onDismiss: widget.aiProvider.clearError,
              ),
            ],

            // ── Suggestion cards ───────────────────────────────────────────
            if (pending.isNotEmpty && !isGenerating) ...[
              const SizedBox(height: AppSpacing.md),
              Column(
                children: [
                  for (int i = 0; i < pending.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    AiSuggestionCard(
                      suggestion: pending[i],
                      onApprove:  () => _onApprove(pending[i]),
                      onDismiss:  () => widget.aiProvider.dismiss(pending[i].id),
                      onMarkDone: () => widget.aiProvider.markApplied(pending[i].id),
                      onReview:   () async {
                        final result = await showSuggestionReviewPanel(
                          context,
                          suggestion: pending[i],
                          provider:   widget.aiProvider,
                        );
                        if (result != null && mounted) {
                          _handleApplyResult(result);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],

            // ── Empty states ───────────────────────────────────────────────
            if (!isGenerating && pending.isEmpty && error == null)
              _attempted
                  ? const _EmptyAfterGeneration()
                  : const _EmptyInitial(),
          ],
        );
      },
    );
  }
}

// ── Supporting sub-widgets ─────────────────────────────────────────────────────

class _GenerateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool isLoading;
  final VoidCallback onTap;

  const _GenerateChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Sequence itinerary chip ───────────────────────────────────────────────────

class _SequenceChip extends StatelessWidget {
  final Trip              trip;
  final ItineraryProvider? itineraryProvider;
  final bool              isLoading;

  const _SequenceChip({
    required this.trip,
    this.itineraryProvider,
    required this.isLoading,
  });

  static const _color = Color(0xFF0F766E);
  static const _bg    = Color(0xFFF0FDFA);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading
          ? null
          : () => showItinerarySequenceReview(
                context,
                trip:              trip,
                itineraryProvider: itineraryProvider,
              ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        _bg,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: _color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_timeline_rounded, size: 12, color: _color),
            const SizedBox(width: 5),
            Text(
              'Sequence Itinerary',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _color),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        _color.withAlpha(18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'AI Draft',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: _color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.accent),
        ),
        const SizedBox(width: 10),
        Text(
          'Generating suggestions…',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: Color(0xFF991B1B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.labelSmall
                    .copyWith(color: const Color(0xFF991B1B))),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFF991B1B)),
          ),
        ],
      ),
    );
  }
}

class _EmptyInitial extends StatelessWidget {
  const _EmptyInitial();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select a mode above to generate AI suggestions for this trip.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAfterGeneration extends StatelessWidget {
  const _EmptyAfterGeneration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'No suggestions returned',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'The AI found no actionable suggestions for this mode. '
              'Try a different mode, or add more itinerary content so the AI has more to work from.',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
