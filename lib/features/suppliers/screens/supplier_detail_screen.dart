import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/supplier_media_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierDetailScreen
//
// Premium supplier intelligence workspace.
// Desktop: hero header + 2-col body (overview left, operational right)
//          + full-width media, linked records, enrichment history.
// Mobile:  stacked single-column cards.
// ─────────────────────────────────────────────────────────────────────────────

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
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final supplier =
            widget.provider.findById(widget.supplier.id) ?? widget.supplier;
        final width      = MediaQuery.sizeOf(context).width;
        final isDesktop  = width >= Responsive.tabletBreak;
        final isMobile   = width < Responsive.mobileBreak;
        final hPad       = isMobile
            ? AppSpacing.pagePaddingHMobile
            : AppSpacing.pagePaddingH;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _SupplierHeader(
                supplier:           supplier,
                provider:           widget.provider,
                enrichmentProvider: widget.enrichmentProvider,
                isMobile:           isMobile,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical:   AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Intelligence body ─────────────────────────────────
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _SupplierOverviewCard(
                                  supplier: supplier),
                            ),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(
                              flex: 2,
                              child: _OperationalPanel(supplier: supplier),
                            ),
                          ],
                        )
                      else ...[
                        _SupplierOverviewCard(supplier: supplier),
                        const SizedBox(height: AppSpacing.base),
                        _OperationalPanel(supplier: supplier),
                      ],

                      const SizedBox(height: AppSpacing.xxl),

                      // ── Media Library ─────────────────────────────────────
                      if (AppRepositories.instance?.supplierMedia != null &&
                          supplier.id.isNotEmpty) ...[
                        SupplierMediaSection(
                          supplierId: supplier.id,
                          teamId:
                              AppRepositories.instance?.currentTeamId ?? '',
                          repository:
                              AppRepositories.instance!.supplierMedia,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],

                      // ── Linked Records ────────────────────────────────────
                      SupplierLinkedRecords(supplierName: supplier.name),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Enrichment History ────────────────────────────────
                      EnrichmentHistorySection(
                        supplierId: supplier.id,
                        repository: AppRepositories.instance?.enrichments,
                      ),
                      const SizedBox(height: AppSpacing.massive),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// _SupplierHeader — compact context bar (no hero block)
//
// Desktop: two compact rows — breadcrumb+name | actions on row 1,
//          chips+meta+quick-contacts on row 2. ~72px total.
// Mobile:  compact stack — back+actions | name | chips | location | contacts.
//          ~130px max.
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierHeader extends StatelessWidget {
  final Supplier            supplier;
  final SupplierProvider    provider;
  final EnrichmentProvider? enrichmentProvider;
  final bool                isMobile;

  const _SupplierHeader({
    required this.supplier,
    required this.provider,
    required this.isMobile,
    this.enrichmentProvider,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = isMobile
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;
    return Container(
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: hPad, vertical: AppSpacing.sm + 2),
      child: isMobile
          ? _MobileBar(
              supplier:           supplier,
              provider:           provider,
              enrichmentProvider: enrichmentProvider,
            )
          : _DesktopBar(
              supplier:           supplier,
              provider:           provider,
              enrichmentProvider: enrichmentProvider,
            ),
    );
  }
}

// ── Desktop compact bar ───────────────────────────────────────────────────────

class _DesktopBar extends StatelessWidget {
  final Supplier            supplier;
  final SupplierProvider    provider;
  final EnrichmentProvider? enrichmentProvider;

  const _DesktopBar({
    required this.supplier,
    required this.provider,
    this.enrichmentProvider,
  });

  @override
  Widget build(BuildContext context) {
    final type        = supplier.effectiveSupplierType;
    final locationStr = [
      if (supplier.city.isNotEmpty)    supplier.city,
      if (supplier.country.isNotEmpty) supplier.country,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        // Row 1: back + name  ·  actions
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Suppliers',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('/',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(
                supplier.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color:      AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize:   15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _ActionRow(
              supplier:           supplier,
              provider:           provider,
              enrichmentProvider: enrichmentProvider,
            ),
          ],
        ),

        const SizedBox(height: 7),

        // Row 2: chips + location + rating + quick contacts
        Wrap(
          spacing:             6,
          runSpacing:          4,
          crossAxisAlignment:  WrapCrossAlignment.center,
          children: [
            CategoryBadge(type: type, compact: true),
            if (supplier.supplierSubtype != null)
              SubtypeBadge(
                  subtype: supplier.supplierSubtype!, compact: true),
            if (supplier.preferred) const PreferredBadge(),
            if (locationStr.isNotEmpty)
              _MetaItem(
                  icon: Icons.place_outlined, label: locationStr),
            if (supplier.internalRating > 0)
              RatingDots(rating: supplier.internalRating, size: 11),
            if (supplier.contactPhone != null)
              _QuickChip(
                icon:  Icons.phone_outlined,
                label: supplier.contactPhone!,
                onTap: () => _copyAndToast(
                    context, supplier.contactPhone!, 'Phone copied'),
              ),
            if (supplier.website != null)
              _QuickChip(
                icon:  Icons.language_rounded,
                label: supplier.website!,
                onTap: () => _copyAndToast(
                    context, supplier.website!, 'Website copied'),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Mobile compact bar ────────────────────────────────────────────────────────

class _MobileBar extends StatelessWidget {
  final Supplier            supplier;
  final SupplierProvider    provider;
  final EnrichmentProvider? enrichmentProvider;

  const _MobileBar({
    required this.supplier,
    required this.provider,
    this.enrichmentProvider,
  });

  @override
  Widget build(BuildContext context) {
    final type        = supplier.effectiveSupplierType;
    final locationStr = [
      if (supplier.city.isNotEmpty)    supplier.city,
      if (supplier.country.isNotEmpty) supplier.country,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        // Back  ·  actions
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Suppliers',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Spacer(),
            _ActionRow(
              supplier:           supplier,
              provider:           provider,
              enrichmentProvider: enrichmentProvider,
            ),
          ],
        ),

        const SizedBox(height: 7),

        // Supplier name
        Text(
          supplier.name,
          style: AppTextStyles.heading3
              .copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 5),

        // Category chips + preferred
        Wrap(
          spacing:    6,
          runSpacing: 4,
          children: [
            CategoryBadge(type: type, compact: true),
            if (supplier.supplierSubtype != null)
              SubtypeBadge(
                  subtype: supplier.supplierSubtype!, compact: true),
            if (supplier.preferred) const PreferredBadge(),
          ],
        ),

        // Location + rating
        if (locationStr.isNotEmpty || supplier.internalRating > 0) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              if (locationStr.isNotEmpty)
                _MetaItem(
                    icon: Icons.place_outlined, label: locationStr),
              if (locationStr.isNotEmpty && supplier.internalRating > 0)
                const SizedBox(width: 10),
              if (supplier.internalRating > 0)
                RatingDots(rating: supplier.internalRating, size: 11),
            ],
          ),
        ],

        // Quick contacts
        if (supplier.contactPhone != null || supplier.website != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing:    6,
            runSpacing: 4,
            children: [
              if (supplier.contactPhone != null)
                _QuickChip(
                  icon:  Icons.phone_outlined,
                  label: supplier.contactPhone!,
                  onTap: () => _copyAndToast(
                      context, supplier.contactPhone!, 'Phone copied'),
                ),
              if (supplier.website != null)
                _QuickChip(
                  icon:  Icons.language_rounded,
                  label: supplier.website!,
                  onTap: () => _copyAndToast(
                      context, supplier.website!, 'Website copied'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Shared action row ─────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final Supplier            supplier;
  final SupplierProvider    provider;
  final EnrichmentProvider? enrichmentProvider;

  const _ActionRow({
    required this.supplier,
    required this.provider,
    this.enrichmentProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enrichmentProvider != null) ...[
          _HeaderButton(
            icon:   Icons.auto_fix_high_rounded,
            label:  'Enrich',
            accent: true,
            onTap:  () => showMergeEnrichmentSheet(
              context,
              supplier:           supplier,
              supplierProvider:   provider,
              enrichmentProvider: enrichmentProvider!,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        _HeaderButton(
          icon:  Icons.edit_outlined,
          label: 'Edit',
          onTap: () => showSupplierEditor(
              context, provider: provider, existing: supplier),
        ),
        const SizedBox(width: AppSpacing.xs),
        _HeaderButton(
          icon:        Icons.delete_outline_rounded,
          label:       'Delete',
          destructive: true,
          onTap:       () => _confirmDelete(context, supplier, provider),
        ),
      ],
    );
  }
}

// ── Meta text item (location, etc.) ──────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Copyable contact chip ─────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header action button ──────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         accent;
  final bool         destructive;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent      = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = destructive
        ? const Color(0xFFFFF0F0)
        : accent
            ? AppColors.accentFaint
            : AppColors.surfaceAlt;
    final border = destructive
        ? const Color(0xFFFFCDD2)
        : accent
            ? AppColors.accentLight
            : AppColors.border;
    final fg     = destructive
        ? const Color(0xFFB00020)
        : accent
            ? AppColors.accent
            : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

// ── Clipboard helper ──────────────────────────────────────────────────────────

void _copyAndToast(BuildContext context, String value, String message) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content:         Text(message),
      behavior:        SnackBarBehavior.floating,
      duration:        const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1E2028),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _SupplierOverviewCard — grouped contact intelligence
// ─────────────────────────────────────────────────────────────────────────────

class _SupplierOverviewCard extends StatelessWidget {
  final Supplier supplier;
  const _SupplierOverviewCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final hasLocation = supplier.city.isNotEmpty ||
        supplier.country.isNotEmpty ||
        supplier.location != null;
    final hasContacts = supplier.contactName  != null ||
        supplier.contactEmail != null ||
        supplier.contactPhone != null;
    final hasDigital  = supplier.website != null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: Icons.business_outlined, label: 'SUPPLIER OVERVIEW'),

          const SizedBox(height: AppSpacing.base),

          // Location
          if (hasLocation) ...[
            _GroupLabel('Location'),
            if (supplier.city.isNotEmpty)
              _OverviewRow(
                  icon: Icons.location_city_outlined,
                  label: 'City',
                  value: supplier.city),
            if (supplier.country.isNotEmpty)
              _OverviewRow(
                  icon: Icons.public_outlined,
                  label: 'Country',
                  value: supplier.country),
            if (supplier.location != null)
              _OverviewRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: supplier.location!),
            if (hasContacts || hasDigital) const _SectionDivider(),
          ],

          // Contacts
          if (hasContacts) ...[
            _GroupLabel('Contacts'),
            if (supplier.contactName != null)
              _OverviewRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Contact',
                  value: supplier.contactName!),
            if (supplier.contactEmail != null)
              _OverviewRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: supplier.contactEmail!,
                  copyable: true),
            if (supplier.contactPhone != null)
              _OverviewRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: supplier.contactPhone!,
                  copyable: true),
            if (hasDigital) const _SectionDivider(),
          ],

          // Digital
          if (hasDigital) ...[
            _GroupLabel('Digital'),
            _OverviewRow(
                icon: Icons.language_rounded,
                label: 'Website',
                value: supplier.website!,
                copyable: true),
          ],

          // Empty state
          if (!hasLocation && !hasContacts && !hasDigital)
            _EmptyInfo(
                message:
                    'No contact information added. Tap Edit to fill in details.'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OperationalPanel — right column
// ─────────────────────────────────────────────────────────────────────────────

class _OperationalPanel extends StatelessWidget {
  final Supplier supplier;
  const _OperationalPanel({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplier.preferred) ...[
          _PreferredPartnerCard(supplier: supplier),
          const SizedBox(height: AppSpacing.base),
        ],
        _InternalNotesCard(notes: supplier.notes),
        if (supplier.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.base),
          _TagsCard(tags: supplier.tags),
        ],
      ],
    );
  }
}

