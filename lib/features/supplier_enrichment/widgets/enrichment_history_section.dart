import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/enrichment_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentHistorySection — shows DB-backed enrichment events for a supplier.
//
// Fetches once on mount. Collapses by default; expands on tap.
// The raw JSON payload is hidden behind a developer-level expansion tile
// to keep the main UI clean.
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentHistorySection extends StatefulWidget {
  final String supplierId;
  final EnrichmentRepository? repository;

  const EnrichmentHistorySection({
    super.key,
    required this.supplierId,
    required this.repository,
  });

  @override
  State<EnrichmentHistorySection> createState() =>
      _EnrichmentHistorySectionState();
}

class _EnrichmentHistorySectionState extends State<EnrichmentHistorySection> {
  late final Future<List<SupplierEnrichmentRecord>> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository;
    _future = repo != null
        ? repo.fetchForSupplier(widget.supplierId)
        : Future.value([]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupplierEnrichmentRecord>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final records = snapshot.data!;
        if (records.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text('ENRICHMENT HISTORY', style: AppTextStyles.overline),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentFaint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${records.length}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.accent, fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),

            if (_expanded) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: records
                      .map((r) => _HistoryRecordTile(record: r))
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HistoryRecordTile
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryRecordTile extends StatelessWidget {
  final SupplierEnrichmentRecord record;
  const _HistoryRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final action = record.actionTaken;
    final domain = record.sourceDomain ?? record.sourceUrl ?? '—';

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: 0),
      dense: true,
      leading: _ActionIcon(action: action),
      title: Text(
        action?.label ?? record.sourceType.label,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        domain,
        style: AppTextStyles.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(record.createdAt),
        style: AppTextStyles.labelSmall,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
      children: [
        // Source URL
        if (record.sourceUrl != null)
          _DevRow(
            label: 'Source',
            value: record.sourceUrl!,
          ),
        // Source type
        _DevRow(label: 'Type', value: record.sourceType.label),
        // Raw payload peek — hidden behind an expansion to keep UI clean
        if (record.extractedPayload != null &&
            record.extractedPayload!.isNotEmpty)
          _PayloadPeek(payload: record.extractedPayload!),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActionIcon extends StatelessWidget {
  final EnrichmentActionTaken? action;
  const _ActionIcon({this.action});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (action) {
      EnrichmentActionTaken.created   => (AppColors.accent,          Icons.add_business_outlined),
      EnrichmentActionTaken.merged    => (const Color(0xFF7C6FAB),   Icons.auto_fix_high_rounded),
      EnrichmentActionTaken.discarded => (AppColors.textMuted,       Icons.delete_outline_rounded),
      EnrichmentActionTaken.draftOnly => (AppColors.textSecondary,   Icons.drafts_outlined),
      null                            => (AppColors.textMuted,       Icons.history_rounded),
    };
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _DevRow extends StatelessWidget {
  final String label;
  final String value;
  const _DevRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _PayloadPeek extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _PayloadPeek({required this.payload});

  @override
  Widget build(BuildContext context) {
    // Show a count of extracted fields and a collapsed dev-only peek
    final nonNull = payload.entries
        .where((e) {
          final v = e.value;
          if (v == null) return false;
          if (v is String) return v.isNotEmpty;
          if (v is List) return v.isNotEmpty;
          return true;
        })
        .length;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.data_object_rounded,
              size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            '$nonNull extracted fields in payload',
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}
