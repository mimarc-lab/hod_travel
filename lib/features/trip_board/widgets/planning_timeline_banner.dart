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

  const PlanningTimelineBanner({
    super.key,
    required this.trip,
    required this.provider,
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

    // Timeline span (no double-counting of parallel tasks)
    final earliest = tasks
        .map((t) => t.travelDate!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = tasks
        .map((t) => t.dueDate!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final durationDays = latest.difference(earliest).inDays + 1;

    // Total effort (sum — may be larger than span due to parallel tasks)
    final totalEffort = tasks.fold<int>(
      0,
      (sum, t) => sum + (t.estimatedDurationDays ?? 0),
    );

    // Planning complete-by deadline
    final deadline = trip.startDate
        ?.subtract(Duration(days: PlanningDeadlineHelper.defaultBufferDays));

    final isPast = deadline?.isBefore(DateTime.now()) ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isPast
            ? const Color(0xFFFFF7ED) // amber tint when deadline passed
            : const Color(0xFFF0F9FF), // blue tint otherwise
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              Icons.schedule_outlined,
              size: 13,
              color: isPast ? const Color(0xFFB45309) : const Color(0xFF0369A1),
            ),
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
            _Stat(label: 'Total Effort', value: '$totalEffort task-days'),
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
  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
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
      ],
    );
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
