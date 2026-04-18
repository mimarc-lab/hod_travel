import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'task_info_section.dart';

/// Placeholder attachment area — ready for real file handling in a future phase.
class TaskAttachmentsSection extends StatelessWidget {
  const TaskAttachmentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSectionHeader(label: 'ATTACHMENTS'),
        _MockAttachment(icon: Icons.picture_as_pdf_outlined, name: 'Proposal_v2.pdf', size: '1.2 MB'),
        _MockAttachment(icon: Icons.image_outlined,          name: 'Villa_photos.zip', size: '8.4 MB'),
        const SizedBox(height: AppSpacing.sm),
        // Upload placeholder button
        GestureDetector(
          onTap: () {}, // Real upload handled in future phase
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attach_file_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Upload file', style: AppTextStyles.labelMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MockAttachment extends StatelessWidget {
  final IconData icon;
  final String name;
  final String size;
  const _MockAttachment({required this.icon, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                Text(size, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Icon(Icons.download_outlined, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
