import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/client_questionnaire_model.dart';
import '../providers/client_dossier_provider.dart';
import '../widgets/dossier_section_card.dart';
import '../widgets/traveler_profile_card.dart';
import '../questionnaire/questionnaire_history_list.dart';
import '../../ai_memory/widgets/inferred_preferences_panel.dart';
import '../../../core/supabase/app_db.dart';
import 'client_dossier_form_screen.dart';
import 'client_questionnaire_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientDossierDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

class ClientDossierDetailScreen extends StatefulWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;

  const ClientDossierDetailScreen({
    super.key,
    required this.dossier,
    required this.provider,
  });

  @override
  State<ClientDossierDetailScreen> createState() =>
      _ClientDossierDetailScreenState();
}

class _ClientDossierDetailScreenState extends State<ClientDossierDetailScreen> {
  List<ClientQuestionnaireResponse> _responses = [];
  bool _loadingResponses = false;

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    setState(() => _loadingResponses = true);
    _responses = await widget.provider.fetchQuestionnaireResponses(widget.dossier.id);
    if (mounted) setState(() => _loadingResponses = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final dossier = widget.provider.findById(widget.dossier.id) ?? widget.dossier;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _DetailHeader(
                dossier:  dossier,
                provider: widget.provider,
                onEditTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientDossierFormScreen(
                      provider: widget.provider,
                      existing: dossier,
                    ),
                  ));
                },
                onQuestionnaireTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientQuestionnaireScreen(
                      dossier:  dossier,
                      provider: widget.provider,
                    ),
                  ));
                  _loadResponses();
                },
                onDeleteTap: () => _confirmDelete(context, dossier),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.isMobile(context)
                        ? AppSpacing.pagePaddingHMobile
                        : AppSpacing.pagePaddingH,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OverviewSection(dossier: dossier),
                        const SizedBox(height: AppSpacing.xl),

                        _TravelersSection(
                          dossier:  dossier,
                          provider: widget.provider,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        if (dossier.pacingPreference != null ||
                            dossier.luxuryLevel != null ||
                            dossier.privacyPreference != null ||
                            dossier.guidePreference != null ||
                            dossier.structurePreference != null) ...[
                          _TravelStyleSection(dossier: dossier),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        if (dossier.accommodationType != null ||
                            dossier.wellnessImportance != null ||
                            dossier.amenityPreferences.isNotEmpty ||
                            dossier.beddingPreferences != null) ...[
                          _AccommodationSection(dossier: dossier),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        if (dossier.diningStyle != null ||
                            dossier.cuisinePreferences.isNotEmpty ||
                            dossier.dietaryRestrictions.isNotEmpty ||
                            dossier.allergies.isNotEmpty ||
                            dossier.diningDislikes.isNotEmpty) ...[
                          _DiningSection(dossier: dossier),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        _ExperiencesSection(dossier: dossier),
                        const SizedBox(height: AppSpacing.xl),

                        _BehavioralSection(dossier: dossier),
                        const SizedBox(height: AppSpacing.xl),

                        _InternalSection(dossier: dossier),
                        const SizedBox(height: AppSpacing.xl),

                        if (AppRepositories.instance?.aiMemory != null)
                          DossierSectionCard(
                            title: 'AI-Learned Preferences',
                            subtitle: 'Inferred from suggestion feedback.',
                            child: InferredPreferencesPanel(
                              dossierId: dossier.id,
                              repo: AppRepositories.instance!.aiMemory,
                            ),
                          ),
                        if (AppRepositories.instance?.aiMemory != null)
                          const SizedBox(height: AppSpacing.xl),

                        DossierSectionCard(
                          title: 'Questionnaire History',
                          subtitle: 'Completed preference questionnaires.',
                          trailing: GestureDetector(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ClientQuestionnaireScreen(
                                  dossier:  dossier,
                                  provider: widget.provider,
                                ),
                              ));
                              _loadResponses();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accentFaint,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.accentLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text('New',
                                      style: AppTextStyles.labelSmall
                                          .copyWith(
                                              color: AppColors.accent,
                                              fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          child: QuestionnaireHistoryList(
                            responses:  _responses,
                            isLoading:  _loadingResponses,
                            dossier:    dossier,
                            provider:   widget.provider,
                            onRefresh:  _loadResponses,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.massive),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, ClientDossier dossier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete dossier?', style: AppTextStyles.heading3),
        content: Text(
          'This will permanently remove "${dossier.displayName}" and all their '
          'travel profiles and questionnaire history.',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFB00020))),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.provider.deleteDossier(dossier.id);
      Navigator.of(context).pop();
    }
  }
}

// ── Detail header ─────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final VoidCallback onEditTap;
  final VoidCallback onQuestionnaireTap;
  final VoidCallback onDeleteTap;

  const _DetailHeader({
    required this.dossier,
    required this.provider,
    required this.onEditTap,
    required this.onQuestionnaireTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Client Dossiers', style: AppTextStyles.bodySmall),
                Text(' / ', style: AppTextStyles.bodySmall),
                Text(dossier.displayName,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accentFaint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  dossier.displayName.isNotEmpty
                      ? dossier.displayName[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.heading2.copyWith(color: AppColors.accent),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dossier.displayName, style: AppTextStyles.displayMedium),
                    if (dossier.typicalTripType != null ||
                        dossier.homeBase != null)
                      Text(
                        [
                          if (dossier.typicalTripType != null)
                            dossier.typicalTripType!.label,
                          if (dossier.homeBase != null) dossier.homeBase!,
                        ].join(' · '),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              // Questionnaire button
              GestureDetector(
                onTap: onQuestionnaireTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentFaint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 13, color: AppColors.accent),
                      const SizedBox(width: 5),
                      Text('Questionnaire',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Edit button
              GestureDetector(
                onTap: onEditTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text('Edit', style: AppTextStyles.labelMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Delete
              GestureDetector(
                onTap: onDeleteTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: Color(0xFFB00020)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overview section ──────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final ClientDossier dossier;
  const _OverviewSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Overview',
      child: Column(
        children: [
          DossierInfoRow(label: 'Primary contact', value: dossier.primaryClientName),
          if (dossier.familyName != null)
            DossierInfoRow(label: 'Family / group name', value: dossier.familyName),
          if (dossier.email != null)
            DossierInfoRow(label: 'Email', value: dossier.email),
          if (dossier.phone != null)
            DossierInfoRow(label: 'Phone', value: dossier.phone),
          if (dossier.nationality != null)
            DossierInfoRow(label: 'Nationality', value: dossier.nationality),
          if (dossier.homeBase != null)
            DossierInfoRow(label: 'Home base', value: dossier.homeBase),
          if (dossier.typicalTripType != null)
            DossierInfoRow(label: 'Trip type', value: dossier.typicalTripType!.label),
          if (dossier.groupDynamicNotes != null)
            DossierInfoRow(label: 'Group dynamic', value: dossier.groupDynamicNotes),
        ],
      ),
    );
  }
}

// ── Travelers section ─────────────────────────────────────────────────────────

class _TravelersSection extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  const _TravelersSection({required this.dossier, required this.provider});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Travelers',
      subtitle: 'Individual profiles within the group.',
      trailing: GestureDetector(
        onTap: () async {
          final result = await showTravelerFormSheet(
            context,
            dossierId: dossier.id,
          );
          if (result != null) await provider.addTraveler(result);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentFaint,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accentLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('Add',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.accent, fontSize: 11)),
            ],
          ),
        ),
      ),
      child: dossier.travelers.isEmpty
          ? Text('No traveler profiles added yet.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted))
          : Column(
              children: dossier.travelers
                  .map((t) => TravelerProfileCard(
                        traveler: t,
                        onEdit: () async {
                          final result = await showTravelerFormSheet(
                            context,
                            dossierId: dossier.id,
                            existing: t,
                          );
                          if (result != null) await provider.updateTraveler(result);
                        },
                        onDelete: () => provider.deleteTraveler(t.id, dossier.id),
                      ))
                  .toList(),
            ),
    );
  }
}

// ── Travel style section ──────────────────────────────────────────────────────

class _TravelStyleSection extends StatelessWidget {
  final ClientDossier dossier;
  const _TravelStyleSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Travel Style',
      child: Column(
        children: [
          if (dossier.pacingPreference != null)
            DossierInfoRow(label: 'Pacing', value: dossier.pacingPreference!.label),
          if (dossier.privacyPreference != null)
            DossierInfoRow(label: 'Privacy', value: dossier.privacyPreference!.label),
          if (dossier.luxuryLevel != null)
            DossierInfoRow(label: 'Luxury level', value: dossier.luxuryLevel!.label),
          if (dossier.guidePreference != null)
            DossierInfoRow(label: 'Guide preference', value: dossier.guidePreference!.label),
          if (dossier.structurePreference != null)
            DossierInfoRow(label: 'Structure', value: dossier.structurePreference!.label),
        ],
      ),
    );
  }
}

