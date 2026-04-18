import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/signature_experience.dart';
import '../providers/signature_experience_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SignatureExperienceFormScreen
// ─────────────────────────────────────────────────────────────────────────────

class SignatureExperienceFormScreen extends StatefulWidget {
  final SignatureExperienceProvider provider;

  /// When set, the form is in edit mode.
  final SignatureExperience? existing;

  const SignatureExperienceFormScreen({
    super.key,
    required this.provider,
    this.existing,
  });

  @override
  State<SignatureExperienceFormScreen> createState() =>
      _SignatureExperienceFormScreenState();
}

class _SignatureExperienceFormScreenState
    extends State<SignatureExperienceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEdit => widget.existing != null;

  // Controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _longDescCtrl;
  late final TextEditingController _conceptCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _locationNotesCtrl;
  late final TextEditingController _indoorOutdoorCtrl;
  late final TextEditingController _productionCtrl;
  late final TextEditingController _setupCtrl;
  late final TextEditingController _complexityCtrl;
  late final TextEditingController _costingCtrl;
  late final TextEditingController _pricingCtrl;
  late final TextEditingController _culturalCtrl;
  late final TextEditingController _politicalCtrl;
  late final TextEditingController _securityCtrl;
  late final TextEditingController _briefingCtrl;

  // State fields
  late ExperienceStatus _status;
  late ExperienceCategory _category;
  late ExperienceType _experienceType;
  late ExperienceFlexibility _flexibility;
  late int? _groupSizeMin;
  late int? _groupSizeMax;
  late List<String> _tags;
  late List<String> _audienceSuitability;
  late List<String> _requiredStaffRoles;
  late List<String> _requiredSuppliers;
  late List<String> _mediaLinks;

  // For chip-input fields
  final _tagCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _staffRoleCtrl = TextEditingController();
  final _requiredSupplierCtrl = TextEditingController();
  final _mediaLinkCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl       = TextEditingController(text: e?.title ?? '');
    _shortDescCtrl   = TextEditingController(text: e?.shortDescriptionClient ?? '');
    _longDescCtrl    = TextEditingController(text: e?.longDescriptionInternal ?? '');
    _conceptCtrl     = TextEditingController(text: e?.conceptSummary ?? '');
    _durationCtrl    = TextEditingController(text: e?.durationLabel ?? '');
    _locationNotesCtrl = TextEditingController(text: e?.locationNotes ?? '');
    _indoorOutdoorCtrl = TextEditingController(text: e?.indoorOutdoorType ?? '');
    _productionCtrl  = TextEditingController(text: e?.productionNotes ?? '');
    _setupCtrl       = TextEditingController(text: e?.setupRequirements ?? '');
    _complexityCtrl  = TextEditingController(text: e?.executionComplexity ?? '');
    _costingCtrl     = TextEditingController(text: e?.costingNotes ?? '');
    _pricingCtrl     = TextEditingController(text: e?.pricingNotes ?? '');
    _culturalCtrl    = TextEditingController(text: e?.culturalSensitivityNotes ?? '');
    _politicalCtrl   = TextEditingController(text: e?.politicalSensitivityNotes ?? '');
    _securityCtrl    = TextEditingController(text: e?.securityNotes ?? '');
    _briefingCtrl    = TextEditingController(text: e?.briefingNotes ?? '');

    _status          = e?.status         ?? ExperienceStatus.draft;
    _category        = e?.category        ?? ExperienceCategory.cultural;
    _experienceType  = e?.experienceType  ?? ExperienceType.private;
    _flexibility     = e?.destinationFlexibility ?? ExperienceFlexibility.adaptable;
    _groupSizeMin    = e?.idealGroupSizeMin;
    _groupSizeMax    = e?.idealGroupSizeMax;
    _tags                 = List.from(e?.tags ?? []);
    _audienceSuitability  = List.from(e?.audienceSuitability ?? []);
    _requiredStaffRoles   = List.from(e?.requiredStaffRoles ?? []);
    _requiredSuppliers    = List.from(e?.requiredSuppliers ?? []);
    _mediaLinks           = List.from(e?.mediaLinks ?? []);
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _shortDescCtrl, _longDescCtrl, _conceptCtrl,
      _durationCtrl, _locationNotesCtrl, _indoorOutdoorCtrl,
      _productionCtrl, _setupCtrl, _complexityCtrl,
      _costingCtrl, _pricingCtrl,
      _culturalCtrl, _politicalCtrl, _securityCtrl,
      _briefingCtrl,
      _tagCtrl, _audienceCtrl, _staffRoleCtrl,
      _requiredSupplierCtrl, _mediaLinkCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _notEmpty(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  void _addChip(TextEditingController ctrl, List<String> list) {
    final val = ctrl.text.trim();
    if (val.isEmpty) return;
    final lower = val.toLowerCase();
    if (list.any((e) => e.toLowerCase() == lower)) {
      ctrl.clear();
      return;
    }
    setState(() => list.add(val));
    ctrl.clear();
  }

  void _removeChip(List<String> list, String item) {
    setState(() => list.remove(item));
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final teamId = AppRepositories.instance?.currentTeamId ?? '';
    final experience = SignatureExperience(
      id: widget.existing?.id ?? '',
      teamId: teamId.isNotEmpty ? teamId : null,
      title:                     _titleCtrl.text.trim(),
      status:                    _status,
      category:                  _category,
      experienceType:            _experienceType,
      shortDescriptionClient:    _shortDescCtrl.text.trim().isEmpty ? null : _shortDescCtrl.text.trim(),
      longDescriptionInternal:   _longDescCtrl.text.trim().isEmpty ? null : _longDescCtrl.text.trim(),
      conceptSummary:            _conceptCtrl.text.trim().isEmpty ? null : _conceptCtrl.text.trim(),
      audienceSuitability:       _audienceSuitability,
      destinationFlexibility:    _flexibility,
      tags:                      _tags,
      durationLabel:             _durationCtrl.text.trim().isEmpty ? null : _durationCtrl.text.trim(),
      idealGroupSizeMin:         _groupSizeMin,
      idealGroupSizeMax:         _groupSizeMax,
      indoorOutdoorType:         _indoorOutdoorCtrl.text.trim().isEmpty ? null : _indoorOutdoorCtrl.text.trim(),
      locationNotes:             _locationNotesCtrl.text.trim().isEmpty ? null : _locationNotesCtrl.text.trim(),
      productionNotes:           _productionCtrl.text.trim().isEmpty ? null : _productionCtrl.text.trim(),
      setupRequirements:         _setupCtrl.text.trim().isEmpty ? null : _setupCtrl.text.trim(),
      executionComplexity:       _complexityCtrl.text.trim().isEmpty ? null : _complexityCtrl.text.trim(),
      requiredStaffRoles:        _requiredStaffRoles,
      requiredSuppliers:         _requiredSuppliers,
      costingNotes:              _costingCtrl.text.trim().isEmpty ? null : _costingCtrl.text.trim(),
      pricingNotes:              _pricingCtrl.text.trim().isEmpty ? null : _pricingCtrl.text.trim(),
      culturalSensitivityNotes:  _culturalCtrl.text.trim().isEmpty ? null : _culturalCtrl.text.trim(),
      politicalSensitivityNotes: _politicalCtrl.text.trim().isEmpty ? null : _politicalCtrl.text.trim(),
      securityNotes:             _securityCtrl.text.trim().isEmpty ? null : _securityCtrl.text.trim(),
      mediaLinks:                _mediaLinks,
      briefingNotes:             _briefingCtrl.text.trim().isEmpty ? null : _briefingCtrl.text.trim(),
      createdBy:                 widget.existing?.createdBy ?? AppRepositories.instance?.currentUserId,
      createdAt:                 widget.existing?.createdAt,
    );

    final result = _isEdit
        ? await widget.provider.update(experience)
        : await widget.provider.add(experience);

    setState(() => _submitting = false);
    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Experience updated.' : 'Experience created.'),
          backgroundColor: AppColors.statusDoneText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final maxWidth = isMobile ? double.infinity : 720.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Edit Experience' : 'New Experience',
          style: AppTextStyles.heading1,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSpacing.base : AppSpacing.xl,
              vertical: AppSpacing.pagePaddingV,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Core identity ────────────────────────────────────────
                  _FormSectionLabel(label: 'Core Identity'),
                  const SizedBox(height: AppSpacing.md),

                  _FieldLabel('Title *'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _titleCtrl,
                    hint: 'e.g. Yin & Yang: Opposing Political Narratives Debate',
                    validator: (v) => _notEmpty(v, 'Title'),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Status'),
                            const SizedBox(height: AppSpacing.xs),
                            _StatusDropdown(
                              value: _status,
                              onChanged: (v) => setState(() => _status = v!),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            _FieldLabel('Category'),
                            const SizedBox(height: AppSpacing.xs),
                            _CategoryDropdown(
                              value: _category,
                              onChanged: (v) => setState(() => _category = v!),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Status'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _StatusDropdown(
                                    value: _status,
                                    onChanged: (v) =>
                                        setState(() => _status = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Category'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _CategoryDropdown(
                                    value: _category,
                                    onChanged: (v) =>
                                        setState(() => _category = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Experience Type'),
                            const SizedBox(height: AppSpacing.xs),
                            _ExperienceTypeDropdown(
                              value: _experienceType,
                              onChanged: (v) =>
                                  setState(() => _experienceType = v!),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            _FieldLabel('Destination Flexibility'),
                            const SizedBox(height: AppSpacing.xs),
                            _FlexibilityDropdown(
                              value: _flexibility,
                              onChanged: (v) =>
                                  setState(() => _flexibility = v!),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Experience Type'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _ExperienceTypeDropdown(
                                    value: _experienceType,
                                    onChanged: (v) =>
                                        setState(() => _experienceType = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Destination Flexibility'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _FlexibilityDropdown(
                                    value: _flexibility,
                                    onChanged: (v) =>
                                        setState(() => _flexibility = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Description ──────────────────────────────────────────
                  _FormSectionLabel(label: 'Description'),
                  const SizedBox(height: AppSpacing.md),

                  _FieldLabel('Short Description (Client-Facing)'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _shortDescCtrl,
                    hint: 'A compelling one-paragraph summary for the client proposal…',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  _FieldLabel('Concept Summary (Internal)'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _conceptCtrl,
                    hint: 'Brief internal rationale and design concept…',
                    maxLines: 3,
                    internal: true,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  _FieldLabel('Full Internal Description'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _longDescCtrl,
                    hint: 'Comprehensive internal breakdown of the experience…',
                    maxLines: 6,
                    internal: true,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Logistics ────────────────────────────────────────────
                  _FormSectionLabel(label: 'Logistics'),
                  const SizedBox(height: AppSpacing.md),

                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Duration'),
                            const SizedBox(height: AppSpacing.xs),
                            _FormField(
                                controller: _durationCtrl,
                                hint: 'e.g. 3 hours, Full day'),
                            const SizedBox(height: AppSpacing.base),
                            _FieldLabel('Indoor / Outdoor'),
                            const SizedBox(height: AppSpacing.xs),
                            _FormField(
                                controller: _indoorOutdoorCtrl,
                                hint: 'e.g. Indoor, Outdoor, Both'),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Duration'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _FormField(
                                      controller: _durationCtrl,
                                      hint: 'e.g. 3 hours, Full day'),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.base),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Indoor / Outdoor'),
                                  const SizedBox(height: AppSpacing.xs),
                                  _FormField(
                                      controller: _indoorOutdoorCtrl,
                                      hint: 'e.g. Indoor, Outdoor, Both'),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: AppSpacing.base),

                  // Group size
                  _FieldLabel('Ideal Group Size'),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _GroupSizeField(
                          hint: 'Min',
                          value: _groupSizeMin,
                          onChanged: (v) => setState(() => _groupSizeMin = v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('–', style: AppTextStyles.bodyMedium),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _GroupSizeField(
                          hint: 'Max',
                          value: _groupSizeMax,
                          onChanged: (v) => setState(() => _groupSizeMax = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  _FieldLabel('Location Notes'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _locationNotesCtrl,
                    hint: 'Specific venue requirements, destination constraints…',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Audience suitability chips
                  _FieldLabel('Audience Suitability'),
                  const SizedBox(height: AppSpacing.xs),
                  _ChipInput(
                    controller: _audienceCtrl,
                    items: _audienceSuitability,
                    hint: 'e.g. Couples, Families, Corporate…',
                    onAdd: () => _addChip(_audienceCtrl, _audienceSuitability),
                    onRemove: (v) => _removeChip(_audienceSuitability, v),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Operational ──────────────────────────────────────────
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: _FormSectionLabel(
                        label: 'Operational (Internal)', bottom: 0),
                    initiallyExpanded: _isEdit &&
                        (_productionCtrl.text.isNotEmpty ||
                            _setupCtrl.text.isNotEmpty ||
                            _complexityCtrl.text.isNotEmpty ||
                            _requiredStaffRoles.isNotEmpty ||
                            _requiredSuppliers.isNotEmpty),
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      _FieldLabel('Execution Complexity'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _complexityCtrl,
                        hint: 'e.g. Low, Medium, High, Requires advance logistics…',
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Production Notes'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _productionCtrl,
                        hint: 'Behind-the-scenes production details…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Setup Requirements'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _setupCtrl,
                        hint: 'What needs to be arranged in advance…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Required Staff Roles'),
                      const SizedBox(height: AppSpacing.xs),
                      _ChipInput(
                        controller: _staffRoleCtrl,
                        items: _requiredStaffRoles,
                        hint: 'e.g. Lead Guide, Security, Translator…',
                        onAdd: () =>
                            _addChip(_staffRoleCtrl, _requiredStaffRoles),
                        onRemove: (v) =>
                            _removeChip(_requiredStaffRoles, v),
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Required Suppliers'),
                      const SizedBox(height: AppSpacing.xs),
                      _ChipInput(
                        controller: _requiredSupplierCtrl,
                        items: _requiredSuppliers,
                        hint: 'e.g. Private venue, Security firm…',
                        onAdd: () =>
                            _addChip(_requiredSupplierCtrl, _requiredSuppliers),
                        onRemove: (v) =>
                            _removeChip(_requiredSuppliers, v),
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Sensitivity ──────────────────────────────────────────
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: _FormSectionLabel(
                        label: 'Sensitivity Notes (Internal)', bottom: 0),
                    initiallyExpanded: _isEdit &&
                        (_culturalCtrl.text.isNotEmpty ||
                            _politicalCtrl.text.isNotEmpty ||
                            _securityCtrl.text.isNotEmpty),
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      _FieldLabel('Cultural Sensitivity'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _culturalCtrl,
                        hint: 'Cultural considerations to brief the team on…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Political Sensitivity'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _politicalCtrl,
                        hint: 'Political context or cautions…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Security Notes'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _securityCtrl,
                        hint: 'Security requirements or risk considerations…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // ── Commercial ───────────────────────────────────────────
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: _FormSectionLabel(
                        label: 'Commercial (Internal)', bottom: 0),
                    initiallyExpanded: _isEdit &&
                        (_costingCtrl.text.isNotEmpty ||
                            _pricingCtrl.text.isNotEmpty),
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      _FieldLabel('Costing Notes'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _costingCtrl,
                        hint: 'Typical cost ranges, cost drivers…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _FieldLabel('Pricing Notes'),
                      const SizedBox(height: AppSpacing.xs),
                      _FormField(
                        controller: _pricingCtrl,
                        hint: 'Suggested pricing structure, margins…',
                        maxLines: 3,
                        internal: true,
                      ),
                      const SizedBox(height: AppSpacing.base),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Media & Briefing ─────────────────────────────────────
                  _FormSectionLabel(label: 'Media & Briefing'),
                  const SizedBox(height: AppSpacing.md),

                  _FieldLabel('Media Links'),
                  const SizedBox(height: AppSpacing.xs),
                  _ChipInput(
                    controller: _mediaLinkCtrl,
                    items: _mediaLinks,
                    hint: 'Paste a URL and press Add…',
                    onAdd: () => _addChip(_mediaLinkCtrl, _mediaLinks),
                    onRemove: (v) => _removeChip(_mediaLinks, v),
                    chipIcon: Icons.link_rounded,
                  ),
                  const SizedBox(height: AppSpacing.base),

                  _FieldLabel('Briefing Notes'),
                  const SizedBox(height: AppSpacing.xs),
                  _FormField(
                    controller: _briefingCtrl,
                    hint: 'Pre-experience briefing content for the team…',
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Tags ─────────────────────────────────────────────────
                  _FormSectionLabel(label: 'Tags'),
                  const SizedBox(height: AppSpacing.md),
                  _ChipInput(
                    controller: _tagCtrl,
                    items: _tags,
                    hint: 'Add a tag and press Enter…',
                    onAdd: () => _addChip(_tagCtrl, _tags),
                    onRemove: (v) => _removeChip(_tags, v),
                    accent: true,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Actions ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.buttonRadius),
                            ),
                          ),
                          child: Text('Cancel',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.buttonRadius),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(
                                  _isEdit
                                      ? 'Save Changes'
                                      : 'Create Experience',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.massive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form sub-widgets ──────────────────────────────────────────────────────────

class _FormSectionLabel extends StatelessWidget {
  final String label;
  final double bottom;
  const _FormSectionLabel({required this.label, this.bottom = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.overline
              .copyWith(color: AppColors.textSecondary, fontSize: 11)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.labelMedium);
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final bool internal;

  const _FormField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
    this.internal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor:
            internal ? AppColors.surfaceAlt : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(
              color: internal
                  ? AppColors.accentLight
                  : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:
              const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}

class _GroupSizeField extends StatelessWidget {
  final String hint;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _GroupSizeField(
      {required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: TextInputType.number,
      style: AppTextStyles.bodyMedium,
      onChanged: (v) => onChanged(int.tryParse(v.trim())),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
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

class _ChipInput extends StatelessWidget {
  final TextEditingController controller;
  final List<String> items;
  final String hint;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final bool internal;
  final bool accent;
  final IconData? chipIcon;

  const _ChipInput({
    required this.controller,
    required this.items,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
    this.internal = false,
    this.accent = false,
    this.chipIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  style: AppTextStyles.bodyMedium,
                  onSubmitted: (_) => onAdd(),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.bodySmall,
                    filled: true,
                    fillColor: internal
                        ? AppColors.surfaceAlt
                        : AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: BorderSide(
                          color: internal
                              ? AppColors.accentLight
                              : AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                child: const Center(
                  child: Text('Add',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent
                      ? AppColors.accentFaint
                      : (internal
                          ? AppColors.surfaceAlt
                          : AppColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                  border: Border.all(
                    color: accent
                        ? AppColors.accentLight
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chipIcon != null) ...[
                      Icon(chipIcon, size: 11,
                          color: accent
                              ? AppColors.accentDark
                              : AppColors.textMuted),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      item,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: accent
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(item),
                      child: Icon(Icons.close, size: 12,
                          color: accent
                              ? AppColors.accentDark
                              : AppColors.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Dropdown widgets ──────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  final ExperienceStatus value;
  final ValueChanged<ExperienceStatus?> onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<ExperienceStatus>(
      value: value,
      items: ExperienceStatus.values,
      labelOf: (s) => s.label,
      onChanged: onChanged,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final ExperienceCategory value;
  final ValueChanged<ExperienceCategory?> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<ExperienceCategory>(
      value: value,
      items: ExperienceCategory.values,
      labelOf: (c) => c.label,
      onChanged: onChanged,
    );
  }
}

class _ExperienceTypeDropdown extends StatelessWidget {
  final ExperienceType value;
  final ValueChanged<ExperienceType?> onChanged;
  const _ExperienceTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<ExperienceType>(
      value: value,
      items: ExperienceType.values,
      labelOf: (t) => t.label,
      onChanged: onChanged,
    );
  }
}

class _FlexibilityDropdown extends StatelessWidget {
  final ExperienceFlexibility value;
  final ValueChanged<ExperienceFlexibility?> onChanged;
  const _FlexibilityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _AppDropdown<ExperienceFlexibility>(
      value: value,
      items: ExperienceFlexibility.values,
      labelOf: (f) => f.label,
      onChanged: onChanged,
    );
  }
}

class _AppDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  const _AppDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
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
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item)),
              ))
          .toList(),
    );
  }
}
