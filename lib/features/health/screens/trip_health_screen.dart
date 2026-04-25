import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/supabase/app_db.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/milestone_status.dart';
import '../../../data/models/trip_exception.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/services/critical_path_engine.dart';
import '../providers/trip_health_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TripHealthScreen
// ─────────────────────────────────────────────────────────────────────────────

class TripHealthScreen extends StatefulWidget {
  final Trip trip;
  const TripHealthScreen({super.key, required this.trip});

  @override
  State<TripHealthScreen> createState() => _TripHealthScreenState();
}

class _TripHealthScreenState extends State<TripHealthScreen>
    with AutomaticKeepAliveClientMixin {
  late final TripHealthProvider _provider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final repos = AppRepositories.instance;
    _provider = TripHealthProvider(
      trip:       widget.trip,
      tasks:      repos?.tasks,
      components: repos?.components,
      budget:     repos?.budget,
      itinerary:  repos?.itinerary,
      runSheets:  repos?.runSheets,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          );
        }
        if (_provider.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 36, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text(_provider.error!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.base),
                FilledButton.icon(
                  onPressed: _provider.reload,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent),
                ),
              ],
            ),
          );
        }

        final hPad = Responsive.isMobile(context)
            ? AppSpacing.pagePaddingHMobile
            : AppSpacing.pagePaddingH;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(onRefresh: _provider.reload),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryHeader(provider: _provider),
                    const SizedBox(height: AppSpacing.xxl),
                    _ExceptionsPanel(provider: _provider),
                    const SizedBox(height: AppSpacing.xxl),
                    _MilestonesPanel(milestones: _provider.milestones),
                    const SizedBox(height: AppSpacing.xxl),
                    _CriticalPathPanel(result: _provider.criticalPath),
                    const SizedBox(height: AppSpacing.massive),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _Toolbar({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip Health', style: AppTextStyles.heading2),
              const SizedBox(height: 2),
              Text(
                'Operational visibility, risk monitoring & readiness scoring.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Refresh health data',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header — 4 metric cards
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final TripHealthProvider provider;
  const _SummaryHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final r         = provider.readiness;
    final cp        = provider.criticalPath;
    final excTotal  = provider.totalExceptionCount;
    final excHigh   = provider.highExceptionCount;
    final supRisk   = provider.supplierRiskCount;
    final isMobile  = Responsive.isMobile(context);

    final readColor   = _scoreColor(r.score);
    final cpColor     = _cpColor(cp.status);
    final excColor    = excTotal > 0
        ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final supColor    = supRisk > 0
        ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    final cards = <Widget>[
      _MetricCard(
        icon:       Icons.favorite_rounded,
        iconColor:  readColor,
        label:      'Trip Readiness',
        value:      '${r.score}%',
        valueColor: readColor,
        sub:        _scoreLabel(r.score),
      ),
      _MetricCard(
        icon:       Icons.route_rounded,
        iconColor:  cpColor,
        label:      'Critical Path',
        value:      _cpLabel(cp.status),
        valueColor: cpColor,
        sub:        '${cp.criticalTasks.length} critical task(s)',
      ),
      _MetricCard(
        icon:       Icons.warning_amber_rounded,
        iconColor:  excColor,
        label:      'Exceptions',
        value:      '$excTotal',
        valueColor: excTotal > 0 ? const Color(0xFFB45309) : const Color(0xFF10B981),
        sub:        '$excHigh high severity',
      ),
      _MetricCard(
        icon:       Icons.storefront_rounded,
        iconColor:  supColor,
        label:      'Supplier Risks',
        value:      '$supRisk',
        valueColor: supColor,
        sub:        supRisk > 0 ? 'Require attention' : 'No risks detected',
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount:  2,
        shrinkWrap:      true,
        physics:         const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing:  AppSpacing.sm,
        childAspectRatio: 1.55,
        children: cards,
      );
    }

    return Row(
      children: cards
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: e.key < cards.length - 1 ? AppSpacing.sm : 0),
                  child: e.value,
                ),
              ))
          .toList(),
    );
  }

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF10B981);
    if (s >= 60) return const Color(0xFF0EA5E9);
    if (s >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(int s) {
    if (s >= 80) return 'Ready';
    if (s >= 60) return 'On Track';
    if (s >= 40) return 'Needs Attention';
    return 'At Risk';
  }

  Color _cpColor(CriticalPathStatus s) => switch (s) {
    CriticalPathStatus.healthy => const Color(0xFF10B981),
    CriticalPathStatus.watch   => const Color(0xFFF59E0B),
    CriticalPathStatus.atRisk  => const Color(0xFFEF4444),
  };

  String _cpLabel(CriticalPathStatus s) => switch (s) {
    CriticalPathStatus.healthy => 'Healthy',
    CriticalPathStatus.watch   => 'Watch',
    CriticalPathStatus.atRisk  => 'At Risk',
  };
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final Color    valueColor;
  final String   sub;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTextStyles.heading1
                  .copyWith(color: valueColor, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: 2),
          Text(sub,
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions panel
// ─────────────────────────────────────────────────────────────────────────────

class _ExceptionsPanel extends StatefulWidget {
  final TripHealthProvider provider;
  const _ExceptionsPanel({required this.provider});

  @override
  State<_ExceptionsPanel> createState() => _ExceptionsPanelState();
}

class _ExceptionsPanelState extends State<_ExceptionsPanel> {
  TripExceptionType? _filter;

  @override
  Widget build(BuildContext context) {
    final all      = widget.provider.exceptions;
    final shown    = _filter == null
        ? all
        : all.where((e) => e.type == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading
        Row(
          children: [
            Text('Exception Monitor', style: AppTextStyles.heading2),
            const SizedBox(width: AppSpacing.sm),
            if (all.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.provider.highExceptionCount > 0
                      ? const Color(0xFFFEE2E2)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${all.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.provider.highExceptionCount > 0
                        ? const Color(0xFFEF4444)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            const Spacer(),
            if (all.isNotEmpty)
              TextButton(
                onPressed: widget.provider.reload,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Refresh',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.accent)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Filter chips
        if (all.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(
                  label:    'All',
                  count:    all.length,
                  selected: _filter == null,
                  color:    AppColors.accent,
                  onTap:    () => setState(() => _filter = null),
                ),
                ...TripExceptionType.values.map((type) {
                  final n =
                      all.where((e) => e.type == type).length;
                  if (n == 0) return const SizedBox.shrink();
                  return _TypeChip(
                    label:    type.label,
                    count:    n,
                    selected: _filter == type,
                    color:    type.color,
                    onTap: () =>
                        setState(() => _filter = _filter == type ? null : type),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Cards or empty state
        if (shown.isEmpty)
          _ExceptionsEmpty()
        else
          Column(
            children: [
              for (int i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                _ExceptionCard(ex: shown[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String    label;
  final int       count;
  final bool      selected;
  final Color     color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.xs),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? color.withAlpha(80) : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color : AppColors.textMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExceptionCard extends StatelessWidget {
  final TripException ex;
  const _ExceptionCard({required this.ex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity bar
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: ex.severity.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Type icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ex.type.color.withAlpha(15),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                Icon(ex.type.icon, size: 14, color: ex.type.color),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ex.severity.bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ex.severity.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ex.severity.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(ex.type.label,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                    if (ex.relatedEntityName != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '· ${ex.relatedEntityName}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(ex.message, style: AppTextStyles.bodySmall),
                const SizedBox(height: 3),
                Text(
                  ex.suggestedAction,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Action badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              ex.actionType.label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExceptionsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 32, color: Color(0xFF10B981)),
          const SizedBox(height: AppSpacing.sm),
          Text('No exceptions detected',
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('All operational checks passed.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Milestones panel
// ─────────────────────────────────────────────────────────────────────────────

class _MilestonesPanel extends StatelessWidget {
  final List<MilestoneStatus> milestones;
  const _MilestonesPanel({required this.milestones});

  @override
  Widget build(BuildContext context) {
    final completed =
        milestones.where((m) => m.completion == MilestoneCompletion.complete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Milestones', style: AppTextStyles.heading2),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$completed / ${milestones.length}',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: Offset(0, 1))
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < milestones.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.divider),
                _MilestoneRow(m: milestones[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final MilestoneStatus m;
  const _MilestoneRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final c          = m.completion;
    final isComplete = c == MilestoneCompletion.complete;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle status icon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isComplete
                  ? Icons.check_rounded
                  : c == MilestoneCompletion.atRisk
                      ? Icons.warning_amber_rounded
                      : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: c.color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isComplete
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  m.description,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
                if (!isComplete && m.pendingCriteria.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ...m.pendingCriteria.map((criterion) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.textMuted)),
                            Expanded(
                              child: Text(
                                criterion,
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Critical Path panel
// ─────────────────────────────────────────────────────────────────────────────

class _CriticalPathPanel extends StatelessWidget {
  final CriticalPathResult result;
  const _CriticalPathPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (result.status) {
      CriticalPathStatus.healthy => const Color(0xFF10B981),
      CriticalPathStatus.watch   => const Color(0xFFF59E0B),
      CriticalPathStatus.atRisk  => const Color(0xFFEF4444),
    };
    final statusBg = switch (result.status) {
      CriticalPathStatus.healthy => const Color(0xFFECFDF5),
      CriticalPathStatus.watch   => const Color(0xFFFEF3C7),
      CriticalPathStatus.atRisk  => const Color(0xFFFEE2E2),
    };
    final statusLabel = switch (result.status) {
      CriticalPathStatus.healthy => 'Healthy',
      CriticalPathStatus.watch   => 'Watch',
      CriticalPathStatus.atRisk  => 'At Risk',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Critical Path', style: AppTextStyles.heading2),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle_rounded,
                      size: 7, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (result.criticalTasks.isEmpty)
          _CriticalEmpty()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 4,
                    offset: Offset(0, 1))
              ],
            ),
            child: Column(
              children: [
                for (int i = 0;
                    i < result.criticalTasks.length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1, color: AppColors.divider),
                  _CriticalTaskRow(ct: result.criticalTasks[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CriticalTaskRow extends StatelessWidget {
  final CriticalTask ct;
  const _CriticalTaskRow({required this.ct});

  @override
  Widget build(BuildContext context) {
    final dotColor = ct.isOverdue
        ? const Color(0xFFEF4444)
        : ct.isDueSoon
            ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6);

    final rowBg = ct.isOverdue
        ? const Color(0xFFFFF5F5)
        : ct.isDueSoon
            ? const Color(0xFFFFFBEB)
            : AppColors.surface;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ct.task.name,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(ct.reason,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                    if (ct.task.category != null) ...[
                      Text(' · ',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                      Flexible(
                        child: Text(
                          ct.task.category!,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (ct.task.dueDate != null)
            _DueDatePill(
              date:      ct.task.dueDate!,
              isOverdue: ct.isOverdue,
              isDueSoon: ct.isDueSoon,
            ),
        ],
      ),
    );
  }
}

class _DueDatePill extends StatelessWidget {
  final DateTime date;
  final bool     isOverdue;
  final bool     isDueSoon;
  const _DueDatePill(
      {required this.date, required this.isOverdue, required this.isDueSoon});

  @override
  Widget build(BuildContext context) {
    final color = isOverdue
        ? const Color(0xFFEF4444)
        : isDueSoon
            ? const Color(0xFFF59E0B)
            : AppColors.textMuted;
    final bg = isOverdue
        ? const Color(0xFFFEE2E2)
        : isDueSoon
            ? const Color(0xFFFEF3C7)
            : AppColors.surfaceAlt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        DateFormat('d MMM').format(date),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _CriticalEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 20, color: Color(0xFF10B981)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'No critical path issues detected.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
