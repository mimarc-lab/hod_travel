import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/client_dossier_model.dart';
import '../../../data/models/effective_permission.dart';
import '../providers/client_dossier_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientDossierFormScreen
//
// Sectioned create / edit form for a client dossier.
// Sections are displayed as a tab rail (desktop) or a scrollable list (mobile).
// ─────────────────────────────────────────────────────────────────────────────

class ClientDossierFormScreen extends StatefulWidget {
  final ClientDossierProvider provider;
  final ClientDossier? existing;

  const ClientDossierFormScreen({
    super.key,
    required this.provider,
    this.existing,
  });

  @override
  State<ClientDossierFormScreen> createState() =>
      _ClientDossierFormScreenState();
}

class _ClientDossierFormScreenState extends State<ClientDossierFormScreen> {
  bool get _isEdit => widget.existing != null;

  // ── Section navigation ─────────────────────────────────────────────────────
  int _section = 0;
  final _sectionKeys = List.generate(7, (_) => GlobalKey());
  final _scrollCtrl = ScrollController();

  // ── Identity ───────────────────────────────────────────────────────────────
  final _primaryNameCtrl = TextEditingController();
  final _familyNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _homeBaseCtrl = TextEditingController();
  final _groupDynamicCtrl = TextEditingController();
  TripType? _tripType;

  // ── Travel style ───────────────────────────────────────────────────────────
  PacingPreference? _pacing;
  PrivacyPreference? _privacy;
  LuxuryLevel? _luxury;
  GuidePreference? _guide;
  StructurePreference? _structure;

  // ── Accommodation ──────────────────────────────────────────────────────────
  AccommodationType? _accommodationType;
  WellnessImportance? _wellness;
  final _beddingCtrl = TextEditingController();
  Set<String> _amenities = {};

  // ── Dining ─────────────────────────────────────────────────────────────────
  DiningStyle? _diningStyle;
  final _cuisineCtrl = TextEditingController();
  final _dislikesCtrl = TextEditingController();
  final _alcoholCtrl = TextEditingController();
  Set<String> _dietary = {};
  final _allergiesCtrl = TextEditingController();

  // ── Experiences ────────────────────────────────────────────────────────────
  int _cultural = 3;
  int _adventure = 3;
  int _intellectual = 3;
  int _relaxation = 3;
  int _shopping = 3;

  // ── Behavioral ─────────────────────────────────────────────────────────────
  bool _prefersLateStarts = false;
  bool _dislikesCrowds = false;
  HeatTolerance? _heat;
  WalkingTolerance? _walking;
  final _accessibilityCtrl = TextEditingController();
  final _securityCtrl = TextEditingController();
  final _photographyCtrl = TextEditingController();

  // ── Internal ───────────────────────────────────────────────────────────────
  final _internalNotesCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final _serviceStyleCtrl = TextEditingController();
  final _flagsCtrl = TextEditingController();

  bool _isSaving = false;
  EffectivePermission _perm = EffectivePermission.fullAccess; // optimistic until resolved