// ── Accommodation section ─────────────────────────────────────────────────────

class _AccommodationSection extends StatelessWidget {
  final ClientDossier dossier;
  const _AccommodationSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Accommodation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dossier.accommodationType != null)
            DossierInfoRow(label: 'Preference', value: dossier.accommodationType!.label),
          if (dossier.wellnessImportance != null)
            DossierInfoRow(label: 'Wellness / spa', value: dossier.wellnessImportance!.label),
          if (dossier.beddingPreferences != null)
            DossierInfoRow(label: 'Bedding', value: dossier.beddingPreferences!),
          if (dossier.amenityPreferences.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Amenity priorities',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dossier.amenityPreferences
                  .map((a) => PreferenceChip(label: a))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dining section ────────────────────────────────────────────────────────────

class _DiningSection extends StatelessWidget {
  final ClientDossier dossier;
  const _DiningSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Dining',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dossier.diningStyle != null)
            DossierInfoRow(label: 'Style', value: dossier.diningStyle!.label),
          if (dossier.alcoholPreference != null)
            DossierInfoRow(label: 'Alcohol', value: dossier.alcoholPreference!),
          if (dossier.cuisinePreferences.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Cuisines',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dossier.cuisinePreferences
                  .map((c) => PreferenceChip(label: c))
                  .toList(),
            ),
          ],
          if (dossier.dietaryRestrictions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Dietary restrictions',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dossier.dietaryRestrictions
                  .map((r) => PreferenceChip(label: r))
                  .toList(),
            ),
          ],
          if (dossier.allergies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Allergies',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dossier.allergies
                  .map((a) => AlertChip(label: a))
                  .toList(),
            ),
          ],
          if (dossier.diningDislikes.isNotEmpty)
            DossierInfoRow(label: 'Dislikes', value: dossier.diningDislikes.join(', ')),
        ],
      ),
    );
  }
}

