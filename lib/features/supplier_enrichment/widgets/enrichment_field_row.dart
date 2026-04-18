import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentFieldRow — shows a single extracted field
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentFieldRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool missing;

  const EnrichmentFieldRow({
    super.key,
    required this.label,
    this.value,
    this.missing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: isEmpty
                ? Text('—',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted,
                            fontStyle: FontStyle.italic))
                : Text(value!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MergeFieldRow — side-by-side current vs extracted for merge screen
// ─────────────────────────────────────────────────────────────────────────────

class MergeFieldRow extends StatelessWidget {
  final String label;
  final String? currentValue;
  final String? extractedValue;
  final bool applyExtracted;
  final ValueChanged<bool> onToggle;

  const MergeFieldRow({
    super.key,
    required this.label,
    this.currentValue,
    this.extractedValue,
    required this.applyExtracted,
    required this.onToggle,
  });

  bool get hasExtracted =>
      extractedValue != null && extractedValue!.isNotEmpty;
  bool get hasCurrent =>
      currentValue != null && currentValue!.isNotEmpty;
  bool get isDifferent => currentValue != extractedValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field label
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Current value
          Expanded(
            child: _ValueCell(
              value: currentValue,
              dimmed: applyExtracted && isDifferent,
              strikethrough: applyExtracted && isDifferent && hasCurrent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Extracted value + toggle
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ValueCell(
                    value: extractedValue,
                    highlight: hasExtracted && isDifferent,
                  ),
                ),
                if (hasExtracted && isDifferent) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _ApplyToggle(
                    active: applyExtracted,
                    onToggle: onToggle,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final String? value;
  final bool dimmed;
  final bool strikethrough;
  final bool highlight;

  const _ValueCell({
    this.value,
    this.dimmed = false,
    this.strikethrough = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? AppColors.accentFaint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? AppColors.accentLight : AppColors.borderSubtle,
        ),
      ),
      child: isEmpty
          ? Text('—',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted,
                      fontStyle: FontStyle.italic))
          : Text(
              value!,
              style: AppTextStyles.labelSmall.copyWith(
                color: dimmed ? AppColors.textMuted : AppColors.textPrimary,
                decoration:
                    strikethrough ? TextDecoration.lineThrough : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

class _ApplyToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onToggle;
  const _ApplyToggle({required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!active),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Icon(
          active ? Icons.check_rounded : Icons.add_rounded,
          size: 14,
          color: active ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MergeColumnHeader — labels for the merge table
// ─────────────────────────────────────────────────────────────────────────────

class MergeColumnHeader extends StatelessWidget {
  const MergeColumnHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      color: AppColors.surfaceAlt,
      child: Row(
        children: [
          const SizedBox(width: 100 + AppSpacing.sm),
          Expanded(
            child: Text('CURRENT',
                style: AppTextStyles.overline),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('EXTRACTED',
                style: AppTextStyles.overline
                    .copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
