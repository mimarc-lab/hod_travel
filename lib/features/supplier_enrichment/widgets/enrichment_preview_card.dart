import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/supplier_enrichment_model.dart';
import '../../../data/models/supplier_model.dart';
import 'enrichment_field_row.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExtractionStatusBanner — completeness indicator at top of preview
// ─────────────────────────────────────────────────────────────────────────────

class ExtractionStatusBanner extends StatelessWidget {
  final SupplierEnrichment enrichment;

  const ExtractionStatusBanner({super.key, required this.enrichment});

  @override
  Widget build(BuildContext context) {
    final pct = (enrichment.completeness * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: enrichment.completenessColor.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: enrichment.completenessColor.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: enrichment.completenessColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${enrichment.completenessLabel} extraction — '
              '${enrichment.filledFieldCount} fields extracted ($pct% completeness)',
              style: AppTextStyles.labelMedium
                  .copyWith(color: enrichment.completenessColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Completeness bar
          SizedBox(
            width: 60,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: enrichment.completeness,
                backgroundColor: enrichment.completenessColor.withAlpha(30),
                valueColor: AlwaysStoppedAnimation(enrichment.completenessColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentPreviewCard — grouped fields display
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentPreviewCard extends StatelessWidget {
  final SupplierEnrichment enrichment;

  const EnrichmentPreviewCard({super.key, required this.enrichment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source info
        _SourceRow(enrichment: enrichment),
        const SizedBox(height: AppSpacing.base),

        // Status banner
        ExtractionStatusBanner(enrichment: enrichment),
        const SizedBox(height: AppSpacing.lg),

        // Core fields
        _FieldGroup(
          title: 'PROPERTY INFO',
          children: [
            EnrichmentFieldRow(label: 'Name',     value: enrichment.name),
            EnrichmentFieldRow(label: 'Category', value: enrichment.category?.label),
            EnrichmentFieldRow(label: 'City',     value: enrichment.city),
            EnrichmentFieldRow(label: 'Country',  value: enrichment.country),
            EnrichmentFieldRow(label: 'Location', value: enrichment.location),
            EnrichmentFieldRow(label: 'Website',  value: enrichment.website),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Contact
        _FieldGroup(
          title: 'CONTACT',
          children: [
            EnrichmentFieldRow(label: 'Name',  value: enrichment.contactName),
            EnrichmentFieldRow(label: 'Email', value: enrichment.contactEmail),
            EnrichmentFieldRow(label: 'Phone', value: enrichment.contactPhone),
          ],
        ),
        const SizedBox(height: AppSpacing.base),

        // Notes & detail
        if (enrichment.summary != null) ...[
          _FieldGroup(
            title: 'SUMMARY',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  enrichment.summary!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary, height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // Highlights
        if (enrichment.highlights.isNotEmpty) ...[
          _TagGroup(title: 'HIGHLIGHTS', items: enrichment.highlights),
          const SizedBox(height: AppSpacing.base),
        ],

        // ── Accommodation-specific sections ───────────────────────────────

        // Rooms & Capacity
        if (_hasRoomData(enrichment)) ...[
          _RoomsSection(enrichment: enrichment),
          const SizedBox(height: AppSpacing.base),
        ],

        // Dining & Wellness
        if (_hasDiningOrWellness(enrichment)) ...[
          _DiningWellnessSection(enrichment: enrichment),
          const SizedBox(height: AppSpacing.base),
        ],

        // Family Suitability
        if (enrichment.familyFriendly != null ||
            enrichment.childrenPolicy != null) ...[
          _FamilySection(enrichment: enrichment),
          const SizedBox(height: AppSpacing.base),
        ],

        // Policies & Operations
        if (_hasOperationsData(enrichment)) ...[
          _PoliciesSection(enrichment: enrichment),
          const SizedBox(height: AppSpacing.base),
        ],

        // Tags
        if (enrichment.tags.isNotEmpty) ...[
          _TagGroup(title: 'TAGS', items: enrichment.tags),
        ],
      ],
    );
  }

  bool _hasRoomData(SupplierEnrichment e) =>
      e.numberOfRooms != null ||
      e.numberOfSuites != null ||
      e.numberOfVillas != null ||
      e.maxOccupancy != null ||
      e.roomTypes.isNotEmpty ||
      e.bedroomConfigurations.isNotEmpty;

  bool _hasDiningOrWellness(SupplierEnrichment e) =>
      e.diningOutlets.isNotEmpty ||
      e.spa != null ||
      e.pool != null ||
      e.beachAccess != null ||
      e.skiAccess != null ||
      e.wellnessFeatures.isNotEmpty ||
      e.activitiesOnSite.isNotEmpty;

  bool _hasOperationsData(SupplierEnrichment e) =>
      e.checkInTime != null ||
      e.checkOutTime != null ||
      e.cancellationPolicy != null ||
      e.pricingText != null ||
      e.airportTransferAvailable != null;
}

class _SourceRow extends StatelessWidget {
  final SupplierEnrichment enrichment;
  const _SourceRow({required this.enrichment});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.link_rounded,
            size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            enrichment.sourceUrl,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FieldGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _TagGroup extends StatelessWidget {
  final String title;
  final List<String> items;
  const _TagGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: items
              .map((item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(item,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EnrichmentHistoryTile — single row in history list
// ─────────────────────────────────────────────────────────────────────────────

class EnrichmentHistoryTile extends StatelessWidget {
  final EnrichmentEvent event;

  const EnrichmentHistoryTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.type.icon,
                size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.type.label +
                      (event.supplierName != null
                          ? ' — ${event.supplierName}'
                          : ''),
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  event.sourceDomain,
                  style: AppTextStyles.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(event.createdAt),
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accommodation-specific section widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RoomsSection extends StatelessWidget {
  final SupplierEnrichment enrichment;
  const _RoomsSection({required this.enrichment});

  @override
  Widget build(BuildContext context) {
    final e = enrichment;
    return _FieldGroup(
      title: 'ROOMS & CAPACITY',
      children: [
        if (e.numberOfRooms != null)
          EnrichmentFieldRow(
              label: 'Rooms', value: '${e.numberOfRooms}'),
        if (e.numberOfSuites != null)
          EnrichmentFieldRow(
              label: 'Suites', value: '${e.numberOfSuites}'),
        if (e.numberOfVillas != null)
          EnrichmentFieldRow(
              label: 'Villas', value: '${e.numberOfVillas}'),
        if (e.maxOccupancy != null)
          EnrichmentFieldRow(
              label: 'Max occupancy', value: e.maxOccupancy),
        if (e.roomTypes.isNotEmpty)
          EnrichmentFieldRow(
              label: 'Room types', value: e.roomTypes.join(', ')),
        if (e.bedroomConfigurations.isNotEmpty)
          EnrichmentFieldRow(
              label: 'Configurations',
              value: e.bedroomConfigurations.join(', ')),
      ],
    );
  }
}

class _DiningWellnessSection extends StatelessWidget {
  final SupplierEnrichment enrichment;
  const _DiningWellnessSection({required this.enrichment});

  String _flag(bool? v) => v == null ? '—' : (v ? 'Yes' : 'No');

  @override
  Widget build(BuildContext context) {
    final e = enrichment;
    return _FieldGroup(
      title: 'DINING & WELLNESS',
      children: [
        if (e.diningOutlets.isNotEmpty)
          EnrichmentFieldRow(
              label: 'Dining', value: e.diningOutlets.join(', ')),
        if (e.spa != null)
          EnrichmentFieldRow(label: 'Spa', value: _flag(e.spa)),
        if (e.pool != null)
          EnrichmentFieldRow(label: 'Pool', value: _flag(e.pool)),
        if (e.beachAccess != null)
          EnrichmentFieldRow(
              label: 'Beach access', value: _flag(e.beachAccess)),
        if (e.skiAccess != null)
          EnrichmentFieldRow(
              label: 'Ski access', value: _flag(e.skiAccess)),
        if (e.wellnessFeatures.isNotEmpty)
          EnrichmentFieldRow(
              label: 'Wellness', value: e.wellnessFeatures.join(', ')),
        if (e.activitiesOnSite.isNotEmpty)
          EnrichmentFieldRow(
              label: 'Activities', value: e.activitiesOnSite.join(', ')),
      ],
    );
  }
}

class _FamilySection extends StatelessWidget {
  final SupplierEnrichment enrichment;
  const _FamilySection({required this.enrichment});

  @override
  Widget build(BuildContext context) {
    final e = enrichment;
    return _FieldGroup(
      title: 'FAMILY SUITABILITY',
      children: [
        if (e.familyFriendly != null)
          EnrichmentFieldRow(
              label: 'Family friendly',
              value: e.familyFriendly! ? 'Yes' : 'No'),
        if (e.childrenPolicy != null)
          EnrichmentFieldRow(
              label: 'Children policy', value: e.childrenPolicy),
      ],
    );
  }
}

class _PoliciesSection extends StatelessWidget {
  final SupplierEnrichment enrichment;
  const _PoliciesSection({required this.enrichment});

  @override
  Widget build(BuildContext context) {
    final e = enrichment;
    return _FieldGroup(
      title: 'POLICIES & OPERATIONS',
      children: [
        if (e.checkInTime != null)
          EnrichmentFieldRow(label: 'Check-in', value: e.checkInTime),
        if (e.checkOutTime != null)
          EnrichmentFieldRow(label: 'Check-out', value: e.checkOutTime),
        if (e.airportTransferAvailable != null)
          EnrichmentFieldRow(
              label: 'Transfers',
              value: e.airportTransferAvailable! ? 'Available' : 'Not offered'),
        if (e.cancellationPolicy != null)
          EnrichmentFieldRow(
              label: 'Cancellation', value: e.cancellationPolicy),
        if (e.pricingText != null)
          _PricingRow(text: e.pricingText!, currency: e.currency),
      ],
    );
  }
}

/// Pricing row with a disclaimer that rates are indicative only.
class _PricingRow extends StatelessWidget {
  final String text;
  final String? currency;
  const _PricingRow({required this.text, this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('Indicative rate',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency != null ? '$text ($currency)' : text,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Extracted from web — not a live or guaranteed rate.',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
