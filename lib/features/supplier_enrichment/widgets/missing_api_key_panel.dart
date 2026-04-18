import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// Shown when FirecrawlConfig.isConfigured is false.
/// Guides the user on how to provide their API key.
class MissingApiKeyPanel extends StatelessWidget {
  const MissingApiKeyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentFaint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.key_outlined,
                    color: AppColors.accent, size: 26),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Firecrawl Not Configured',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'To use supplier enrichment, provide your Firecrawl API key at build time.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _CodeBlock(
                  code:
                      'flutter run \\\n  --dart-define=FIRECRAWL_API_KEY=fc-your-key-here'),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Get your API key at firecrawl.dev → API Keys',
                style: AppTextStyles.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SelectableText(
        code,
        style: AppTextStyles.labelSmall.copyWith(
          fontFamily: 'monospace',
          color: AppColors.textPrimary,
          height: 1.7,
        ),
      ),
    );
  }
}
