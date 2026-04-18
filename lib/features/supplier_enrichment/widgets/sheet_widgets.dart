import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI primitives for the enrichment sheet family.
//
// Used by: url_enrichment_sheet, merge_enrichment_sheet, supplier_search_sheet.
// Keeps the three sheets visually consistent and avoids copy-pasted code.
// ─────────────────────────────────────────────────────────────────────────────

// ── Footer (cancel + primary action) ─────────────────────────────────────────

class EnrichmentSheetFooter extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;

  const EnrichmentSheetFooter({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ── URL text field ────────────────────────────────────────────────────────────

class EnrichmentUrlField extends StatelessWidget {
  final TextEditingController ctrl;

  const EnrichmentUrlField({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.url,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'https://www.example.com/property',
        hintStyle: AppTextStyles.bodySmall,
        prefixIcon:
            const Icon(Icons.link_rounded, size: 16, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ── Loading indicator ─────────────────────────────────────────────────────────

class EnrichmentLoadingIndicator extends StatelessWidget {
  final String message;

  const EnrichmentLoadingIndicator({
    super.key,
    this.message = 'Extracting supplier data…',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const CircularProgressIndicator(
              color: AppColors.accent, strokeWidth: 2),
          const SizedBox(height: AppSpacing.base),
          Text(message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Error banner with retry ───────────────────────────────────────────────────

class EnrichmentErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const EnrichmentErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFF991B1B)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFF991B1B))),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onRetry,
            child: Text('Retry',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