// ── Experiences section ───────────────────────────────────────────────────────

class _ExperiencesSection extends StatelessWidget {
  final ClientDossier dossier;
  const _ExperiencesSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Experiences',
      subtitle: 'Interest levels on a 1–5 scale.',
      child: Column(
        children: [
          InterestBar(label: 'Cultural / heritage', level: dossier.culturalInterest),
          InterestBar(label: 'Adventure / active', level: dossier.adventureInterest),
          InterestBar(label: 'Intellectual', level: dossier.intellectualInterest),
          InterestBar(label: 'Relaxation', level: dossier.relaxationInterest),
          InterestBar(label: 'Shopping', level: dossier.shoppingInterest),
        ],
      ),
    );
  }
}

// ── Behavioral section ────────────────────────────────────────────────────────

class _BehavioralSection extends StatelessWidget {
  final ClientDossier dossier;
  const _BehavioralSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final hasBehavioral = dossier.prefersLateStarts ||
        dossier.dislikesCrowds ||
        dossier.heatTolerance != null ||
        dossier.walkingTolerance != null ||
        dossier.accessibilityNotes != null ||
        dossier.photographySensitivity != null ||
        dossier.securitySensitivity != null;

    if (!hasBehavioral) return const SizedBox.shrink();

    return DossierSectionCard(
      title: 'Behavioral & Comfort',
      child: Column(
        children: [
          if (dossier.prefersLateStarts)
            DossierInfoRow(label: 'Starts', value: 'Prefers late morning starts (10am+)'),
          if (dossier.dislikesCrowds)
            DossierInfoRow(label: 'Crowds', value: 'Sensitive to crowds — avoid busy venues'),
          if (dossier.heatTolerance != null)
            DossierInfoRow(label: 'Heat tolerance', value: dossier.heatTolerance!.label),
          if (dossier.walkingTolerance != null)
            DossierInfoRow(label: 'Walking tolerance', value: dossier.walkingTolerance!.label),
          if (dossier.accessibilityNotes != null)
            DossierInfoRow(label: 'Accessibility', value: dossier.accessibilityNotes!),
          if (dossier.photographySensitivity != null)
            DossierInfoRow(label: 'Photography', value: dossier.photographySensitivity!),
          if (dossier.securitySensitivity != null)
            DossierInfoRow(label: 'Security', value: dossier.securitySensitivity!),
        ],
      ),
    );
  }
}

// ── Internal section ──────────────────────────────────────────────────────────

class _InternalSection extends StatelessWidget {
  final ClientDossier dossier;
  const _InternalSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final hasInternal = dossier.internalNotes != null ||
        dossier.pastFeedbackNotes != null ||
        dossier.serviceStyleNotes != null ||
        dossier.operationalFlags.isNotEmpty;

    if (!hasInternal) return const SizedBox.shrink();

    return DossierSectionCard(
      title: 'Internal Notes',
      subtitle: 'Visible to team only — not shared with client.',
      isInternal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dossier.internalNotes != null) ...[
            Text('Notes',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            Text(dossier.internalNotes!,
                style: AppTextStyles.bodySmall.copyWith(height: 1.6)),
            const SizedBox(height: AppSpacing.base),
          ],
          if (dossier.pastFeedbackNotes != null) ...[
            Text('Past feedback',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            Text(dossier.pastFeedbackNotes!,
                style: AppTextStyles.bodySmall.copyWith(height: 1.6)),
            const SizedBox(height: AppSpacing.base),
          ],
          if (dossier.serviceStyleNotes != null) ...[
            Text('Service style',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            Text(dossier.serviceStyleNotes!,
                style: AppTextStyles.bodySmall.copyWith(height: 1.6)),
            const SizedBox(height: AppSpacing.base),
          ],
          if (dossier.operationalFlags.isNotEmpty) ...[
            Text('Operational flags',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dossier.operationalFlags
                  .map((f) => AlertChip(label: f))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

