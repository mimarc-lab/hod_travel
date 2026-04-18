import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/supplier_model.dart';
import '../../../../core/supabase/app_db.dart';
import '../../supplier_enrichment/providers/enrichment_provider.dart';
import '../../supplier_enrichment/screens/merge_enrichment_sheet.dart';
import '../../supplier_enrichment/widgets/enrichment_history_section.dart';
import '../providers/supplier_provider.dart';
import '../widgets/supplier_badges.dart';
import '../widgets/supplier_editor.dart';
import '../widgets/supplier_linked_records.dart';

/// Full-page supplier profile screen.
/// Pushed via Navigator from the supplier list.
class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;
  final SupplierProvider provider;
  final EnrichmentProvider? enrichmentProvider;

  const SupplierDetailScreen({
    super.key,
    required this.supplier,
    required this.provider,
    this.enrichmentProvider,
  });

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  // Keep a local copy that updates on provider changes via ListenableBuilder.
  // The detail screen shows whichever version the provider holds.

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        // Always fetch by id — safe even when filters are active.
        final supplier =
            widget.provider.findById(widget.supplier.id) ?? widget.supplier;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _DetailHeader(
            supplier: supplier,
            provider: widget.provider,
            enrichmentProvider: widget.enrichmentProvider,
          ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.isMobile(context)
                        ? AppSpacing.pagePaddingHMobile
                        : AppSpacing.pagePaddingH,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BasicInfoCard(supplier: supplier),
                        const SizedBox(height: AppSpacing.xl),

                        if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                          _NotesCard(notes: supplier.notes!),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        if (supplier.tags.isNotEmpty) ...[
                          _TagsSection(tags: supplier.tags),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        _AttachmentsPlaceholder(),
                        const SizedBox(height: AppSpacing.xl),

                        SupplierLinkedRecords(supplierName: supplier.name),
                        const SizedBox(height: AppSpacing.xl),

                        EnrichmentHistorySection(
                          supplierId: supplier.id,
                          repository: AppRepositories.instance?.enrichments,
                        ),
                        const SizedBox(height: AppSpacing.massive),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Detail header ─────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final Supplier supplier;
  final SupplierProvider provider;
  final EnrichmentProvider? enrichmentProvider;
  const _DetailHeader({
    required this.supplier,
    required this.provider,
    this.enrichmentProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Suppliers', style: AppTextStyles.bodySmall),
                Text(' / ', style: AppTextStyles.bodySmall),
                Text(supplier.name,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category icon
              CategoryIconBadge(category: supplier.category, size: 44),
              const SizedBox(width: AppSpacing.base),

              // Name + badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: AppTextStyles.displayMedium),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        CategoryBadge(category: supplier.category),
                        if (supplier.preferred) const PreferredBadge(),
                        RatingDots(rating: supplier.internalRating, size: 13),
                      ],
                    ),
                  ],
                ),
              ),

              // Enrich button (only shown when EnrichmentProvider is available)
              if (enrichmentProvider != null) ...[
                _EnrichButton(
                  onTap: () => showMergeEnrichmentSheet(
                    context,
                    supplier: supplier,
                    supplierProvider: provider,
                    enrichmentProvider: enrichmentProvider!,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],

              // Edit button
              _EditButton(
                onTap: () => showSupplierEditor(
                  context,
                  provider: provider,
                  existing: supplier,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Delete button
              _DeleteButton(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      title: Text('Delete supplier?',
                          style: AppTextStyles.heading3),
                      content: Text(
                        'This will permanently remove "${supplier.name}" '
                        'from your database. This action cannot be undone.',
                        style: AppTextStyles.bodySmall,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel',
                              style: AppTextStyles.labelMedium),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Delete',
                              style: AppTextStyles.labelMedium.copyWith(
                                  color: const Color(0xFFB00020))),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    provider.deleteSupplier(supplier.id);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnrichButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EnrichButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentFaint,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accentLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high_rounded, size: 14, color: AppColors.accent),
            const SizedBox(width: 5),
            Text('Enrich',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text('Edit', style: AppTextStyles.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded,
                size: 14, color: Color(0xFFB00020)),
            const SizedBox(width: 5),
            Text('Delete',
                style: AppTextStyles.labelMedium
                    .copyWith(color: const Color(0xFFB00020))),
          ],
        ),
      ),
    );
  }
}

// ── Basic info card ───────────────────────────────────────────────────────────

class _BasicInfoCard extends StatelessWidget {
  final Supplier supplier;
  const _BasicInfoCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      children: [
        _InfoRow(icon: Icons.location_city_outlined, label: 'City', value: supplier.city),
        _InfoRow(icon: Icons.public_outlined, label: 'Country', value: supplier.country),
        if (supplier.location != null)
          _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: supplier.location!),
        if (supplier.website != null)
          _InfoRow(icon: Icons.link_rounded, label: 'Website', value: supplier.website!),
        if (supplier.contactName != null)
          _InfoRow(icon: Icons.person_outline_rounded, label: 'Contact', value: supplier.contactName!),
        if (supplier.contactEmail != null)
          _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: supplier.contactEmail!),
        if (supplier.contactPhone != null)
          _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: supplier.contactPhone!),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Notes card ────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INTERNAL NOTES', style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          children: [
            Text(notes,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, height: 1.6)),
          ],
        ),
      ],
    );
  }
}

// ── Tags section ──────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  const _TagsSection({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TAGS', style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: tags.map((tag) => _TagChip(tag: tag)).toList(),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(tag,
          style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary)),
    );
  }
}

// ── Attachments placeholder ───────────────────────────────────────────────────

class _AttachmentsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTACHMENTS', style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          children: [
            _AttachmentRow(icon: Icons.picture_as_pdf_outlined,
                name: 'Contract_2025.pdf', size: '340 KB'),
            const Divider(height: 1, color: AppColors.divider),
            _AttachmentRow(icon: Icons.image_outlined,
                name: 'Property_photos.zip', size: '8.2 MB'),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.upload_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Upload file',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted)),
                Text(' — placeholder only',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String size;
  const _AttachmentRow({required this.icon, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(name,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary)),
          ),
          Text(size,
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Shared section card ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
