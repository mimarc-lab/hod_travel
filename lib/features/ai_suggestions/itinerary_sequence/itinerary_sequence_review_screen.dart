import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/ai_suggestion_model.dart';
import '../../../data/models/proposed_itinerary_day.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../features/itinerary/providers/itinerary_provider.dart';
import '../services/ai_config.dart';
import '../services/ai_provider.dart';
import 'assisted_itinerary_sequence_service.dart';
import 'itinerary_sequence_apply_service.dart';
import 'itinerary_sequence_context_builder.dart';
import 'itinerary_sequence_day_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItinerarySequenceReviewScreen
//
// Self-contained workflow screen:
//   preparing → generating → reviewing → applying → done
//
// Human-approved at every step. Never writes to the live itinerary
// without explicit "Apply" confirmation.
//
// Entry points:
//   • Intelligence panel "Sequence Itinerary" chip
//   • Itinerary Builder "Suggest Sequence" button
//   • Components tab "Build Itinerary Draft" button
// ─────────────────────────────────────────────────────────────────────────────

enum _ReviewStatus { preparing, generating, reviewing, applying, done, error }

Future<void> showItinerarySequenceReview(
  BuildContext context, {
  required Trip trip,
  ItineraryProvider? itineraryProvider,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ItinerarySequenceReviewScreen(
      trip:              trip,
      itineraryProvider: itineraryProvider,
    ),
  ));
}

class ItinerarySequenceReviewScreen extends StatefulWidget {
  final Trip              trip;
  final ItineraryProvider? itineraryProvider;

  const ItinerarySequenceReviewScreen({
    super.key,
    required this.trip,
    this.itineraryProvider,
  });

  @override
  State<ItinerarySequenceReviewScreen> createState() =>
      _ItinerarySequenceReviewScreenState();
}