// ── Preferred Partner card ────────────────────────────────────────────────────

class _PreferredPartnerCard extends StatelessWidget {
  final Supplier supplier;
  const _PreferredPartnerCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            AppColors.accent.withAlpha(14),
            AppColors.accentFaint,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.accentLight),
        boxShadow: const [
          BoxShadow(
            color:      Color(0x06000000),
            blurRadius: 8,
            offset:     Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  30,
                height: 30,
                decoration: BoxDecoration(
                  color:        AppColors.accent.withAlpha(22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.diamond_outlined,
                    size: 15, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Text(
                'Preferred Partner',
                style: AppTextStyles.labelMedium.copyWith(
                  color:      AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _PreferredRow(
            label: 'Rating',
            child: RatingDots(
              rating: supplier.internalRating,
              size:   13,
              color:  AppColors.accent,
            ),
          ),
          if (supplier.supplierSubtype != null) ...[
            const SizedBox(height: 6),
            _PreferredRow(
              label: 'Speciality',
              child: Text(
                subtypeLabel(supplier.supplierSubtype!),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _PreferredRow(
            label: 'Category',
            child: Text(
              supplier.effectiveSupplierType.label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferredRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _PreferredRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
        ),
        child,
      ],
    );
  }
}

// ── Internal Notes card ───────────────────────────────────────────────────────

class _InternalNotesCard extends StatelessWidget {
  final String? notes;
  const _InternalNotesCard({this.notes});

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes != null && notes!.isNotEmpty;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: Icons.notes_rounded, label: 'INTERNAL NOTES'),
          const SizedBox(height: AppSpacing.md),
          if (hasNotes)
            Text(
              notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color:  AppColors.textSecondary,
                height: 1.6,
              ),
            )
          else
            _EmptyInfo(
                message:
                    'No notes added. Open Edit to document internal knowledge.'),
        ],
      ),
    );
  }
}

