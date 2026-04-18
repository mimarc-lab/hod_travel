import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/signature_experience.dart';

/// Editorial card for a single Signature Experience.
/// Used in the list grid view.
class SignatureExperienceCard extends StatelessWidget {
  final SignatureExperience experience;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SignatureExperienceCard({
    super.key,
    required this.experience,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = experience.category;
    final status = experience.status;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category colour bar + icon ───────────────────────────────────
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: cat.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.cardRadius)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: category icon + status badge + menu
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cat.color.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(cat.icon, size: 16, color: cat.color),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(cat.label, style: AppTextStyles.labelMedium),
                      const Spacer(),
                      _StatusBadge(status: status),
                      if (onEdit != null || onDelete != null) ...[
                        const SizedBox(width: 6),
                        _CardMenu(onEdit: onEdit, onDelete: onDelete),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Text(
                    experience.title,
                    style: AppTextStyles.heading3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Short description (client-facing)
                  if (experience.shortDescriptionClient != null &&
                      experience.shortDescriptionClient!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      experience.shortDescriptionClient!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Meta row
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: 4,
                    children: [
                      _MetaChip(
                        icon: experience.experienceType == ExperienceType.private
                            ? Icons.person_outline_rounded
                            : Icons.group_outlined,
                        label: experience.experienceType.label,
                      ),
                      _MetaChip(
                        icon: experience.destinationFlexibility.icon,
                        label: experience.destinationFlexibility.label,
                      ),
                      if (experience.durationLabel != null)
                        _MetaChip(
                          icon: Icons.schedule_outlined,
                          label: experience.durationLabel!,
                        ),
                      if (experience.idealGroupSizeMin != null ||
                          experience.idealGroupSizeMax != null)
                        _MetaChip(
                          icon: Icons.people_outline_rounded,
                          label: experience.groupSizeLabel,
                        ),
                    ],
                  ),

                  // Tags
                  if (experience.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: experience.tags.take(4).map((tag) => _Tag(tag)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ExperienceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            status.label,
            style: AppTextStyles.labelSmall.copyWith(color: status.color),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentFaint,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accentLight),
      ),
      child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentDark)),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _CardMenu({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit' && onEdit != null) onEdit!();
        if (v == 'delete' && onDelete != null) onDelete!();
      },
      tooltip: 'Options',
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (onEdit != null && onDelete != null) const PopupMenuDivider(),
        if (onDelete != null)
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
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border, width: 0.75),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
