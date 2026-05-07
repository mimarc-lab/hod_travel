import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../features/workflow_scheduling/planning_deadline_helper.dart';
import '../../../data/models/trip_model.dart';
import '../providers/board_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlanningTimelineBanner
//
// Derives planning metrics directly from the live BoardProvider task list:
//   • Planning Start  = min(task.travelDate) across scheduled tasks
//   • Complete By     = trip.startDate − PlanningDeadlineHelper.defaultBufferDays
//   • Duration        = latestDueDate − earliestStartDate + 1  (span, NOT sum)
//   • Total Effort    = Σ task.estimatedDurationDays            (task-days)
//
// Shown as a compact one-line strip between the tab bar and the board content.
// ─────────────────────────────────────────────────────────────────────────────

class PlanningTimelineBanner extends StatelessWidget {
  final Trip trip;
  final BoardProvider provider;
  /// When true, renders a compact card (used inside the mobile trip header).
  final bool compact;

  const PlanningTimelineBanner({
    super.key,
    required this.trip,
    required this.provider,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, child) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final tasks = provider.groups
        .expand((g) => g.tasks)
        .where((t) => t.travelDate != null && t.dueDate != null)
        .toList();

    if (tasks.isEmpty) return const SizedBox.shrink();

    final earliest = tasks
        .map((t) => t.travelDate!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = tasks
        .map((t) => t.dueDate!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final durationDays = latest.difference(earliest).inDays + 1;

    final totalEffort = tasks.fold<int>(
      0,
      (sum, t) => sum + (t.estimatedDurationDays ?? 0),
    );
    final approxHours = totalEffort * 8;

    final deadline = trip.startDate
        ?.subtract(Duration(days: PlanningDeadlineHelper.defaultBufferDays));
    final isPast = deadline?.isBefore(DateTime.now()) ?? false;

    if (compact) {
      return _buildCompactCard(
        isPast: isPast,
        earliest: earliest,
        deadline: deadline,
        durationDays: durationDays,
        totalEffort: totalEffort,
      );
    }

    // ── Strip layout (desktop / tablet) ──────────────────────────────────────
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFFFFF7ED) : const Color(0xFFF0F9FF),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 13,
                color: isPast ? const Color(0xFFB45309) : const Color(0xFF0369A1)),
            const SizedBox(width: 6),
            Text(
              'Planning Timeline',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isPast ? const Color(0xFFB45309) : const Color(0xFF0369A1),
              ),
            ),
            const SizedBox(width: 16),
            _Stat(label: 'Start', value: _fmt(earliest)),
            _Divider(),
            _Stat(
              label: 'Complete By',
              value: deadline != null ? _fmt(deadline) : '—',
              valueColor: isPast ? const Color(0xFFEF4444) : null,
            ),
            _Divider(),
            _Stat(label: 'Duration', value: '$durationDays days'),
            _Divider(),
            _Stat(
              label: 'Team Effort',
              value: '$totalEffort task-days  (~${approxHours}h)',
              tooltip: 'Sum of all individual task durations — '
                  'larger than the timeline span because tasks run in parallel. '
                  'Working hours assume 8h per task-day.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact card layout (mobile expandable header) ────────────────────────

  Widget _buildCompactCard({
    required bool isPast,
    required DateTime earliest,
    required DateTime? deadline,
    required int durationDays,
    required int totalEffort,
  }) {
    final accent = isPast ? const Color(0xFFB45309) : const Color(0xFF0369A1);
    final bg     = isPast ? const Color(0xFFFFF7ED) : const Color(0xFFF0F9FF);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Icon(Icons.schedule_outlined, size: 13, color: accent),
                const SizedBox(width: 5),
                Text(
                  'Planning Timeline',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: accent.withAlpha(30)),
          // Stats row
          IntrinsicHeight(
            child: Row(
              children: [
                _CompactStat(label: 'Start',       value: _fmt(earliest)),
                _VertDivider(color: accent),
                _CompactStat(
                  label: 'Complete By',
                  value: deadline != null ? _fmt(deadline) : '—',
                  valueColor: isPast ? const Color(0xFFEF4444) : null,
                ),
                _VertDivider(color: accent),
                _CompactStat(label: 'Duration',    value: '$durationDays days'),
                _VertDivider(color: accent),
                _CompactStat(label: 'Effort',      value: '$totalEffort td'),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) => DateFormat('d MMM').format(d);
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;
  const _Stat({required this.label, required this.value, this.valueColor, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        Text(
          value,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (tooltip != null) ...[
          const SizedBox(width: 3),
          Tooltip(
            message: tooltip!,
            preferBelow: true,
            child: const Icon(Icons.info_outline_rounded, size: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
    return row;
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('·',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
    );
  }
}

// ── Compact card helpers ──────────────────────────────────────────────────────

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _CompactStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final Color color;
  const _VertDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color.withAlpha(30));
  }
}
