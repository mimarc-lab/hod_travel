import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/enrichment_repository.dart';
import '../supplier_intelligence_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierActivityTimeline
//
// Chronological list of enrichment events for a single supplier.
// Shows source type, action taken, and formatted date.
// Renders an empty state when no enrichments exist.
// ─────────────────────────────────────────────────────────────────────────────

class SupplierActivityTimeline extends StatelessWidget {
  final String supplierId;
  final SupplierIntelligenceProvider intelligenceProvider;

  const SupplierActivityTimeline({
    super.key,
    required this.supplierId,
    required this.intelligenceProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: intelligenceProvider,
      builder: (context, _) {
        if (!intelligenceProvider.isLoaded) {
          return const _LoadingState();
        }

        final enrichments = intelligenceProvider.enrichmentsFor(supplierId);

        if (enrichments.isEmpty) {
          return const _EmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < enrichments.length; i++)
              _TimelineEntry(
                record:   enrichments[i],
                isLast:   i == enrichments.length - 1,
              ),
          ],
        );
      },
    );
  }
}

// ── _TimelineEntry ────────────────────────────────────────────────────────────

class _TimelineEntry extends StatelessWidget {
  final SupplierEnrichmentRecord record;
  final bool isLast;

  const _TimelineEntry({required this.record, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final icon      = _iconFor(record.sourceType);
    final title     = _titleFor(record);
    final subtitle  = _subtitleFor(record);
    final dateLabel = DateFormat('d MMM yyyy · HH:mm').format(record.createdAt.toLocal());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left spine ─────────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width:  28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceAlt,
                    shape:        BoxShape.circle,
                    border:       Border.all(color: AppColors.border, width: 0.75),
                  ),
                  child: Icon(icon, size: 13, color: AppColors.textSecondary),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.divider,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(EnrichmentSourceType type) {
    switch (type) {
      case EnrichmentSourceType.firecrawlUrl:    return Icons.link_rounded;
      case EnrichmentSourceType.firecrawlSearch: return Icons.search_rounded;
      case EnrichmentSourceType.manualImport:    return Icons.upload_file_outlined;
    }
  }

  String _titleFor(SupplierEnrichmentRecord r) {
    final action = r.actionTaken?.label ?? 'Data imported';
    return action;
  }

  String? _subtitleFor(SupplierEnrichmentRecord r) {
    if (r.sourceDomain != null && r.sourceDomain!.isNotEmpty) {
      return 'via ${r.sourceDomain}';
    }
    if (r.sourceUrl != null && r.sourceUrl!.isNotEmpty) {
      return r.sourceUrl;
    }
    return r.sourceType.label;
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Icon(Icons.history_edu_outlined, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            'No enrichment activity yet.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading activity…',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
