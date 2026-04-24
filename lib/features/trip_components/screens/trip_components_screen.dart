import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../data/models/trip_component_model.dart';
import '../../../data/models/trip_model.dart';
import '../providers/components_provider.dart';
import '../widgets/component_card.dart';
import '../widgets/component_filter_bar.dart';
import '../widgets/component_form_sheet.dart';

class TripComponentsScreen extends StatefulWidget {
  final Trip trip;

  const TripComponentsScreen({super.key, required this.trip});

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
      trip:     widget.trip,
      provider: _provider,
    );
  }

  void _openEditSheet(TripComponent component) {
    showComponentFormSheet(
      context,
      trip:     widget.trip,
      provider: _provider,
      existing: component,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar
        _ComponentsToolbar(onAdd: _openAddSheet),

        // Filter bar
        ComponentFilterBar(provider: _provider),

        const Divider(height: 1, color: AppColors.divider),

        // Content
        Expanded(
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) {
              if (_provider.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = _provider.filtered;

              if (items.isEmpty) {
                return _EmptyState(
                  hasFilter: _provider.filterType != null || _provider.filterStatus != null,
                  onAdd:     _openAddSheet,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: items.length,
                itemBuilder: (context, i) => ComponentCard(
                  key:      ValueKey(items[i].id),
                  component: items[i],
                  provider:  _provider,
                  onEdit:    () => _openEditSheet(items[i]),
                ),
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
  const _ComponentsToolbar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical:   AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirmed Trip Components', style: AppTextStyles.heading2),
              const SizedBox(height: 2),
              Text(
                'Track all accommodation, experiences, transport and services',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Component'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
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
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_rounded, size: 28, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            hasFilter ? 'No components match your filters' : 'No components yet',
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
