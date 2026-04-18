import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/signature_experience.dart';
import '../providers/signature_experience_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a picker modal and returns the selected [SignatureExperience],
/// or null if the user cancelled.
Future<SignatureExperience?> showSignatureExperiencePicker(
    BuildContext context) {
  return showDialog<SignatureExperience>(
    context: context,
    builder: (_) => const _SignatureExperiencePickerDialog(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SignatureExperiencePickerDialog extends StatefulWidget {
  const _SignatureExperiencePickerDialog();

  @override
  State<_SignatureExperiencePickerDialog> createState() =>
      _SignatureExperiencePickerDialogState();
}

class _SignatureExperiencePickerDialogState
    extends State<_SignatureExperiencePickerDialog> {
  late final SignatureExperienceProvider _provider;
  String _search = '';
  ExperienceCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _provider = SignatureExperienceProvider(
      repository: AppRepositories.instance?.signatureExperiences,
      teamId: AppRepositories.instance?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  List<SignatureExperience> get _filtered {
    return _provider.experiences.where((e) {
      // Only show approved and flagship by default
      if (e.status != ExperienceStatus.approved &&
          e.status != ExperienceStatus.flagship) { return false; }
      final q = _search.toLowerCase();
      final matchSearch = _search.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          (e.shortDescriptionClient?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchCategory =
          _filterCategory == null || e.category == _filterCategory;
      return matchSearch && matchCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _PickerHeader(
              onClose: () => Navigator.of(context).pop(),
            ),

            // Search + category filter
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search experiences…',
                        hintStyle: AppTextStyles.bodySmall,
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 16, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: AppSpacing.sm),
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
                          borderSide: const BorderSide(
                              color: AppColors.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryPill(
                          label: 'All',
                          selected: _filterCategory == null,
                          onTap: () =>
                              setState(() => _filterCategory = null),
                        ),
                        const SizedBox(width: 4),
                        ...ExperienceCategory.values.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _CategoryPill(
                                label: c.label,
                                selected: _filterCategory == c,
                                color: c.color,
                                onTap: () => setState(() =>
                                    _filterCategory =
                                        _filterCategory == c ? null : c),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // List
            Flexible(
              child: ListenableBuilder(
                listenable: _provider,
                builder: (context, _) {
                  if (_provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    );
                  }

                  final filtered = _filtered;

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_outlined,
                                size: 36, color: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _provider.experiences.isEmpty
                                  ? 'No approved experiences in the library yet.'
                                  : 'No experiences match your search.',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (ctx, i) {
                      final e = filtered[i];
                      return _ExperiencePickerRow(
                        experience: e,
                        onTap: () => Navigator.of(context).pop(e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PickerHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _PickerHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Text('Pick from Experience Library',
              style: AppTextStyles.heading3),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperiencePickerRow extends StatelessWidget {
  final SignatureExperience experience;
  final VoidCallback onTap;
  const _ExperiencePickerRow(
      {required this.experience, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final cat = e.category;
    final status = e.status;

    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.accentFaint,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cat.color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cat.icon, size: 18, color: cat.color),
            ),
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.title,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status.backgroundColor,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.chipRadius),
                        ),
                        child: Text(status.label,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: status.color)),
                      ),
                    ],
                  ),
                  if (e.shortDescriptionClient != null &&
                      e.shortDescriptionClient!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      e.shortDescriptionClient!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.md,
                    children: [
                      Text(cat.label,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: cat.color)),
                      if (e.durationLabel != null)
                        Text(e.durationLabel!,
                            style: AppTextStyles.labelSmall),
                      Text(e.groupSizeLabel,
                          style: AppTextStyles.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withAlpha(26)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
              color: selected ? activeColor : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? activeColor : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
