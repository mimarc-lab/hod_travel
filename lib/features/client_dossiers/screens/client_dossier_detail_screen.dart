import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
import '../../security/dossier_access_guard.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/effective_permission.dart';
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

class _ClientDossierDetailScreenState
    extends State<ClientDossierDetailScreen> {
  List<ClientQuestionnaireResponse> _responses = [];
  bool _loadingResponses = false;
  EffectivePermission _perm = EffectivePermission.denied;

  @override
  void initState() {
    super.initState();
    _loadResponses();
    _resolvePermissions();
  }

  Future<void> _resolvePermissions() async {
    final repos = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    if (repos == null || teamId.isEmpty) return;
    final perm = await repos.permissions.resolve(teamId);
    if (mounted) setState(() => _perm = perm);
    repos.auditLogs.logDossierView(widget.dossier.id);
  }

  Future<void> _loadResponses() async {
    setState(() => _loadingResponses = true);
    _responses = await widget.provider
        .fetchQuestionnaireResponses(widget.dossier.id);
    if (mounted) setState(() => _loadingResponses = false);
  }

  void _openQuestionnaire(ClientDossier dossier) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientQuestionnaireScreen(
        dossier: dossier,
        provider: widget.provider,
      ),
    ));
    _loadResponses();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final dossier =
            widget.provider.findById(widget.dossier.id) ?? widget.dossier;
        final isMobile = Responsive.isMobile(context);

        return Scaffold(
          backgroundColor: const Color(0xFFFAF9F7),
          body: Column(
            children: [
              _ProfileHeader(
                dossier: dossier,
                canEdit: _perm.canEditDossier,
                onEditTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientDossierFormScreen(
                      provider: widget.provider,
                      existing: dossier,
                    ),
                  ));
                },
                onQuestionnaireTap: () => _openQuestionnaire(dossier),
                onDeleteTap: () => _confirmDelete(context, dossier),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile
                        ? AppSpacing.pagePaddingHMobile
                        : AppSpacing.pagePaddingH,
                    vertical: AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: isMobile
                          ? _MobileLayout(
                              dossier: dossier,
                              provider: widget.provider,
                              perm: _perm,
                              responses: _responses,
                              loadingResponses: _loadingResponses,
                              onQuestionnaire: () =>
                                  _openQuestionnaire(dossier),
                              onLoadResponses: _loadResponses,
                            )
                          : _DesktopLayout(
                              dossier: dossier,
                              provider: widget.provider,
                              perm: _perm,
                              responses: _responses,
                              loadingResponses: _loadingResponses,
                              onQuestionnaire: () =>
                                  _openQuestionnaire(dossier),
                              onLoadResponses: _loadResponses,
                            ),
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

  Future<void> _confirmDelete(
      BuildContext context, ClientDossier dossier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

// ── Desktop two-column layout ─────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final EffectivePermission perm;
  final List<ClientQuestionnaireResponse> responses;
  final bool loadingResponses;
  final VoidCallback onQuestionnaire;
  final VoidCallback onLoadResponses;

  const _DesktopLayout({
    required this.dossier,
    required this.provider,
    required this.perm,
    required this.responses,
    required this.loadingResponses,
    required this.onQuestionnaire,
    required this.onLoadResponses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — profile + preferences
        Expanded(
          flex: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileSummaryCard(dossier: dossier),
              const SizedBox(height: AppSpacing.base),
              _TravelPersonalityCard(dossier: dossier),
              if (dossier.groupDynamicNotes != null) ...[
                const SizedBox(height: AppSpacing.base),
                _GroupDynamicCard(dossier: dossier),
              ],
              const SizedBox(height: AppSpacing.base),
              _PreferenceSnapshotCard(dossier: dossier),
              if (dossier.prefersLateStarts ||
                  dossier.dislikesCrowds ||
                  dossier.heatTolerance != null ||
                  dossier.walkingTolerance != null ||
                  dossier.accessibilityNotes != null ||
                  dossier.photographySensitivity != null ||
                  dossier.securitySensitivity != null) ...[
                const SizedBox(height: AppSpacing.base),
                _BehavioralSection(dossier: dossier),
              ],
              if (AppRepositories.instance?.aiMemory != null) ...[
                const SizedBox(height: AppSpacing.base),
                DossierSectionCard(
                  title: 'AI-Learned Preferences',
                  subtitle: 'Inferred from suggestion feedback.',
                  child: InferredPreferencesPanel(
                    dossierId: dossier.id,
                    repo: AppRepositories.instance!.aiMemory,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.base),
              _QuestionnaireHistoryCard(
                dossier: dossier,
                provider: provider,
                responses: responses,
                loadingResponses: loadingResponses,
                onQuestionnaire: onQuestionnaire,
                onLoadResponses: onLoadResponses,
              ),
              const SizedBox(height: AppSpacing.massive),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        // Right column — travelers + questionnaire status + confidential
        Expanded(
          flex: 42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TravelersSection(dossier: dossier, provider: provider),
              const SizedBox(height: AppSpacing.base),
              _QuestionnaireStatusCard(
                dossier: dossier,
                responses: responses,
                onTap: onQuestionnaire,
              ),
              if (perm.canViewSensitiveNotes) ...[
                const SizedBox(height: AppSpacing.base),
                PermissionGate(
                  allowed: perm.canViewSensitiveNotes,
                  child: _ConfidentialNotesSection(dossier: dossier),
                ),
              ],
              const SizedBox(height: AppSpacing.massive),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mobile single-column layout ───────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final EffectivePermission perm;
  final List<ClientQuestionnaireResponse> responses;
  final bool loadingResponses;
  final VoidCallback onQuestionnaire;
  final VoidCallback onLoadResponses;

  const _MobileLayout({
    required this.dossier,
    required this.provider,
    required this.perm,
    required this.responses,
    required this.loadingResponses,
    required this.onQuestionnaire,
    required this.onLoadResponses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileSummaryCard(dossier: dossier),
        const SizedBox(height: AppSpacing.base),
        _QuestionnaireStatusCard(
          dossier: dossier,
          responses: responses,
          onTap: onQuestionnaire,
        ),
        const SizedBox(height: AppSpacing.base),
        _TravelersSection(dossier: dossier, provider: provider),
        const SizedBox(height: AppSpacing.base),
        _TravelPersonalityCard(dossier: dossier),
        if (dossier.groupDynamicNotes != null) ...[
          const SizedBox(height: AppSpacing.base),
          _GroupDynamicCard(dossier: dossier),
        ],
        const SizedBox(height: AppSpacing.base),
        _PreferenceSnapshotCard(dossier: dossier),
        if (dossier.prefersLateStarts ||
            dossier.dislikesCrowds ||
            dossier.heatTolerance != null ||
            dossier.walkingTolerance != null ||
            dossier.accessibilityNotes != null) ...[
          const SizedBox(height: AppSpacing.base),
          _BehavioralSection(dossier: dossier),
        ],
        if (perm.canViewSensitiveNotes) ...[
          const SizedBox(height: AppSpacing.base),
          PermissionGate(
            allowed: perm.canViewSensitiveNotes,
            child: _ConfidentialNotesSection(dossier: dossier),
          ),
        ],
        if (AppRepositories.instance?.aiMemory != null) ...[
          const SizedBox(height: AppSpacing.base),
          DossierSectionCard(
            title: 'AI-Learned Preferences',
            subtitle: 'Inferred from suggestion feedback.',
            child: InferredPreferencesPanel(
              dossierId: dossier.id,
              repo: AppRepositories.instance!.aiMemory,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.base),
        _QuestionnaireHistoryCard(
          dossier: dossier,
          provider: provider,
          responses: responses,
          loadingResponses: loadingResponses,
          onQuestionnaire: onQuestionnaire,
          onLoadResponses: onLoadResponses,
        ),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ClientDossier dossier;
  final bool canEdit;
  final VoidCallback onEditTap;
  final VoidCallback onQuestionnaireTap;
  final VoidCallback onDeleteTap;

  const _ProfileHeader({
    required this.dossier,
    required this.canEdit,
    required this.onEditTap,
    required this.onQuestionnaireTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
            bottom: BorderSide(color: Color(0xFFEDECEA))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back nav + private badge
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Client Dossiers',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                const Spacer(),
                // Private Dossier indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDDBD8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Private Dossier',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main profile row
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 18),
            child: isMobile
                ? _MobileHeaderContent(
                    dossier: dossier,
                    canEdit: canEdit,
                    onQuestionnaireTap: onQuestionnaireTap,
                    onEditTap: onEditTap,
                    onDeleteTap: onDeleteTap,
                  )
                : _DesktopHeaderContent(
                    dossier: dossier,
                    canEdit: canEdit,
                    onQuestionnaireTap: onQuestionnaireTap,
                    onEditTap: onEditTap,
                    onDeleteTap: onDeleteTap,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DesktopHeaderContent extends StatelessWidget {
  final ClientDossier dossier;
  final bool canEdit;
  final VoidCallback onQuestionnaireTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  const _DesktopHeaderContent({
    required this.dossier,
    required this.canEdit,
    required this.onQuestionnaireTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        _ProfileAvatar(name: dossier.displayName, size: 56),
        const SizedBox(width: AppSpacing.base),

        // Name + meta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dossier.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.2,
                  )),
              if (dossier.familyName != null) ...[
                const SizedBox(height: 2),
                Text(
                  dossier.familyName!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _MetaPills(dossier: dossier),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),

        // Actions
        _HeaderActions(
          canEdit: canEdit,
          onQuestionnaireTap: onQuestionnaireTap,
          onEditTap: onEditTap,
          onDeleteTap: onDeleteTap,
          isMobile: false,
        ),
      ],
    );
  }
}

class _MobileHeaderContent extends StatelessWidget {
  final ClientDossier dossier;
  final bool canEdit;
  final VoidCallback onQuestionnaireTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  const _MobileHeaderContent({
    required this.dossier,
    required this.canEdit,
    required this.onQuestionnaireTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ProfileAvatar(name: dossier.displayName, size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dossier.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  if (dossier.familyName != null)
                    Text(
                      dossier.familyName!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Overflow menu on mobile
            _HeaderActions(
              canEdit: canEdit,
              onQuestionnaireTap: onQuestionnaireTap,
              onEditTap: onEditTap,
              onDeleteTap: onDeleteTap,
              isMobile: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetaPills(dossier: dossier),
        const SizedBox(height: 12),
        // Questionnaire as primary CTA on mobile
        GestureDetector(
          onTap: onQuestionnaireTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Questionnaire',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _ProfileAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7EDD8), Color(0xFFF0D9A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accentLight, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: AppColors.accentDark,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _MetaPills extends StatelessWidget {
  final ClientDossier dossier;
  const _MetaPills({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final items = <_MetaItem>[];
    if (dossier.typicalTripType != null) {
      items.add(_MetaItem(
          icon: Icons.luggage_outlined,
          label: dossier.typicalTripType!.label));
    }
    if (dossier.homeBase != null) {
      items.add(_MetaItem(
          icon: Icons.location_on_outlined, label: dossier.homeBase!));
    }
    if (dossier.nationality != null) {
      items.add(_MetaItem(
          icon: Icons.flag_outlined, label: dossier.nationality!));
    }
    items.add(_MetaItem(
        icon: Icons.update_outlined,
        label: 'Updated ${DateFormat('d MMM yyyy').format(dossier.updatedAt)}'));

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDDBD8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String label;
  _MetaItem({required this.icon, required this.label});
}

class _HeaderActions extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onQuestionnaireTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  final bool isMobile;

  const _HeaderActions({
    required this.canEdit,
    required this.onQuestionnaireTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'questionnaire') onQuestionnaireTap();
          if (v == 'edit') onEditTap();
          if (v == 'delete') onDeleteTap();
        },
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'questionnaire',
            child: Row(children: [
              Icon(Icons.assignment_outlined, size: 15),
              SizedBox(width: 8),
              Text('Questionnaire'),
            ]),
          ),
          if (canEdit)
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 15),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded,
                  size: 15, color: Color(0xFFB00020)),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: Color(0xFFB00020))),
            ]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              size: 16, color: AppColors.textSecondary),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Questionnaire
        GestureDetector(
          onTap: onQuestionnaireTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Questionnaire',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (canEdit) ...[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onEditTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('Edit',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onDeleteTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                size: 14, color: Color(0xFFB00020)),
          ),
        ),
      ],
    );
  }
}

// ── Profile Summary Card ──────────────────────────────────────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  final ClientDossier dossier;
  const _ProfileSummaryCard({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Profile Summary',
      child: Column(
        children: [
          DossierInfoRow(
              label: 'Primary contact',
              value: dossier.primaryClientName),
          if (dossier.familyName != null)
            DossierInfoRow(
                label: 'Family / group',
                value: dossier.familyName),
          if (dossier.email != null)
            DossierInfoRow(label: 'Email', value: dossier.email),
          if (dossier.phone != null)
            DossierInfoRow(label: 'Phone', value: dossier.phone),
          if (dossier.nationality != null)
            DossierInfoRow(
                label: 'Nationality', value: dossier.nationality),
          if (dossier.homeBase != null)
            DossierInfoRow(
                label: 'Home base', value: dossier.homeBase),
          if (dossier.typicalTripType != null)
            DossierInfoRow(
                label: 'Trip type',
                value: dossier.typicalTripType!.label),
        ],
      ),
    );
  }
}

// ── Travel Personality Card ───────────────────────────────────────────────────

class _TravelPersonalityCard extends StatelessWidget {
  final ClientDossier dossier;
  const _TravelPersonalityCard({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final hasStyle = dossier.pacingPreference != null ||
        dossier.privacyPreference != null ||
        dossier.luxuryLevel != null ||
        dossier.guidePreference != null ||
        dossier.structurePreference != null;

    if (!hasStyle) return const SizedBox.shrink();

    return DossierSectionCard(
      title: 'Travel Personality',
      subtitle: 'Style and comfort preferences.',
      child: Column(
        children: [
          if (dossier.pacingPreference != null)
            DossierInfoRow(
                label: 'Pacing',
                value: dossier.pacingPreference!.label),
          if (dossier.luxuryLevel != null)
            DossierInfoRow(
                label: 'Luxury level',
                value: dossier.luxuryLevel!.label),
          if (dossier.privacyPreference != null)
            DossierInfoRow(
                label: 'Privacy',
                value: dossier.privacyPreference!.label),
          if (dossier.guidePreference != null)
            DossierInfoRow(
                label: 'Guide preference',
                value: dossier.guidePreference!.label),
          if (dossier.structurePreference != null)
            DossierInfoRow(
                label: 'Structure',
                value: dossier.structurePreference!.label),
        ],
      ),
    );
  }
}

// ── Group Dynamic Card ────────────────────────────────────────────────────────

class _GroupDynamicCard extends StatelessWidget {
  final ClientDossier dossier;
  const _GroupDynamicCard({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Group Dynamic',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Text(
          dossier.groupDynamicNotes!,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ── Preference Snapshot Card ──────────────────────────────────────────────────

class _PreferenceSnapshotCard extends StatelessWidget {
  final ClientDossier dossier;
  const _PreferenceSnapshotCard({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (dossier.accommodationType != null) {
      rows.add(DossierInfoRow(
          label: 'Accommodation',
          value: dossier.accommodationType!.label));
    }

    if (dossier.beddingPreferences != null) {
      rows.add(DossierInfoRow(
          label: 'Bedding', value: dossier.beddingPreferences!));
    }

    if (dossier.wellnessImportance != null) {
      rows.add(DossierInfoRow(
          label: 'Wellness / spa',
          value: dossier.wellnessImportance!.label));
    }

    if (dossier.amenityPreferences.isNotEmpty) {
      rows.add(_ChipRow(
          label: 'Amenities', chips: dossier.amenityPreferences));
    }

    if (dossier.diningStyle != null) {
      rows.add(DossierInfoRow(
          label: 'Dining style', value: dossier.diningStyle!.label));
    }

    if (dossier.cuisinePreferences.isNotEmpty) {
      rows.add(
          _ChipRow(label: 'Cuisines', chips: dossier.cuisinePreferences));
    }

    if (dossier.dietaryRestrictions.isNotEmpty) {
      rows.add(_ChipRow(
          label: 'Dietary',
          chips: dossier.dietaryRestrictions,
          alert: true));
    }

    if (dossier.allergies.isNotEmpty) {
      rows.add(
          _ChipRow(label: 'Allergies', chips: dossier.allergies, alert: true));
    }

    if (dossier.diningDislikes.isNotEmpty) {
      rows.add(DossierInfoRow(
          label: 'Dislikes',
          value: dossier.diningDislikes.join(', ')));
    }

    // Experience interest bars
    final interestRows = <Widget>[];
    if (dossier.culturalInterest > 0) {
      interestRows.add(InterestBar(
          label: 'Cultural / heritage',
          level: dossier.culturalInterest));
    }
    if (dossier.adventureInterest > 0) {
      interestRows.add(InterestBar(
          label: 'Adventure / active',
          level: dossier.adventureInterest));
    }
    if (dossier.relaxationInterest > 0) {
      interestRows.add(InterestBar(
          label: 'Relaxation', level: dossier.relaxationInterest));
    }
    if (dossier.intellectualInterest > 0) {
      interestRows.add(InterestBar(
          label: 'Intellectual', level: dossier.intellectualInterest));
    }
    if (dossier.shoppingInterest > 0) {
      interestRows.add(InterestBar(
          label: 'Shopping', level: dossier.shoppingInterest));
    }

    if (rows.isEmpty && interestRows.isEmpty) return const SizedBox.shrink();

    return DossierSectionCard(
      title: 'Preference Snapshot',
      subtitle: 'Accommodation, dining and activity interests.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          if (rows.isNotEmpty && interestRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Text('Experience interests',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                )),
            const SizedBox(height: 6),
          ],
          ...interestRows,
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> chips;
  final bool alert;
  const _ChipRow(
      {required this.label, required this.chips, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: chips
                  .map((c) =>
                      alert ? AlertChip(label: c) : PreferenceChip(label: c))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Behavioral Section ────────────────────────────────────────────────────────

class _BehavioralSection extends StatelessWidget {
  final ClientDossier dossier;
  const _BehavioralSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Behavioral & Comfort',
      child: Column(
        children: [
          if (dossier.prefersLateStarts)
            DossierInfoRow(
                label: 'Start times',
                value: 'Prefers late morning starts (10am+)'),
          if (dossier.dislikesCrowds)
            DossierInfoRow(
                label: 'Crowds',
                value: 'Sensitive — avoid busy venues'),
          if (dossier.heatTolerance != null)
            DossierInfoRow(
                label: 'Heat tolerance',
                value: dossier.heatTolerance!.label),
          if (dossier.walkingTolerance != null)
            DossierInfoRow(
                label: 'Walking',
                value: dossier.walkingTolerance!.label),
          if (dossier.accessibilityNotes != null)
            DossierInfoRow(
                label: 'Accessibility',
                value: dossier.accessibilityNotes!),
          if (dossier.photographySensitivity != null)
            DossierInfoRow(
                label: 'Photography',
                value: dossier.photographySensitivity!),
          if (dossier.securitySensitivity != null)
            DossierInfoRow(
                label: 'Security', value: dossier.securitySensitivity!),
        ],
      ),
    );
  }
}

// ── Travelers Section ─────────────────────────────────────────────────────────

class _TravelersSection extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  const _TravelersSection(
      {required this.dossier, required this.provider});

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Traveler Profiles',
      subtitle: 'Individual preferences within the group.',
      trailing: GestureDetector(
        onTap: () async {
          final result = await showTravelerFormSheet(
            context,
            dossierId: dossier.id,
          );
          if (result != null) await provider.addTraveler(result);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentFaint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded,
                  size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
      child: dossier.travelers.isEmpty
          ? _TravelersEmptyState(
              onAdd: () async {
                final result = await showTravelerFormSheet(
                  context,
                  dossierId: dossier.id,
                );
                if (result != null) await provider.addTraveler(result);
              },
            )
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
                          if (result != null) {
                            await provider.updateTraveler(result);
                          }
                        },
                        onDelete: () =>
                            provider.deleteTraveler(t.id, dossier.id),
                      ))
                  .toList(),
            ),
    );
  }
}

class _TravelersEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _TravelersEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No traveler profiles added yet.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add individual profiles for preferences,\nrooming, dietary needs, and special notes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accentFaint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Add Traveler',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Questionnaire Status Card ─────────────────────────────────────────────────

class _QuestionnaireStatusCard extends StatelessWidget {
  final ClientDossier dossier;
  final List<ClientQuestionnaireResponse> responses;
  final VoidCallback onTap;

  const _QuestionnaireStatusCard({
    required this.dossier,
    required this.responses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = responses
        .where((r) => !r.isDraft)
        .toList()
      ..sort((a, b) => (b.completedAt ?? DateTime(0))
          .compareTo(a.completedAt ?? DateTime(0)));

    final hasCompleted = submitted.isNotEmpty;
    final latest = hasCompleted ? submitted.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasCompleted
              ? const Color(0xFFF0FAF4)
              : const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasCompleted
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFFDE68A),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withAlpha(8),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasCompleted
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasCompleted
                    ? Icons.check_circle_outline_rounded
                    : Icons.assignment_outlined,
                size: 20,
                color: hasCompleted
                    ? const Color(0xFF065F46)
                    : const Color(0xFF92400E),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCompleted
                        ? 'Questionnaire Completed'
                        : 'Questionnaire Pending',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasCompleted
                          ? const Color(0xFF065F46)
                          : const Color(0xFF92400E),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasCompleted && latest?.completedAt != null
                        ? 'Last submitted ${DateFormat('d MMM yyyy').format(latest!.completedAt)}'
                        : 'Tap to start the preference questionnaire',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: hasCompleted
                          ? const Color(0xFF065F46).withAlpha(160)
                          : const Color(0xFF92400E).withAlpha(160),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: hasCompleted
                  ? const Color(0xFF065F46).withAlpha(120)
                  : const Color(0xFF92400E).withAlpha(120),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confidential Notes Section ────────────────────────────────────────────────

class _ConfidentialNotesSection extends StatelessWidget {
  final ClientDossier dossier;
  const _ConfidentialNotesSection({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final hasInternal = dossier.internalNotes != null ||
        dossier.pastFeedbackNotes != null ||
        dossier.serviceStyleNotes != null ||
        dossier.operationalFlags.isNotEmpty;

    if (!hasInternal) return const SizedBox.shrink();

    return DossierSectionCard(
      title: 'Confidential Notes',
      subtitle: 'Visible to authorized team members only.',
      isInternal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dossier.internalNotes != null)
            _NoteBlock(
                label: 'Internal notes', text: dossier.internalNotes!),
          if (dossier.pastFeedbackNotes != null)
            _NoteBlock(
                label: 'Past feedback',
                text: dossier.pastFeedbackNotes!),
          if (dossier.serviceStyleNotes != null)
            _NoteBlock(
                label: 'Service style',
                text: dossier.serviceStyleNotes!),
          if (dossier.operationalFlags.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Operational flags',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
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

class _NoteBlock extends StatelessWidget {
  final String label;
  final String text;
  const _NoteBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Questionnaire History Card ────────────────────────────────────────────────

class _QuestionnaireHistoryCard extends StatelessWidget {
  final ClientDossier dossier;
  final ClientDossierProvider provider;
  final List<ClientQuestionnaireResponse> responses;
  final bool loadingResponses;
  final VoidCallback onQuestionnaire;
  final VoidCallback onLoadResponses;

  const _QuestionnaireHistoryCard({
    required this.dossier,
    required this.provider,
    required this.responses,
    required this.loadingResponses,
    required this.onQuestionnaire,
    required this.onLoadResponses,
  });

  @override
  Widget build(BuildContext context) {
    return DossierSectionCard(
      title: 'Questionnaire History',
      subtitle: 'Completed preference questionnaires.',
      trailing: GestureDetector(
        onTap: onQuestionnaire,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentFaint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded,
                  size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'New',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
      child: QuestionnaireHistoryList(
        responses: responses,
        isLoading: loadingResponses,
        dossier: dossier,
        provider: provider,
        onRefresh: onLoadResponses,
      ),
    );
  }
}
