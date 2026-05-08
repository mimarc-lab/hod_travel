import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../../../features/ai_suggestions/itinerary_sequence/itinerary_sequence_review_screen.dart';
import '../../../features/budget/providers/budget_provider.dart';
import '../../../features/itinerary/providers/itinerary_provider.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../providers/components_provider.dart';
import '../widgets/component_filter_bar.dart';
import '../widgets/component_form_sheet.dart';
import '../widgets/component_table_row.dart';

class TripComponentsScreen extends StatefulWidget {
  final Trip trip;
  final ItineraryProvider? itineraryProvider;
  final BudgetProvider?    budgetProvider;

  const TripComponentsScreen({
    super.key,
    required this.trip,
    this.itineraryProvider,
    this.budgetProvider,
  });

  @override
  State<TripComponentsScreen> createState() => _TripComponentsScreenState();
}

class _TripComponentsScreenState extends State<TripComponentsScreen>
    with AutomaticKeepAliveClientMixin {
  late final ComponentsProvider _provider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _provider = ComponentsProvider(
      trip:       widget.trip,
      repository: AppRepositories.instance?.components,
      teamId:     AppRepositories.instance?.currentTeamId,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    showComponentFormSheet(
      context,
      trip:              widget.trip,
      provider:          _provider,
      itineraryProvider: widget.itineraryProvider,
      budgetProvider:    widget.budgetProvider,
    );
  }

  void _openSequenceDraft() {
    showItinerarySequenceReview(context, trip: widget.trip);
  }

  void _openEditSheet(TripComponent component) {
    showComponentFormSheet(
      context,
      trip:              widget.trip,
      provider:          _provider,
      existing:          component,
      itineraryProvider: widget.itineraryProvider,
      budgetProvider:    widget.budgetProvider,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TripComponent component) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete component?'),
        content: Text('Delete "${component.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) _provider.deleteComponent(component.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComponentsToolbar(
          onAdd:        _openAddSheet,
          onRefresh:    _provider.refresh,
          onBuildDraft: _openSequenceDraft,
        ),
        ComponentFilterBar(provider: _provider),
        Expanded(
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              final err = _provider.error;
              if (err != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 36, color: Colors.red),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Failed to load components',
                            style: AppTextStyles.heading3),
                        const SizedBox(height: AppSpacing.xs),
                        Text(err,
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.base),
                        OutlinedButton.icon(
                          onPressed: () {
                            _provider.clearError();
                            _provider.refresh();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_provider.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final items   = _provider.filtered;
              final isMobile = Responsive.isMobile(context);
              final hPad = isMobile
                  ? AppSpacing.pagePaddingHMobile
                  : AppSpacing.pagePaddingH;

              if (items.isEmpty) {
                return _EmptyState(
                  hasFilter: _provider.filterType != null ||
                      _provider.filterStatus != null,
                  onAdd: _openAddSheet,
                );
              }

              return Column(
                children: [
                  ComponentColumnHeader(hPad: hPad),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _provider.refresh,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            hPad, 8, hPad, AppSpacing.massive),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AdaptiveSpacing.rowGap),
                        itemBuilder: (context, i) => ComponentRow(
                          key:      ValueKey(items[i].id),
                          component: items[i],
                          onEdit:   () => _openEditSheet(items[i]),
                          onDelete: () => _confirmDelete(context, items[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _ComponentsToolbar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onBuildDraft;
  final Future<void> Function() onRefresh;

  const _ComponentsToolbar({
    required this.onAdd,
    required this.onRefresh,
    required this.onBuildDraft,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final hPad =
        isMobile ? AppSpacing.pagePaddingHMobile : AppSpacing.pagePaddingH;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirmed Trip Components',
                    style: AppTextStyles.heading2),
                const SizedBox(height: 2),
                Text(
                  'Track all accommodation, experiences, transport and services',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            GestureDetector(
              onTap: onBuildDraft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF0F766E).withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_timeline_rounded,
                        size: 13, color: Color(0xFF0F766E)),
                    const SizedBox(width: 5),
                    Text(
                      'Build Itinerary Draft',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: const Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              color: AppColors.textSecondary,
              tooltip: 'Refresh',
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: isMobile
                ? const Text('Add')
                : const Text('Add Component'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onAdd;

  const _EmptyState({required this.hasFilter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accentFaint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_rounded,
                size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilter
                ? 'No components match your filters'
                : 'No components yet',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasFilter
                ? 'Try clearing your filters to see all components.'
                : 'Add accommodation, experiences, transport and more.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (!hasFilter) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Component'),
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
