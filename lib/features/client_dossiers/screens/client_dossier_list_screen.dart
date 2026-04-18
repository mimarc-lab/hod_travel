import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/client_dossier_model.dart';
import '../providers/client_dossier_provider.dart';
import 'client_dossier_detail_screen.dart';
import 'client_dossier_form_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClientDossierListScreen
// ─────────────────────────────────────────────────────────────────────────────

class ClientDossierListScreen extends StatefulWidget {
  const ClientDossierListScreen({super.key});

  @override
  State<ClientDossierListScreen> createState() => _ClientDossierListScreenState();
}

class _ClientDossierListScreenState extends State<ClientDossierListScreen> {
  late final ClientDossierProvider _provider;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = ClientDossierProvider(
      repository: repos?.clientDossiers,
      teamId:     repos?.currentTeamId ?? '',
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetail(ClientDossier dossier) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientDossierDetailScreen(
        dossier:  dossier,
        provider: _provider,
      ),
    ));
  }

  Future<void> _createNew() async {
    final created = await Navigator.of(context).push<ClientDossier>(
      MaterialPageRoute(
        builder: (_) => ClientDossierFormScreen(provider: _provider),
      ),
    );
    if (created != null && mounted) _openDetail(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            provider:  _provider,
            searchCtrl: _searchCtrl,
            onNewTap:  _createNew,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _provider,
              builder: (context, _) {
                if (_provider.isLoading && _provider.totalCount == 0) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  );
                }

                final items = _provider.filteredDossiers;

                if (items.isEmpty) {
                  return _EmptyState(
                    hasFilters: _provider.hasActiveFilters,
                    onClear: _provider.clearFilters,
                    onAdd: _createNew,
                  );
                }

                return Column(
                  children: [
                    if (Responsive.showSidebar(context)) _TableHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: Responsive.isMobile(context)
                            ? const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePaddingHMobile,
                                vertical: AppSpacing.sm)
                            : EdgeInsets.zero,
                        itemCount: items.length,
                        itemBuilder: (_, i) => _DossierRow(
                          dossier:  items[i],
                          isMobile: Responsive.isMobile(context),
                          onTap:    () => _openDetail(items[i]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ClientDossierProvider provider;
  final TextEditingController searchCtrl;
  final VoidCallback onNewTap;

  const _Header({
    required this.provider,
    required this.searchCtrl,
    required this.onNewTap,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.isMobile(context)
        ? AppSpacing.pagePaddingHMobile
        : AppSpacing.pagePaddingH;

    return Container(
      color: AppColors.surface,
      padding:
          EdgeInsets.symmetric(horizontal: hPad, vertical: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Dossiers', style: AppTextStyles.displayMedium),
                    ListenableBuilder(
                      listenable: provider,
                      builder: (_, __) => Text(
                        '${provider.totalCount} client profiles',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              _NewButton(onTap: onNewTap),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(child: _SearchField(ctrl: searchCtrl, provider: provider)),
              const SizedBox(width: AppSpacing.sm),
              _TypeFilterMenu(provider: provider),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text('New Client',
                style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final ClientDossierProvider provider;
  const _SearchField({required this.ctrl, required this.provider});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: provider.setSearch,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by name or base…',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 16, color: AppColors.textMuted),
        suffixIcon: ListenableBuilder(
          listenable: provider,
          builder: (_, __) => provider.searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () { ctrl.clear(); provider.setSearch(''); },
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: AppColors.textMuted),
                )
              : const SizedBox.shrink(),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _TypeFilterMenu extends StatelessWidget {
  final ClientDossierProvider provider;
  const _TypeFilterMenu({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (_, __) {
        final active = provider.typeFilter != null;
        return PopupMenuButton<TripType?>(
          onSelected: provider.setTypeFilter,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.surface,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? AppColors.accentFaint : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                  color: active ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_rounded,
                    size: 14,
                    color: active ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  provider.typeFilter?.label ?? 'Type',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: active ? AppColors.accent : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          itemBuilder: (_) => [
            const PopupMenuItem(value: null, child: Text('All types')),
            ...TripType.values.map((t) =>
                PopupMenuItem(value: t, child: Text(t.label))),
          ],
        );
      },
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          const SizedBox(width: 40 + AppSpacing.base),
          _Col(label: 'CLIENT / FAMILY', flex: 5),
          _Col(label: 'TRIP TYPE', flex: 3),
          _Col(label: 'BASE', flex: 3),
          _Col(label: 'TRAVELERS', flex: 2),
          _Col(label: 'UPDATED', flex: 2),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String label;
  final int flex;
  const _Col({required this.label, required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
      );
}

// ── Dossier row ───────────────────────────────────────────────────────────────

class _DossierRow extends StatelessWidget {
  final ClientDossier dossier;
  final bool isMobile;
  final VoidCallback onTap;

  const _DossierRow({
    required this.dossier,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) return _MobileCard(dossier: dossier, onTap: onTap);

    final updated = _formatDate(dossier.updatedAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceAlt,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingH,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              _Avatar(name: dossier.displayName),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dossier.displayName,
                        style: AppTextStyles.labelMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (dossier.familyName != null &&
                        dossier.primaryClientName != dossier.displayName)
                      Text(dossier.primaryClientName,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: dossier.typicalTripType != null
                    ? _TypeChip(label: dossier.typicalTripType!.label)
                    : Text('—',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
              ),
              Expanded(
                flex: 3,
                child: Text(dossier.homeBase ?? '—',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  dossier.travelers.isEmpty
                      ? '—'
                      : '${dossier.travelers.length}',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(updated,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MobileCard extends StatelessWidget {
  final ClientDossier dossier;
  final VoidCallback onTap;
  const _MobileCard({required this.dossier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Avatar(name: dossier.displayName),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dossier.displayName,
                      style: AppTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (dossier.typicalTripType != null) ...[
                        _TypeChip(label: dossier.typicalTripType!.label),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (dossier.homeBase != null)
                        Text(dossier.homeBase!,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.accentFaint,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textSecondary, fontSize: 10)),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final VoidCallback onAdd;
  const _EmptyState(
      {required this.hasFilters, required this.onClear, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            child: const Icon(Icons.person_outline_rounded,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilters ? 'No clients match filters' : 'No client dossiers yet',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting your search or filters.'
                : 'Create your first client dossier to start personalising trips.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasFilters)
            GestureDetector(
              onTap: onClear,
              child: Text('Clear filters',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.accent)),
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                child: Text('Create First Client',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