  @override
  void initState() {
    super.initState();
    _resolvePermissions();
    final e = widget.existing;
    if (e != null) {
      _primaryNameCtrl.text = e.primaryClientName;
      _familyNameCtrl.text = e.familyName ?? '';
      _emailCtrl.text = e.email ?? '';
      _phoneCtrl.text = e.phone ?? '';
      _nationalityCtrl.text = e.nationality ?? '';
      _homeBaseCtrl.text = e.homeBase ?? '';
      _groupDynamicCtrl.text = e.groupDynamicNotes ?? '';
      _tripType = e.typicalTripType;
      _pacing = e.pacingPreference;
      _privacy = e.privacyPreference;
      _luxury = e.luxuryLevel;
      _guide = e.guidePreference;
      _structure = e.structurePreference;
      _accommodationType = e.accommodationType;
      _wellness = e.wellnessImportance;
      _beddingCtrl.text = e.beddingPreferences ?? '';
      _amenities = Set.from(e.amenityPreferences);
      _diningStyle = e.diningStyle;
      _cuisineCtrl.text = e.cuisinePreferences.join(', ');
      _dislikesCtrl.text = e.diningDislikes.join(', ');
      _alcoholCtrl.text = e.alcoholPreference ?? '';
      _dietary = Set.from(e.dietaryRestrictions);
      _allergiesCtrl.text = e.allergies.join(', ');
      _cultural = e.culturalInterest;
      _adventure = e.adventureInterest;
      _intellectual = e.intellectualInterest;
      _relaxation = e.relaxationInterest;
      _shopping = e.shoppingInterest;
      _prefersLateStarts = e.prefersLateStarts;
      _dislikesCrowds = e.dislikesCrowds;
      _heat = e.heatTolerance;
      _walking = e.walkingTolerance;
      _accessibilityCtrl.text = e.accessibilityNotes ?? '';
      _securityCtrl.text = e.securitySensitivity ?? '';
      _photographyCtrl.text = e.photographySensitivity ?? '';
      _internalNotesCtrl.text = e.internalNotes ?? '';
      _feedbackCtrl.text = e.pastFeedbackNotes ?? '';
      _serviceStyleCtrl.text = e.serviceStyleNotes ?? '';
      _flagsCtrl.text = e.operationalFlags.join(', ');
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _primaryNameCtrl,
      _familyNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _nationalityCtrl,
      _homeBaseCtrl,
      _groupDynamicCtrl,
      _beddingCtrl,
      _cuisineCtrl,
      _dislikesCtrl,
      _alcoholCtrl,
      _allergiesCtrl,
      _accessibilityCtrl,
      _securityCtrl,
      _photographyCtrl,
      _internalNotesCtrl,
      _feedbackCtrl,
      _serviceStyleCtrl,
      _flagsCtrl,
    ]) {
      ctrl.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolvePermissions() async {
    final repos  = AppRepositories.instance;
    final teamId = repos?.currentTeamId ?? '';
    if (repos == null || teamId.isEmpty) return;
    final perm = await repos.permissions.resolve(teamId);
    if (mounted) setState(() => _perm = perm);
  }

  // ── Build dossier from form ────────────────────────────────────────────────

  ClientDossier _buildDossier() {
    List<String> split(String v) =>
        v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final now = DateTime.now();
    return ClientDossier(
      id: widget.existing?.id ?? '',
      teamId: widget.existing?.teamId ?? '',
      primaryClientName: _primaryNameCtrl.text.trim(),
      familyName: _familyNameCtrl.text.trim().isNotEmpty
          ? _familyNameCtrl.text.trim()
          : null,
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      nationality: _nationalityCtrl.text.trim().isNotEmpty
          ? _nationalityCtrl.text.trim()
          : null,
      homeBase: _homeBaseCtrl.text.trim().isNotEmpty
          ? _homeBaseCtrl.text.trim()
          : null,
      typicalTripType: _tripType,
      groupDynamicNotes: _groupDynamicCtrl.text.trim().isNotEmpty
          ? _groupDynamicCtrl.text.trim()
          : null,
      pacingPreference: _pacing,
      privacyPreference: _privacy,
      luxuryLevel: _luxury,
      guidePreference: _guide,
      structurePreference: _structure,
      accommodationType: _accommodationType,
      beddingPreferences: _beddingCtrl.text.trim().isNotEmpty
          ? _beddingCtrl.text.trim()
          : null,
      wellnessImportance: _wellness,
      amenityPreferences: _amenities.toList(),
      cuisinePreferences: split(_cuisineCtrl.text),
      diningDislikes: split(_dislikesCtrl.text),
      dietaryRestrictions: _dietary.toList(),
      allergies: split(_allergiesCtrl.text),
      diningStyle: _diningStyle,
      alcoholPreference: _alcoholCtrl.text.trim().isNotEmpty
          ? _alcoholCtrl.text.trim()
          : null,
      culturalInterest: _cultural,
      adventureInterest: _adventure,
      intellectualInterest: _intellectual,
      relaxationInterest: _relaxation,
      shoppingInterest: _shopping,
      prefersLateStarts: _prefersLateStarts,
      dislikesCrowds: _dislikesCrowds,
      heatTolerance: _heat,
      walkingTolerance: _walking,
      accessibilityNotes: _accessibilityCtrl.text.trim().isNotEmpty
          ? _accessibilityCtrl.text.trim()
          : null,
      securitySensitivity: _securityCtrl.text.trim().isNotEmpty
          ? _securityCtrl.text.trim()
          : null,
      photographySensitivity: _photographyCtrl.text.trim().isNotEmpty
          ? _photographyCtrl.text.trim()
          : null,
      internalNotes: _internalNotesCtrl.text.trim().isNotEmpty
          ? _internalNotesCtrl.text.trim()
          : null,
      pastFeedbackNotes: _feedbackCtrl.text.trim().isNotEmpty
          ? _feedbackCtrl.text.trim()
          : null,
      serviceStyleNotes: _serviceStyleCtrl.text.trim().isNotEmpty
          ? _serviceStyleCtrl.text.trim()
          : null,
      operationalFlags: split(_flagsCtrl.text),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    if (_primaryNameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final dossier = _buildDossier();
      if (_isEdit) {
        await widget.provider.updateDossier(dossier);
        if (mounted) Navigator.of(context).pop();
      } else {
        final created = await widget.provider.addDossier(dossier);
        if (!mounted) return;
        if (created == null) {
          final msg = widget.provider.error ?? 'Could not save — check your team membership and try again.';
          widget.provider.clearError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return; // keep the form open
        }
        Navigator.of(context).pop(created);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Sections list ──────────────────────────────────────────────────────────

  static const _sectionTitles = [
    'Overview',
    'Travel Style',
    'Accommodation',
    'Dining',
    'Experiences',
    'Behavioral',
    'Internal',
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? AppSpacing.pagePaddingHMobile
                  : AppSpacing.pagePaddingH,
              vertical: AppSpacing.base,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit Dossier' : 'New Client Dossier',
                    style: AppTextStyles.heading2,
                  ),
                ),
                GestureDetector(
                  onTap: (_isSaving || !_perm.canEditDossier) ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: (_isSaving || !_perm.canEditDossier)
                          ? AppColors.textMuted
                          : AppColors.accent,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.buttonRadius,
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Section nav pills
          Container(
            color: AppColors.surface,
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? AppSpacing.pagePaddingHMobile
                    : AppSpacing.pagePaddingH,
              ),
              child: Row(
                children: List.generate(_sectionTitles.length, (i) {
                  final sel = _section == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _section = i);
                      final ctx = _sectionKeys[i].currentContext;
                      if (ctx != null) {
                        Scrollable.ensureVisible(
                          ctx,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: 0.05,
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.accentFaint : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.accent : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _sectionTitles[i],
                        style: AppTextStyles.labelSmall.copyWith(
                          color: sel
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? AppSpacing.pagePaddingHMobile
                    : AppSpacing.pagePaddingH,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormSection(
                      key: _sectionKeys[0],
                      title: 'Overview',
                      child: _OverviewFields(
                        primaryCtrl: _primaryNameCtrl,
                        familyCtrl: _familyNameCtrl,
                        emailCtrl: _emailCtrl,
                        phoneCtrl: _phoneCtrl,
                        nationalityCtrl: _nationalityCtrl,
                        homeBaseCtrl: _homeBaseCtrl,
                        groupCtrl: _groupDynamicCtrl,
                        tripType: _tripType,
                        onTripType: (v) => setState(() => _tripType = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _FormSection(
                      key: _sectionKeys[1],
                      title: 'Travel Style',
                      child: _TravelStyleFields(
                        pacing: _pacing,
                        onPacing: (v) => setState(() => _pacing = v),
                        privacy: _privacy,
                        onPrivacy: (v) => setState(() => _privacy = v),
                        luxury: _luxury,
                        onLuxury: (v) => setState(() => _luxury = v),
                        guide: _guide,
                        onGuide: (v) => setState(() => _guide = v),
                        structure: _structure,
                        onStructure: (v) => setState(() => _structure = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _FormSection(
                      key: _sectionKeys[2],
                      title: 'Accommodation',
                      child: _AccommodationFields(
                        type: _accommodationType,
                        onType: (v) => setState(() => _accommodationType = v),
                        wellness: _wellness,
                        onWellness: (v) => setState(() => _wellness = v),
                        beddingCtrl: _beddingCtrl,
                        amenities: _amenities,
                        onAmenities: (v) => setState(() => _amenities = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _FormSection(
                      key: _sectionKeys[3],
                      title: 'Dining',
                      child: _DiningFields(
                        style: _diningStyle,
                        onStyle: (v) => setState(() => _diningStyle = v),
                        cuisineCtrl: _cuisineCtrl,
                        dislikesCtrl: _dislikesCtrl,
                        alcoholCtrl: _alcoholCtrl,
                        dietary: _dietary,
                        onDietary: (v) => setState(() => _dietary = v),
                        allergiesCtrl: _allergiesCtrl,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _FormSection(
                      key: _sectionKeys[4],
                      title: 'Experiences',
                      child: _ExperiencesFields(
                        cultural: _cultural,
                        onCultural: (v) => setState(() => _cultural = v),
                        adventure: _adventure,
                        onAdventure: (v) => setState(() => _adventure = v),
                        intellectual: _intellectual,
                        onIntellectual: (v) =>
                            setState(() => _intellectual = v),
                        relaxation: _relaxation,
                        onRelaxation: (v) => setState(() => _relaxation = v),
                        shopping: _shopping,
                        onShopping: (v) => setState(() => _shopping = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _FormSection(
                      key: _sectionKeys[5],
                      title: 'Behavioral & Comfort',
                      child: _BehavioralFields(
                        prefersLate: _prefersLateStarts,
                        onPrefersLate: (v) =>
                            setState(() => _prefersLateStarts = v),
                        dislikesCrowds: _dislikesCrowds,
                        onDislikesCrowds: (v) =>
                            setState(() => _dislikesCrowds = v),
                        heat: _heat,
                        onHeat: (v) => setState(() => _heat = v),
                        walking: _walking,
                        onWalking: (v) => setState(() => _walking = v),
                        accessCtrl: _accessibilityCtrl,
                        securityCtrl: _securityCtrl,
                        photoCtrl: _photographyCtrl,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_perm.canViewSensitiveNotes)
                      _FormSection(
                        key: _sectionKeys[6],
                        title: 'Internal Notes',
                        isInternal: true,
                        child: _InternalFields(
                          notesCtrl: _internalNotesCtrl,
                          feedbackCtrl: _feedbackCtrl,
                          serviceCtrl: _serviceStyleCtrl,
                          flagsCtrl: _flagsCtrl,
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
  }
}

// ── Form section wrapper ──────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isInternal;
  const _FormSection({
    super.key,
    required this.title,
    required this.child,
    this.isInternal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isInternal) ...[
              Icon(
                Icons.lock_outline_rounded,
                size: 11,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              title.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: isInternal ? AppColors.accent : AppColors.textSecondary,
                letterSpacing: 1.1,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: isInternal ? const Color(0xFFFFFBF5) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: isInternal ? AppColors.accentLight : AppColors.border,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section field groups — each extracts into its own StatelessWidget
// ─────────────────────────────────────────────────────────────────────────────

// Shared field builder helpers
Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

Widget _enumRow<T>(
  String label,
  List<T> values,
  T? selected,
  String Function(T) labelOf,
  ValueChanged<T?> onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: values.map((v) {
          final sel = selected == v;
          return GestureDetector(
            onTap: () => onChanged(sel ? null : v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? AppColors.accentFaint : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                border: Border.all(
                  color: sel ? AppColors.accent : AppColors.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Text(
                labelOf(v),
                style: AppTextStyles.labelSmall.copyWith(
                  color: sel ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

Widget _multiChipRow(
  String label,
  List<String> options,
  Set<String> selected,
  ValueChanged<Set<String>> onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: options.map((opt) {
          final sel = selected.contains(opt);
          return GestureDetector(
            onTap: () {
              final next = Set<String>.from(selected);
              sel ? next.remove(opt) : next.add(opt);
              onChanged(next);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? AppColors.accentFaint : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                border: Border.all(
                  color: sel ? AppColors.accent : AppColors.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Text(
                opt,
                style: AppTextStyles.labelSmall.copyWith(
                  color: sel ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

const _gap = SizedBox(height: AppSpacing.base);

// ── Overview fields ───────────────────────────────────────────────────────────

class _OverviewFields extends StatelessWidget {
  final TextEditingController primaryCtrl,
      familyCtrl,
      emailCtrl,
      phoneCtrl,
      nationalityCtrl,
      homeBaseCtrl,
      groupCtrl;
  final TripType? tripType;
  final ValueChanged<TripType?> onTripType;

  const _OverviewFields({
    required this.primaryCtrl,
    required this.familyCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.nationalityCtrl,
    required this.homeBaseCtrl,
    required this.groupCtrl,
    required this.tripType,
    required this.onTripType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Primary client name *', primaryCtrl),
        _gap,
        _field('Family / group name', familyCtrl),
        _gap,
        Row(
          children: [
            Expanded(child: _field('Email', emailCtrl)),
            const SizedBox(width: AppSpacing.base),
            Expanded(child: _field('Phone', phoneCtrl)),
          ],
        ),
        _gap,
        Row(
          children: [
            Expanded(child: _field('Nationality', nationalityCtrl)),
            const SizedBox(width: AppSpacing.base),
            Expanded(child: _field('Home base', homeBaseCtrl)),
          ],
        ),
        _gap,
        _enumRow(
          'Trip type',
          TripType.values,
          tripType,
          (t) => t.label,
          onTripType,
        ),
        _gap,
        _field('Group dynamic notes', groupCtrl, maxLines: 3),
      ],
    );
  }
}

// ── Travel style fields ───────────────────────────────────────────────────────

class _TravelStyleFields extends StatelessWidget {
  final PacingPreference? pacing;
  final ValueChanged<PacingPreference?> onPacing;
  final PrivacyPreference? privacy;
  final ValueChanged<PrivacyPreference?> onPrivacy;
  final LuxuryLevel? luxury;
  final ValueChanged<LuxuryLevel?> onLuxury;
  final GuidePreference? guide;
  final ValueChanged<GuidePreference?> onGuide;
  final StructurePreference? structure;
  final ValueChanged<StructurePreference?> onStructure;

  const _TravelStyleFields({
    required this.pacing,
    required this.onPacing,
    required this.privacy,
    required this.onPrivacy,
    required this.luxury,
    required this.onLuxury,
    required this.guide,
    required this.onGuide,
    required this.structure,
    required this.onStructure,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _enumRow(
        'Pacing',
        PacingPreference.values,
        pacing,
        (v) => v.label,
        onPacing,
      ),
      _gap,
      _enumRow(
        'Privacy',
        PrivacyPreference.values,
        privacy,
        (v) => v.label,
        onPrivacy,
      ),
      _gap,
      _enumRow(
        'Luxury level',
        LuxuryLevel.values,
        luxury,
        (v) => v.label,
        onLuxury,
      ),
      _gap,
      _enumRow(
        'Guide preference',
        GuidePreference.values,
        guide,
        (v) => v.label,
        onGuide,
      ),
      _gap,
      _enumRow(
        'Structure',
        StructurePreference.values,
        structure,
        (v) => v.label,
        onStructure,
      ),
    ],
  );
}

// ── Accommodation fields ──────────────────────────────────────────────────────

class _AccommodationFields extends StatelessWidget {
  final AccommodationType? type;
  final ValueChanged<AccommodationType?> onType;
  final WellnessImportance? wellness;
  final ValueChanged<WellnessImportance?> onWellness;
  final TextEditingController beddingCtrl;
  final Set<String> amenities;
  final ValueChanged<Set<String>> onAmenities;

  const _AccommodationFields({
    required this.type,
    required this.onType,
    required this.wellness,
    required this.onWellness,
    required this.beddingCtrl,
    required this.amenities,
    required this.onAmenities,
  });

  static const _amenityOptions = [
    'Private pool',
    'Beach access',
    'Gym',
    'Spa',
    'Butler service',
    'Kids club',
    'Restaurant on site',
    'Quiet property',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _enumRow(
        'Property type',
        AccommodationType.values,
        type,
        (v) => v.label,
        onType,
      ),
      _gap,
      _enumRow(
        'Wellness / spa',
        WellnessImportance.values,
        wellness,
        (v) => v.label,
        onWellness,
      ),
      _gap,
      _field('Bedding preferences', beddingCtrl),
      _gap,
      _multiChipRow(
        'Amenity priorities',
        _amenityOptions,
        amenities,
        onAmenities,
      ),
    ],
  );
}

// ── Dining fields ─────────────────────────────────────────────────────────────

class _DiningFields extends StatelessWidget {
  final DiningStyle? style;
  final ValueChanged<DiningStyle?> onStyle;
  final TextEditingController cuisineCtrl,
      dislikesCtrl,
      alcoholCtrl,
      allergiesCtrl;
  final Set<String> dietary;
  final ValueChanged<Set<String>> onDietary;

  const _DiningFields({
    required this.style,
    required this.onStyle,
    required this.cuisineCtrl,
    required this.dislikesCtrl,
    required this.alcoholCtrl,
    required this.allergiesCtrl,
    required this.dietary,
    required this.onDietary,
  });

  static const _dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
    'Halal',
    'Kosher',
    'No pork',
    'No shellfish',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _enumRow(
        'Dining style',
        DiningStyle.values,
        style,
        (v) => v.label,
        onStyle,
      ),
      _gap,
      _field('Cuisine preferences (comma-separated)', cuisineCtrl),
      _gap,
      _field('Dining dislikes (comma-separated)', dislikesCtrl),
      _gap,
      _multiChipRow(
        'Dietary restrictions',
        _dietaryOptions,
        dietary,
        onDietary,
      ),
      _gap,
      _field('Allergies (comma-separated) — list clearly', allergiesCtrl),
      _gap,
      _field('Alcohol preference', alcoholCtrl),
    ],
  );
}

// ── Experiences fields ────────────────────────────────────────────────────────

class _ExperiencesFields extends StatelessWidget {
  final int cultural, adventure, intellectual, relaxation, shopping;
  final ValueChanged<int> onCultural,
      onAdventure,
      onIntellectual,
      onRelaxation,
      onShopping;

  const _ExperiencesFields({
    required this.cultural,
    required this.onCultural,
    required this.adventure,
    required this.onAdventure,
    required this.intellectual,
    required this.onIntellectual,
    required this.relaxation,
    required this.onRelaxation,
    required this.shopping,
    required this.onShopping,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _sliderRow('Cultural / heritage', cultural, onCultural),
      _sliderRow('Adventure / active', adventure, onAdventure),
      _sliderRow('Intellectual', intellectual, onIntellectual),
      _sliderRow('Relaxation', relaxation, onRelaxation),
      _sliderRow('Shopping', shopping, onShopping),
    ],
  );

  Widget _sliderRow(String label, int val, ValueChanged<int> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                value: val.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.surfaceAlt,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '$val',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
}

// ── Behavioral fields ─────────────────────────────────────────────────────────

class _BehavioralFields extends StatelessWidget {
  final bool prefersLate;
  final ValueChanged<bool> onPrefersLate;
  final bool dislikesCrowds;
  final ValueChanged<bool> onDislikesCrowds;
  final HeatTolerance? heat;
  final ValueChanged<HeatTolerance?> onHeat;
  final WalkingTolerance? walking;
  final ValueChanged<WalkingTolerance?> onWalking;
  final TextEditingController accessCtrl, securityCtrl, photoCtrl;

  const _BehavioralFields({
    required this.prefersLate,
    required this.onPrefersLate,
    required this.dislikesCrowds,
    required this.onDislikesCrowds,
    required this.heat,
    required this.onHeat,
    required this.walking,
    required this.onWalking,
    required this.accessCtrl,
    required this.securityCtrl,
    required this.photoCtrl,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _toggle(
        'Prefers late morning starts (10am+)',
        prefersLate,
        onPrefersLate,
      ),
      _toggle('Sensitive to crowds', dislikesCrowds, onDislikesCrowds),
      _gap,
      _enumRow(
        'Heat tolerance',
        HeatTolerance.values,
        heat,
        (v) => v.label,
        onHeat,
      ),
      _gap,
      _enumRow(
        'Walking tolerance',
        WalkingTolerance.values,
        walking,
        (v) => v.label,
        onWalking,
      ),
      _gap,
      _field('Accessibility / mobility notes', accessCtrl, maxLines: 2),
      _gap,
      _field('Photography / privacy sensitivity', photoCtrl),
      _gap,
      _field('Security sensitivity', securityCtrl),
    ],
  );

  Widget _toggle(String label, bool val, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      Switch(
        value: val,
        onChanged: onChanged,
        activeThumbColor: AppColors.accent,
      ),
    ],
  );
}

// ── Internal fields ───────────────────────────────────────────────────────────

class _InternalFields extends StatelessWidget {
  final TextEditingController notesCtrl, feedbackCtrl, serviceCtrl, flagsCtrl;
  const _InternalFields({
    required this.notesCtrl,
    required this.feedbackCtrl,
    required this.serviceCtrl,
    required this.flagsCtrl,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _field('Internal notes', notesCtrl, maxLines: 4),
      _gap,
      _field('Past feedback notes', feedbackCtrl, maxLines: 3),
      _gap,
      _field('Service style notes', serviceCtrl, maxLines: 3),
      _gap,
      _field('Operational flags (comma-separated)', flagsCtrl),
    ],
  );
}
