import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/signature_experience.dart';
import '../providers/signature_experience_provider.dart';
import 'signature_experience_form_screen.dart';

class SignatureExperienceDetailScreen extends StatefulWidget {
  final SignatureExperience experience;
  final SignatureExperienceProvider provider;

  const SignatureExperienceDetailScreen({
    super.key,
    required this.experience,
    required this.provider,
  });

  @override
  State<SignatureExperienceDetailScreen> createState() =>
      _SignatureExperienceDetailScreenState();
}

class _SignatureExperienceDetailScreenState
    extends State<SignatureExperienceDetailScreen> {
  late SignatureExperience _experience;

  @override
  void initState() {
    super.initState();
    _experience = widget.experience;
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureExperienceFormScreen(
          provider: widget.provider,
          existing: _experience,
        ),
      ),
    );
    // Refresh from provider in case the edit saved
    final updated = widget.provider.findById(_experience.id);
    if (updated != null && mounted) {
      setState(() => _experience = updated);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete experience?'),
        content: Text(
          'This will permanently delete "${_experience.title}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.provider.delete(_experience.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _experience;

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
        title: Text(e.title, style: AppTextStyles.heading1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Edit',
            onPressed: _openEdit,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical: AppSpacing.pagePaddingV,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero header ──────────────────────────────────────────────
                _HeroHeader(experience: e),
                const SizedBox(height: AppSpacing.xxl),

                // ── Client-facing description ────────────────────────────────
                if (e.shortDescriptionClient != null ||
                    e.longDescriptionInternal != null) ...[
                  _SectionHeader(
                      icon: Icons.person_outline_rounded,
                      label: 'Client Description'),
                  const SizedBox(height: AppSpacing.md),
                  if (e.shortDescriptionClient != null)
                    _DetailCard(child: Text(e.shortDescriptionClient!,
                        style: AppTextStyles.bodyLarge)),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Internal concept (tinted) ────────────────────────────────
                if (e.longDescriptionInternal != null ||
                    e.conceptSummary != null) ...[
                  _SectionHeader(
                      icon: Icons.lock_outline_rounded,
                      label: 'Internal Concept',
                      internal: true),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.conceptSummary != null) ...[
                          Text('Concept Summary',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.accent)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(e.conceptSummary!,
                              style: AppTextStyles.bodyMedium),
                          const SizedBox(height: AppSpacing.base),
                        ],
                        if (e.longDescriptionInternal != null) ...[
                          Text('Full Internal Description',
                              style: AppTextStyles.labelMedium
                                  .copyWith(color: AppColors.accent)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(e.longDescriptionInternal!,
                              style: AppTextStyles.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Logistics ────────────────────────────────────────────────
                _SectionHeader(
                    icon: Icons.tune_rounded, label: 'Logistics'),
                const SizedBox(height: AppSpacing.md),
                _DetailCard(
                  child: Wrap(
                    spacing: AppSpacing.xxl,
                    runSpacing: AppSpacing.base,
                    children: [
                      _LabelValue(
                          label: 'Type',
                          value: e.experienceType.label),
                      _LabelValue(
                          label: 'Destination',
                          value: e.destinationFlexibility.label),
                      _LabelValue(
                          label: 'Group Size',
                          value: e.groupSizeLabel),
                      if (e.durationLabel != null)
                        _LabelValue(
                            label: 'Duration', value: e.durationLabel!),
                      if (e.indoorOutdoorType != null)
                        _LabelValue(
                            label: 'Setting',
                            value: e.indoorOutdoorType!),
                    ],
                  ),
                ),
                if (e.locationNotes != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NoteBlock(
                      icon: Icons.location_on_outlined,
                      label: 'Location Notes',
                      text: e.locationNotes!),
                ],
                if (e.audienceSuitability.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Audience Suitability',
                      style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: e.audienceSuitability
                        .map((a) => _Chip(a))
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),

                // ── Operational (internal) ───────────────────────────────────
                if (e.productionNotes != null ||
                    e.setupRequirements != null ||
                    e.executionComplexity != null ||
                    e.requiredStaffRoles.isNotEmpty ||
                    e.requiredSuppliers.isNotEmpty) ...[
                  _SectionHeader(
                      icon: Icons.settings_outlined,
                      label: 'Operational',
                      internal: true),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.executionComplexity != null)
                          _LabelValue(
                              label: 'Execution Complexity',
                              value: e.executionComplexity!),
                        if (e.productionNotes != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.build_outlined,
                              label: 'Production Notes',
                              text: e.productionNotes!),
                        ],
                        if (e.setupRequirements != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.checklist_outlined,
                              label: 'Setup Requirements',
                              text: e.setupRequirements!),
                        ],
                        if (e.requiredStaffRoles.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('Required Staff Roles',
                              style: AppTextStyles.labelMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: e.requiredStaffRoles
                                .map((r) => _Chip(r))
                                .toList(),
                          ),
                        ],
                        if (e.requiredSuppliers.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text('Required Suppliers',
                              style: AppTextStyles.labelMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: e.requiredSuppliers
                                .map((r) => _Chip(r))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Sensitivity (internal) ───────────────────────────────────
                if (e.culturalSensitivityNotes != null ||
                    e.politicalSensitivityNotes != null ||
                    e.securityNotes != null) ...[
                  _SectionHeader(
                      icon: Icons.warning_amber_outlined,
                      label: 'Sensitivity Notes',
                      internal: true),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9ED),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border:
                          Border.all(color: const Color(0xFFF5E6B8)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.culturalSensitivityNotes != null)
                          _NoteBlock(
                              icon: Icons.people_outline_rounded,
                              label: 'Cultural',
                              text: e.culturalSensitivityNotes!),
                        if (e.politicalSensitivityNotes != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.gavel_outlined,
                              label: 'Political',
                              text: e.politicalSensitivityNotes!),
                        ],
                        if (e.securityNotes != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.shield_outlined,
                              label: 'Security',
                              text: e.securityNotes!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Commercial (internal) ────────────────────────────────────
                if (e.costingNotes != null || e.pricingNotes != null) ...[
                  _SectionHeader(
                      icon: Icons.attach_money_rounded,
                      label: 'Commercial',
                      internal: true),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.costingNotes != null)
                          _NoteBlock(
                              icon: Icons.receipt_outlined,
                              label: 'Costing',
                              text: e.costingNotes!),
                        if (e.pricingNotes != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.sell_outlined,
                              label: 'Pricing',
                              text: e.pricingNotes!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // ── Media & Briefing ─────────────────────────────────────────
                if (e.mediaLinks.isNotEmpty || e.briefingNotes != null) ...[
                  _SectionHeader(
                      icon: Icons.perm_media_outlined,
                      label: 'Media & Briefing'),
                  const SizedBox(height: AppSpacing.md),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.mediaLinks.isNotEmpty) ...[
                          Text('Media Links',
                              style: AppTextStyles.labelMedium),
                          const SizedBox(height: AppSpacing.sm),
                          ...e.mediaLinks.map(
                            (url) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded,
                                      size: 14,
                                      color: AppColors.accent),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(url,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color: AppColors.accent),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (e.briefingNotes != null) ...[
                          if (e.mediaLinks.isNotEmpty)
                            const SizedBox(height: AppSpacing.md),
                          _NoteBlock(
                              icon: Icons.description_outlined,
                              label: 'Briefing Notes',
                              text: e.briefingNotes!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // Tags
                if (e.tags.isNotEmpty) ...[
                  Text('Tags', style: AppTextStyles.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: e.tags
                        .map((t) => _Chip(t, accent: true))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.massive),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final SignatureExperience experience;
  const _HeroHeader({required this.experience});

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final cat = e.category;
    final status = e.status;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cat.color.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cat.icon, size: 28, color: cat.color),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(cat.label, style: AppTextStyles.labelMedium.copyWith(color: cat.color)),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 11, color: status.color),
                        const SizedBox(width: 4),
                        Text(status.label,
                            style: AppTextStyles.labelSmall.copyWith(color: status.color)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(e.title, style: AppTextStyles.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.base,
                children: [
                  _HeroMeta(icon: Icons.category_outlined, label: e.experienceType.label),
                  _HeroMeta(icon: e.destinationFlexibility.icon, label: e.destinationFlexibility.label),
                  _HeroMeta(icon: Icons.people_outline_rounded, label: e.groupSizeLabel),
                  if (e.durationLabel != null)
                    _HeroMeta(icon: Icons.schedule_outlined, label: e.durationLabel!),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool internal;
  const _SectionHeader(
      {required this.icon, required this.label, this.internal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: internal ? AppColors.accent : AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: AppTextStyles.overline),
        if (internal) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('INTERNAL',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.accent, fontSize: 9)),
          ),
        ],
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: child,
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  const _NoteBlock(
      {required this.icon, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(text, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _LabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool accent;
  const _Chip(this.label, {this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
            color: accent ? AppColors.accentLight : AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: accent ? AppColors.accentDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}