class _ItinerarySequenceReviewScreenState
    extends State<ItinerarySequenceReviewScreen> {
  // ── Workflow state ─────────────────────────────────────────────────────────
  _ReviewStatus            _status       = _ReviewStatus.preparing;
  String?                  _errorMessage;
  ItinerarySequenceDraft?  _draft;
  AiSuggestion?            _suggestion;

  // ── Draft review state ─────────────────────────────────────────────────────
  // itemId → true = included in apply set (default all included)
  Map<String, bool>              _included = {};
  // itemId → field overrides ('title', 'timeBlock', 'location')
  final Map<String, Map<String, String>> _edits = {};

  // ── Data ───────────────────────────────────────────────────────────────────
  List<TripComponent>                   _components  = [];
  late ItineraryProvider                _itinProvider;
  late bool                             _ownsProvider;

  // ── Apply result ───────────────────────────────────────────────────────────
  ItinerarySequenceApplyResult? _applyResult;

  @override
  void initState() {
    super.initState();

    if (widget.itineraryProvider != null) {
      _itinProvider = widget.itineraryProvider!;
      _ownsProvider = false;
    } else {
      _itinProvider = ItineraryProvider(
        widget.trip,
        repository: AppRepositories.instance?.itinerary,
        teamId:     AppRepositories.instance?.currentTeamId,
      );
      _ownsProvider = true;
    }

    _prepare();
  }

  @override
  void dispose() {
    if (_ownsProvider) _itinProvider.dispose();
    super.dispose();
  }

  // ── Prepare: fetch components + itinerary days ────────────────────────────

  Future<void> _prepare() async {
    setState(() => _status = _ReviewStatus.preparing);
    try {
      final repos = AppRepositories.instance;

      // Fetch confirmed/approved/booked components
      final allComps = repos?.components != null
          ? await repos!.components.fetchForTrip(widget.trip.id)
          : <TripComponent>[];

      _components = allComps
          .where((c) =>
              c.status == ComponentStatus.approved ||
              c.status == ComponentStatus.confirmed ||
              c.status == ComponentStatus.booked)
          .toList();

      if (_components.isEmpty && mounted) {
        setState(() {
          _status = _ReviewStatus.error;
          _errorMessage =
              'No confirmed components found for this trip.\n\n'
              'Mark components as Approved, Confirmed, or Booked in the '
              'Components tab before generating a sequence.';
        });
        return;
      }

      if (!AiConfig.instance.isConfigured) {
        setState(() {
          _status = _ReviewStatus.error;
          _errorMessage =
              'AI is not configured. Add your Anthropic API key in Settings → AI.';
        });
        return;
      }

      // Wait for itinerary to load if needed
      if (_itinProvider.isLoading) {
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (mounted) await _generate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status       = _ReviewStatus.error;
          _errorMessage = 'Failed to load trip data. Please try again.\n$e';
        });
      }
    }
  }

  // ── Generate ──────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() {
      _status       = _ReviewStatus.generating;
      _errorMessage = null;
      _draft        = null;
    });

    try {
      final repos  = AppRepositories.instance;
      final teamId = repos?.currentTeamId ?? '';

      final input = ItinerarySequenceInput(
        trip:              widget.trip,
        existingDays:      _itinProvider.days,
        existingItemsByDay:_itinProvider.itemsByDayId,
        components:        _components,
      );

      final service = AssistedItinerarySequenceService(
        provider: ClaudeAiProvider(),
      );

      final suggestion = await service.generate(
        input:  input,
        tripId: widget.trip.id,
        teamId: teamId,
      );

      if (suggestion == null) {
        setState(() {
          _status       = _ReviewStatus.error;
          _errorMessage =
              'The AI returned an unexpected response. Please try again.';
        });
        return;
      }

      // Save to DB (best-effort — don't fail the flow if it errors)
      AiSuggestion saved = suggestion;
      if (repos?.aiSuggestions != null) {
        try {
          saved = await repos!.aiSuggestions.create(suggestion);
        } catch (_) {}
      }

      final draft = ItinerarySequenceDraft.fromPayload(saved.proposedPayload);

      // Initialise all items as included
      final included = <String, bool>{};
      for (final day in draft.days) {
        for (final item in day.items) {
          included[item.id] = true;
        }
      }

      if (mounted) {
        setState(() {
          _suggestion = saved;
          _draft      = draft;
          _included   = included;
          _status     = _ReviewStatus.reviewing;
        });
      }
    } on AiProviderException catch (e) {
      if (mounted) {
        setState(() {
          _status       = _ReviewStatus.error;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status       = _ReviewStatus.error;
          _errorMessage = 'Generation failed. Please try again.\n$e';
        });
      }
    }
  }

  // ── Apply ─────────────────────────────────────────────────────────────────

  Future<void> _apply() async {
    final draft  = _draft;
    final repos  = AppRepositories.instance;
    if (draft == null || repos?.itinerary == null) return;

    final includedCount =
        _included.values.where((v) => v).length;
    if (includedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected to apply.')),
      );
      return;
    }

    // Warn if the itinerary already has items
    final existingCount = _itinProvider.itemsByDayId.values
        .fold(0, (s, items) => s + items.length);
    if (existingCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Itinerary already has items'),
          content: Text(
            'The live itinerary already has $existingCount item(s) scheduled.\n\n'
            'The sequence will add new items alongside the existing ones — '
            'nothing will be overwritten.\n\n'
            'Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add Items'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _status = _ReviewStatus.applying);

    final result = await const ItinerarySequenceApplyService().apply(
      draft:              draft,
      includedItems:      _included,
      itemEdits:          _edits,
      existingDays:       _itinProvider.days,
      existingItemsByDay: _itinProvider.itemsByDayId,
      repository:         repos!.itinerary,
      teamId:             repos.currentTeamId ?? '',
    );

    // Mark the suggestion as applied
    if (_suggestion?.id.isNotEmpty == true) {
      try {
        await repos.aiSuggestions.updateStatus(
          _suggestion!.id,
          AiSuggestionStatus.applied,
          reviewedAt: DateTime.now(),
        );
      } catch (_) {}
    }

    // Refresh itinerary so the new items appear
    await _itinProvider.reload();

    if (mounted) {
      setState(() {
        _applyResult = result;
        _status      = _ReviewStatus.done;
      });
    }
  }

  // ── Approve all / deselect all ─────────────────────────────────────────────

  void _approveAll() {
    setState(() {
      for (final key in _included.keys) {
        _included[key] = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (final key in _included.keys) {
        _included[key] = false;
      }
    });
  }

  int get _selectedCount => _included.values.where((v) => v).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation:       0,
        leading: IconButton(
          icon:    const Icon(Icons.close_rounded, size: 20),
          color:   AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assisted Itinerary Sequencing',
                style: AppTextStyles.heading3),
            Text(widget.trip.name,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: _buildAppBarActions(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_status != _ReviewStatus.reviewing) return [];
    return [
      TextButton(
        onPressed: _deselectAll,
        child: Text('Deselect All',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary)),
      ),
      TextButton(
        onPressed: _approveAll,
        child: Text('Select All',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.accent)),
      ),
      const SizedBox(width: AppSpacing.sm),
    ];
  }

  Widget _buildBody() {
    return switch (_status) {
      _ReviewStatus.preparing  => _buildLoading('Loading trip data…'),
      _ReviewStatus.generating => _buildGenerating(),
      _ReviewStatus.applying   => _buildLoading('Applying to itinerary…'),
      _ReviewStatus.error      => _buildError(),
      _ReviewStatus.done       => _buildDone(),
      _ReviewStatus.reviewing  => _buildReview(),
    };
  }

  // ── Status screens ────────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width:  32,
            height: 32,
            child:  CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color:        const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.view_timeline_rounded,
                  size: 26, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Analysing Components…',
                style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The AI is reviewing ${_components.length} confirmed components\n'
              'and building a day-by-day sequence draft.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width:  24,
              height: 24,
              child:  CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF0F766E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 36, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.base),
            Text('Could not generate sequence',
                style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _prepare,
              icon:  const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    final r = _applyResult!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color:        const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 28, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Sequence Applied', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${r.created} item${r.created == 1 ? '' : 's'} added to the itinerary'
              '${r.skipped > 0 ? ' · ${r.skipped} skipped' : ''}.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              ...r.warnings.map((w) => _WarningRow(text: w)),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Itinerary'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Review screen ─────────────────────────────────────────────────────────

  Widget _buildReview() {
    final draft = _draft!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.xl,
        AppSpacing.pagePaddingH,
        120, // leave room for bottom bar
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary header ─────────────────────────────────────────────
          _SummaryHeader(draft: draft, selectedCount: _selectedCount),
          const SizedBox(height: AppSpacing.xl),

          // ── Conflict / itinerary warning ───────────────────────────────
          if (_itinProvider.days.isEmpty)
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              color: const Color(0xFF0891B2),
              message: 'No itinerary days exist yet. Create days in the '
                  'Itinerary Builder first — items can only be applied to existing days.',
            ),

          // ── Day cards ──────────────────────────────────────────────────
          ...draft.days.asMap().entries.map((e) {
            final dayIdx = e.key;
            final day    = e.value;
            return ItinerarySequenceDayCard(
              key:             ValueKey('day_$dayIdx'),
              day:             day,
              dayIndex:        dayIdx,
              includedItems:   _included,
              onToggleItem:    (id, v)  => setState(() => _included[id] = v),
              onRemoveItem:    (id)     => setState(() => _included[id] = false),
              onEditTitle:     (id, t)  => setState(() {
                _edits[id] = {...(_edits[id] ?? {}), 'title': t};
              }),
              onEditTimeBlock: (id, tb) => setState(() {
                _edits[id] = {...(_edits[id] ?? {}), 'timeBlock': tb};
              }),
            );
          }),

          // ── Unplaced components ────────────────────────────────────────
          if (draft.unplaced.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _UnplacedPanel(unplaced: draft.unplaced),
          ],

          // ── Global notes ───────────────────────────────────────────────
          if (draft.globalPacingNotes.isNotEmpty ||
              draft.globalRoutingNotes.isNotEmpty ||
              draft.missingDataWarnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            _GlobalNotesPanel(draft: draft),
          ],
        ],
      ),
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget? _buildBottomBar() {
    if (_status != _ReviewStatus.reviewing) return null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.md,
        AppSpacing.pagePaddingH,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('Dismiss'),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _generate,
            icon:  const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Regenerate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _selectedCount > 0 ? _apply : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
            ),
            child: Text(
              _selectedCount > 0
                  ? 'Apply $_selectedCount Item${_selectedCount == 1 ? '' : 's'}'
                  : 'No Items Selected',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final ItinerarySequenceDraft draft;
  final int                    selectedCount;
  const _SummaryHeader({required this.draft, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final s = draft.summary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: const Color(0xFF0F766E).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_timeline_rounded,
                  size: 16, color: Color(0xFF0F766E)),
              const SizedBox(width: 7),
              Text('Sequence Draft Ready',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color:      const Color(0xFF0F766E),
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: 6,
            children: [
              _Stat(value: '${s.componentsAnalyzed}', label: 'analysed'),
              _Stat(value: '${s.componentsPlaced}',   label: 'placed'),
              if (s.unplacedCount > 0)
                _Stat(
                    value: '${s.unplacedCount}',
                    label: 'unplaced',
                    warn: true),
              if (s.timingConflicts > 0)
                _Stat(
                    value: '${s.timingConflicts}',
                    label: 'conflicts',
                    warn: true),
              _Stat(value: '$selectedCount',          label: 'selected'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool   warn;
  const _Stat({required this.value, required this.label, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color:      warn
                  ? const Color(0xFFD97706)
                  : const Color(0xFF0F766E),
            )),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.labelSmall.copyWith(
              color: warn ? const Color(0xFFD97706) : AppColors.textSecondary,
            )),
      ],
    );
  }
}

