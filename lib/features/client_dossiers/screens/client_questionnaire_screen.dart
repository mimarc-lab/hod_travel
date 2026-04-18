import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_questionnaire_model.dart';
import '../providers/client_dossier_provider.dart';
import '../questionnaire/questionnaire_review_apply_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientQuestionnaireScreen
//
// Full-screen questionnaire capture form.  Supports:
// - Draft save at any point (persisted via provider)
// - Submit → navigates to Review & Apply screen
// - Resume existing draft (pass via [existing])
// - Auto-prompts to resume draft if one exists (when existing == null)
// ─────────────────────────────────────────────────────────────────────────────

class ClientQuestionnaireScreen extends StatefulWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final ClientQuestionnaireResponse? existing;

  const ClientQuestionnaireScreen({
    super.key,
    required this.dossier,
    required this.provider,
    this.existing,
  });

  @override
  State<ClientQuestionnaireScreen> createState() =>
      _ClientQuestionnaireScreenState();
}

class _ClientQuestionnaireScreenState
    extends State<ClientQuestionnaireScreen> {
  final Map<String, dynamic> _responses = {};
  final Map<String, TextEditingController> _controllers = {};
  final _notesCtrl = TextEditingController();
  final _pageController = PageController();

  QuestionnaireSource _source = QuestionnaireSource.internal;
  int _currentSection = 0;
  bool _savingDraft = false;
  bool _submitting = false;
  ClientQuestionnaireResponse? _currentResponse;

  // total = sections + 1 submit page
  int get _totalPages => kDreamMakerQuestionnaire.length + 1;

  @override
  void initState() {
    super.initState();
    _initControllers();
    if (widget.existing != null) {
      _loadFrom(widget.existing!);
    } else {
      _checkForDraft();
    }
  }

  void _initControllers() {
    for (final section in kDreamMakerQuestionnaire) {
      for (final item in section.items) {
        if (item.type == QItemType.text || item.type == QItemType.longText) {
          _controllers[item.key] = TextEditingController();
        }
      }
    }
  }

  void _loadFrom(ClientQuestionnaireResponse response) {
    _currentResponse = response;
    _source = response.source;
    final r = response.responses;

    r.forEach((key, value) {
      if (_controllers.containsKey(key)) {
        _controllers[key]!.text = value?.toString() ?? '';
      } else {
        _responses[key] = value;
      }
    });

    if (response.notes != null) _notesCtrl.text = response.notes!;
  }

  Future<void> _checkForDraft() async {
    final draft =
        await widget.provider.fetchLatestDraft(widget.dossier.id);
    if (draft == null || !mounted) return;

    final resume = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Resume draft?', style: AppTextStyles.heading3),
        content: Text(
          'A draft questionnaire exists for ${widget.dossier.displayName}. '
          'Would you like to continue where you left off?',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Start fresh',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Resume draft',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (resume == true && mounted) {
      setState(() => _loadFrom(draft));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notesCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Responses ────────────────────────────────────────────────────────────

  Map<String, dynamic> _collectResponses() {
    final result = Map<String, dynamic>.from(_responses);
    _controllers.forEach((key, ctrl) {
      final v = ctrl.text.trim();
      if (v.isNotEmpty) result[key] = v;
    });
    return result;
  }

  ClientQuestionnaireResponse _buildResponse({
    required ResponseStatus status,
  }) {
    return ClientQuestionnaireResponse(
      id: _currentResponse?.id ?? '',
      dossierId: widget.dossier.id,
      teamId: widget.dossier.teamId,
      completedAt: _currentResponse?.completedAt ?? DateTime.now(),
      responses: _collectResponses(),
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      source: _source,
      status: status,
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    setState(() => _savingDraft = true);
    try {
      final saved = await widget.provider.upsertDraft(
        _buildResponse(status: ResponseStatus.draft),
        widget.dossier.id,
      );
      if (saved != null) setState(() => _currentResponse = saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Draft saved',
                style: AppTextStyles.labelSmall
                    .copyWith(color: Colors.white)),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _submit() async {
    final count = _collectResponses().length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer at least one question before submitting.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final submitted = await widget.provider.submitResponse(
        _buildResponse(status: ResponseStatus.submitted),
        widget.dossier.id,
      );
      if (submitted == null || !mounted) return;

      final currentDossier =
          widget.provider.findById(widget.dossier.id) ?? widget.dossier;

      final applied = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => QuestionnaireReviewApplyScreen(
            response: submitted,
            dossier: currentDossier,
            provider: widget.provider,
          ),
        ),
      );

      if (mounted) Navigator.of(context).pop(applied ?? false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goTo(int index) {
    setState(() => _currentSection = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_currentSection < _totalPages - 1) _goTo(_currentSection + 1);
  }

  void _prev() {
    if (_currentSection > 0) _goTo(_currentSection - 1);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 20, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preference Questionnaire',
                style: AppTextStyles.labelMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(widget.dossier.displayName,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (_currentResponse?.isDraft == true ||
              _currentSection > 0 ||
              _collectResponses().isNotEmpty)
            TextButton(
              onPressed: _savingDraft ? null : _saveDraft,
              child: _savingDraft
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Text('Save draft',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accent)),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_currentSection + 1) / _totalPages,
            backgroundColor: AppColors.border,
            color: AppColors.accent,
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          _SectionPills(
            sections: kDreamMakerQuestionnaire,
            current: _currentSection,
            onTap: _goTo,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _totalPages,
              onPageChanged: (i) => setState(() => _currentSection = i),
              itemBuilder: (context, index) {
                if (index < kDreamMakerQuestionnaire.length) {
                  return _SectionPage(
                    section: kDreamMakerQuestionnaire[index],
                    responses: _responses,
                    controllers: _controllers,
                    onChoice: (k, v) => setState(() => _responses[k] = v),
                    onMulti: (k, v) => setState(() {
                      final list = List<String>.from(
                          (_responses[k] as List<dynamic>? ?? []).cast());
                      if (list.contains(v)) {
                        list.remove(v);
                      } else {
                        list.add(v);
                      }
                      _responses[k] = list;
                    }),
                    onScale: (k, v) => setState(() => _responses[k] = v),
                    onYesNo: (k, v) => setState(() => _responses[k] = v),
                  );
                }
                return _SubmitPage(
                  notesCtrl: _notesCtrl,
                  source: _source,
                  onSourceChanged: (v) => setState(() => _source = v),
                  responseCount: _collectResponses().length,
                );
              },
            ),
          ),
          _BottomNav(
            currentSection: _currentSection,
            totalPages: _totalPages,
            submitting: _submitting,
            onPrev: _currentSection > 0 ? _prev : null,
            onNext:
                _currentSection < _totalPages - 1 ? _next : null,
            onSubmit:
                _currentSection == _totalPages - 1 ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section pill navigator
// ─────────────────────────────────────────────────────────────────────────────

class _SectionPills extends StatelessWidget {
  final List<QSection> sections;
  final int current;
  final ValueChanged<int> onTap;

  const _SectionPills({
    required this.sections,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < sections.length; i++) ...[
              GestureDetector(
                onTap: () => onTap(i),
                child: _Pill(label: sections[i].title, selected: current == i),
              ),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              onTap: () => onTap(sections.length),
              child: _Pill(
                  label: 'Submit',
                  selected: current == sections.length,
                  isSubmit: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isSubmit;

  const _Pill(
      {required this.label, required this.selected, this.isSubmit = false});

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? (isSubmit ? AppColors.accent : AppColors.accentFaint)
        : AppColors.surfaceAlt;
    final Color border = selected ? AppColors.accent : AppColors.border;
    final Color text = selected
        ? (isSubmit ? Colors.white : AppColors.accent)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: border, width: selected ? 1.5 : 1),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
              color: text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 11)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section page
// ─────────────────────────────────────────────────────────────────────────────

class _SectionPage extends StatelessWidget {
  final QSection section;
  final Map<String, dynamic> responses;
  final Map<String, TextEditingController> controllers;
  final void Function(String, String) onChoice;
  final void Function(String, String) onMulti;
  final void Function(String, int) onScale;
  final void Function(String, bool) onYesNo;

  const _SectionPage({
    required this.section,
    required this.responses,
    required this.controllers,
    required this.onChoice,
    required this.onMulti,
    required this.onScale,
    required this.onYesNo,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(section.title, style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text(section.subtitle,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        for (final item in section.items) ...[
          _QuestionBlock(
            item: item,
            response: responses[item.key],
            controller: controllers[item.key],
            onChoice: onChoice,
            onMulti: onMulti,
            onScale: onScale,
            onYesNo: onYesNo,
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question block
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionBlock extends StatelessWidget {
  final QItem item;
  final dynamic response;
  final TextEditingController? controller;
  final void Function(String, String) onChoice;
  final void Function(String, String) onMulti;
  final void Function(String, int) onScale;
  final void Function(String, bool) onYesNo;

  const _QuestionBlock({
    required this.item,
    required this.response,
    this.controller,
    required this.onChoice,
    required this.onMulti,
    required this.onScale,
    required this.onYesNo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.label,
            style: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600)),
        if (item.hint != null) ...[
          const SizedBox(height: 2),
          Text(item.hint!,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted, fontSize: 11)),
        ],
        const SizedBox(height: 8),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    switch (item.type) {
      case QItemType.choice:
        return _ChoiceGroup(
          options: item.options ?? [],
          selected: response as String?,
          onTap: (v) => onChoice(item.key, v),
        );

      case QItemType.multiChoice:
        final selected = List<String>.from(
            (response as List<dynamic>? ?? []).cast<String>());
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: (item.options ?? []).map((opt) {
            final sel = selected.contains(opt);
            return GestureDetector(
              onTap: () => onMulti(item.key, opt),
              child: _QChip(label: opt, selected: sel),
            );
          }).toList(),
        );

      case QItemType.scale:
        final val = (response as int?) ?? 0;
        return _ScaleInput(
          value: val,
          onChanged: (v) => onScale(item.key, v),
        );

      case QItemType.yesNo:
        final val = response as bool?;
        return Row(
          children: [
            GestureDetector(
              onTap: () => onYesNo(item.key, true),
              child: _QChip(label: 'Yes', selected: val == true),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onYesNo(item.key, false),
              child: _QChip(label: 'No', selected: val == false),
            ),
          ],
        );

      case QItemType.text:
        return _QTextField(ctrl: controller!, maxLines: 1);

      case QItemType.longText:
        return _QTextField(ctrl: controller!, maxLines: 3);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onTap;

  const _ChoiceGroup(
      {required this.options, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options
          .map((opt) => GestureDetector(
                onTap: () => onTap(opt),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == opt
                        ? AppColors.accentFaint
                        : AppColors.surfaceAlt,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    border: Border.all(
                      color: selected == opt
                          ? AppColors.accent
                          : AppColors.border,
                      width: selected == opt ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(opt,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: selected == opt
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                              fontWeight: selected == opt
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ),
                      if (selected == opt)
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.accent),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ScaleInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ScaleInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = {
      1: 'None',
      2: 'Low',
      3: 'Medium',
      4: 'High',
      5: 'Very High'
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final score = i + 1;
            final sel = score <= value;
            return GestureDetector(
              onTap: () => onChanged(score),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 44,
                height: 36,
                decoration: BoxDecoration(
                  color: sel ? AppColors.accentFaint : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel ? AppColors.accent : AppColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text('$score',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: sel ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            );
          }),
        ),
        if (value > 0) ...[
          const SizedBox(height: 4),
          Text('$value / 5 — ${labels[value]}',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted, fontSize: 11)),
        ],
      ],
    );
  }
}

class _QChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _QChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          )),
    );
  }
}

class _QTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final int maxLines;

  const _QTextField({required this.ctrl, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style:
          AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:
              const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit / review page
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitPage extends StatelessWidget {
  final TextEditingController notesCtrl;
  final QuestionnaireSource source;
  final ValueChanged<QuestionnaireSource> onSourceChanged;
  final int responseCount;

  const _SubmitPage({
    required this.notesCtrl,
    required this.source,
    required this.onSourceChanged,
    required this.responseCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text('Review & Submit', style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text(
            'Check your entries, select how responses were collected, '
            'then submit to proceed to the Review & Apply screen.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 24),

        // Answer count
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentFaint,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.accentLight),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 20, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                '$responseCount ${responseCount == 1 ? 'question' : 'questions'} answered',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Source selector
        Text('How were responses collected?',
            style: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...QuestionnaireSource.values.map((s) {
          final label = switch (s) {
            QuestionnaireSource.internal =>
              'Internal entry (from files / notes)',
            QuestionnaireSource.clientCall => 'Client call / meeting',
            QuestionnaireSource.direct    => 'Client submitted directly',
          };
          return GestureDetector(
            onTap: () => onSourceChanged(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: source == s
                    ? AppColors.accentFaint
                    : AppColors.surfaceAlt,
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                  color:
                      source == s ? AppColors.accent : AppColors.border,
                  width: source == s ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: source == s
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: source == s
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ),
                  if (source == s)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.accent),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 20),

        // Internal notes
        Text('Internal notes (optional)',
            style: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Context about this session — not shared with client.',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 8),
        _QTextField(ctrl: notesCtrl, maxLines: 3),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentSection;
  final int totalPages;
  final bool submitting;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;

  const _BottomNav({
    required this.currentSection,
    required this.totalPages,
    required this.submitting,
    this.onPrev,
    this.onNext,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = onSubmit != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onPrev != null)
            OutlinedButton(
              onPressed: onPrev,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: const Text('Back'),
            ),
          const Spacer(),
          Text('${currentSection + 1} / $totalPages',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted)),
          const Spacer(),
          ElevatedButton(
            onPressed: submitting ? null : (isLast ? onSubmit : onNext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.buttonRadius),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isLast ? 'Submit & Review' : 'Next',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