// ── Tags card ─────────────────────────────────────────────────────────────────

class _TagsCard extends StatelessWidget {
  final List<String> tags;
  const _TagsCard({required this.tags});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: Icons.label_outline_rounded, label: 'TAGS'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing:    AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        t,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color:      Color(0x05000000),
            blurRadius: 8,
            offset:     Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _CardHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 7),
        Text(label, style: AppTextStyles.overline),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color:         AppColors.textMuted,
          fontWeight:    FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     copyable;

  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: copyable
                ? GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:         Text('$label copied'),
                          behavior:        SnackBarBehavior.floating,
                          duration:        const Duration(seconds: 2),
                          backgroundColor: const Color(0xFF1E2028),
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: AppTextStyles.labelSmall.copyWith(
                              color:           AppColors.textPrimary,
                              decoration:      TextDecoration.underline,
                              decorationColor: AppColors.border,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.copy_outlined,
                              size: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : Text(
                    value,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textPrimary),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(color: AppColors.divider, height: 1),
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  final String message;
  const _EmptyInfo({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        message,
        style: AppTextStyles.bodySmall.copyWith(
          color:      AppColors.textMuted,
          fontStyle:  FontStyle.italic,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete confirmation — shared by both desktop and mobile hero widgets
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _confirmDelete(
  BuildContext context,
  Supplier supplier,
  SupplierProvider provider,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title:   Text('Delete supplier?', style: AppTextStyles.heading3),
      content: Text(
        'This will permanently remove "${supplier.name}" from your database. '
        'This action cannot be undone.',
        style: AppTextStyles.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: AppTextStyles.labelMedium),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete',
              style: AppTextStyles.labelMedium
                  .copyWith(color: const Color(0xFFB00020))),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    provider.deleteSupplier(supplier.id);
    Navigator.of(context).pop();
  }
}