class _UnplacedPanel extends StatelessWidget {
  final List<UnplacedComponent> unplaced;
  const _UnplacedPanel({required this.unplaced});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: const Color(0xFFD97706).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                '${unplaced.length} component${unplaced.length == 1 ? '' : 's'} could not be placed',
                style: AppTextStyles.labelMedium.copyWith(
                    color: const Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...unplaced.map((u) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: Color(0xFFD97706), fontSize: 11)),
                    Expanded(
                      child: Text(
                        '${u.title} — ${u.reason}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: const Color(0xFF92400E), height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _GlobalNotesPanel extends StatelessWidget {
  final ItinerarySequenceDraft draft;
  const _GlobalNotesPanel({required this.draft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color:        AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes & Warnings',
              style: AppTextStyles.labelMedium
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          for (final n in draft.globalPacingNotes)
            _GlobalNoteRow(
                icon: Icons.timer_outlined,
                color: const Color(0xFF0891B2),
                text: n),
          for (final n in draft.globalRoutingNotes)
            _GlobalNoteRow(
                icon: Icons.route_outlined,
                color: const Color(0xFFD97706),
                text: n),
          for (final w in draft.missingDataWarnings)
            _GlobalNoteRow(
                icon: Icons.info_outline_rounded,
                color: AppColors.textSecondary,
                text: w),
        ],
      ),
    );
  }
}

class _GlobalNoteRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _GlobalNoteRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   message;
  const _InfoBanner(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border:       Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.labelSmall
                    .copyWith(color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final String text;
  const _WarningRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF92400E), height: 1.5)),
          ),
        ],
      ),
    );
  }
}
