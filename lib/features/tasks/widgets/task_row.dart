import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/task_model.dart';
import '../../../shared/adaptive_table/adaptive_column.dart';
import '../../../shared/adaptive_table/adaptive_mobile_card.dart';
import '../../../shared/adaptive_table/adaptive_priority_chip.dart';
import '../../../shared/adaptive_table/adaptive_row.dart';
import '../../../shared/adaptive_table/adaptive_status_chip.dart';
import '../../../shared/design_system/responsive_breakpoints.dart';
import '../../../shared/design_system/shadow_tokens.dart';
import '../../../shared/design_system/radius_tokens.dart';
import '../../../shared/design_system/spacing_tokens.dart';
import '../../../shared/design_system/typography_tokens.dart';
import '../../../shared/widgets/user_avatar.dart';

// ── Domain helpers (preserved exactly from task_center_screen.dart) ────────────

bool taskIsTerminal(TaskStatus s) =>
    s == TaskStatus.confirmed || s == TaskStatus.cancelled;

bool taskIsOverdue(Task t) =>
    t.dueDate != null &&
    t.dueDate!.isBefore(DateTime.now()) &&
    !taskIsTerminal(t.status);

Color taskAccentColor(TaskStatus status, bool isOverdue) {
  if (isOverdue) return const Color(0xFFEF4444);
  switch (status) {
    case TaskStatus.notStarted:     return const Color(0xFFD1D5DB);
    case TaskStatus.researching:    return const Color(0xFF3B82F6);
    case TaskStatus.awaitingReply:  return const Color(0xFFF59E0B);
    case TaskStatus.readyForReview: return const Color(0xFF8B5CF6);
    case TaskStatus.approved:       return const Color(0xFF059669);
    case TaskStatus.sentToClient:   return const Color(0xFFC9A96E);
    case TaskStatus.confirmed:      return const Color(0xFF10B981);
    case TaskStatus.cancelled:      return const Color(0xFF9CA3AF);
  }
}

String taskOperationalLabel(TaskStatus status, bool isOverdue) {
  if (isOverdue) return 'Overdue';
  switch (status) {
    case TaskStatus.notStarted:     return 'Not started';
    case TaskStatus.researching:    return 'In research';
    case TaskStatus.awaitingReply:  return 'Waiting on supplier';
    case TaskStatus.readyForReview: return 'Ready for review';
    case TaskStatus.approved:       return 'Approved';
    case TaskStatus.sentToClient:   return 'Sent to client';
    case TaskStatus.confirmed:      return 'Confirmed';
    case TaskStatus.cancelled:      return 'Cancelled';
  }
}

// ── Status + priority chip helpers ────────────────────────────────────────────

AdaptiveStatusChip _statusChip(Task task, bool isOverdue, {bool compact = true}) {
  final accent = taskAccentColor(task.status, isOverdue);
  final label  = taskOperationalLabel(task.status, isOverdue);
  return AdaptiveStatusChip(
    label: label,
    backgroundColor: accent.withAlpha(24),
    textColor: accent,
    compact: compact,
  );
}

AdaptivePriorityChip _priorityChip(Task task, {bool compact = true}) {
  final p = switch (task.priority) {
    TaskPriority.low    => AdaptivePriority.low,
    TaskPriority.medium => AdaptivePriority.medium,
    TaskPriority.high   => AdaptivePriority.high,
  };
  return AdaptivePriorityChip(priority: p, compact: compact);
}

// ── Due-date formatter ─────────────────────────────────────────────────────────

String _dueText(DateTime d, bool overdue) {
  if (overdue) return 'Overdue';
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff  = d.difference(today).inDays;
  if (diff == 0) return 'Due Today';
  if (diff == 1) return 'Due Tomorrow';
  return DateFormat('d MMM').format(d);
}

Color _dueColor(DateTime d, bool overdue) {
  if (overdue) return const Color(0xFFEF4444);
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return d.difference(today).inDays == 0
      ? const Color(0xFFF59E0B)
      : AppColors.textMuted;
}

// ── Column definitions ─────────────────────────────────────────────────────────

/// Adaptive column set for the Tasks module.
/// Pass [showTrip] = false in grouped-by-trip views.
List<AdaptiveColumn<Task>> taskColumns({
  bool showTrip = true,
  Map<String, String>? tripNames,
}) {
  return [
    // PRIMARY — task name (always visible)
    AdaptiveColumn<Task>(
      key: 'name',
      label: 'Task',
      priority: ColumnPriority.primary,
      flex: 3,
      builder: (task) {
        final overdue = taskIsOverdue(task);
        final tripName = showTrip && tripNames != null
            ? tripNames[task.tripId]
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.name,
              style: AdaptiveTypography.primaryCell.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (tripName != null && tripName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                tripName,
                style: AdaptiveTypography.primarySubCell,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (overdue) ...[
              const SizedBox(height: 2),
              Text(
                'Overdue',
                style: AdaptiveTypography.tertiaryCell.copyWith(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );
      },
    ),

    // SECONDARY — status chip
    AdaptiveColumn<Task>(
      key: 'status',
      label: 'Status',
      priority: ColumnPriority.secondary,
      width: 140,
      builder: (task) => _statusChip(task, taskIsOverdue(task)),
    ),

    // SECONDARY — due date
    AdaptiveColumn<Task>(
      key: 'due',
      label: 'Due',
      priority: ColumnPriority.secondary,
      width: 100,
      builder: (task) {
        if (task.dueDate == null) {
          return Text('—', style: AdaptiveTypography.secondaryCell);
        }
        final overdue = taskIsOverdue(task);
        final text    = _dueText(task.dueDate!, overdue);
        final color   = _dueColor(task.dueDate!, overdue);
        return Text(
          text,
          style: AdaptiveTypography.secondaryCell.copyWith(
            color: color,
            fontWeight: (overdue || text == 'Due Today')
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        );
      },
    ),

    // SECONDARY — priority pill
    AdaptiveColumn<Task>(
      key: 'priority',
      label: 'Priority',
      priority: ColumnPriority.secondary,
      width: 90,
      builder: (task) => _priorityChip(task),
    ),

    // TERTIARY — assignee avatar (desktop only)
    AdaptiveColumn<Task>(
      key: 'assignee',
      label: 'Assignee',
      priority: ColumnPriority.tertiary,
      width: 60,
      alignment: ColumnAlignment.center,
      hideLabel: false,
      builder: (task) => task.assignedTo != null
          ? UserAvatar(user: task.assignedTo!, size: 26)
          : Text('—',
              style: AdaptiveTypography.tertiaryCell,
              textAlign: TextAlign.center),
    ),
  ];
}

// ── TaskRow — adaptive entry point ────────────────────────────────────────────

/// Renders a [Task] as an [AdaptiveRow] on desktop/tablet or an
/// [AdaptiveMobileCard] on mobile — both using the shared design tokens.
///
/// All business logic (onTap routing, overdue detection, accent colour) is
/// computed here and passed through; no logic lives in the visual layer.
class TaskRow extends StatelessWidget {
  final Task task;
  final String? tripName;
  final bool showTrip;
  final VoidCallback onTap;

  const TaskRow({
    super.key,
    required this.task,
    required this.onTap,
    this.tripName,
    this.showTrip = true,
  });

  @override
  Widget build(BuildContext context) {
    final layout  = AdaptiveBreakpoints.layoutOf(context);
    final overdue = taskIsOverdue(task);
    final accent  = taskAccentColor(task.status, overdue);

    if (layout == Layout.mobile) {
      return _MobileTaskCard(
        task: task,
        tripName: showTrip ? tripName : null,
        overdue: overdue,
        accent: accent,
        onTap: onTap,
      );
    }

    // Desktop / Tablet: AdaptiveRow with full column set
    final cols = taskColumns(
      showTrip: showTrip,
      tripNames: tripName != null ? {task.tripId ?? '': tripName!} : {},
    );

    return AdaptiveRow<Task>(
      item: task,
      columns: cols,
      layout: layout,
      onTap: onTap,
      accentBar: accent,
    );
  }
}

// ── Mobile card ───────────────────────────────────────────────────────────────

class _MobileTaskCard extends StatefulWidget {
  final Task task;
  final String? tripName;
  final bool overdue;
  final Color accent;
  final VoidCallback onTap;

  const _MobileTaskCard({
    required this.task,
    required this.overdue,
    required this.accent,
    required this.onTap,
    this.tripName,
  });

  @override
  State<_MobileTaskCard> createState() => _MobileTaskCardState();
}

class _MobileTaskCardState extends State<_MobileTaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task    = widget.task;
    final overdue = widget.overdue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AdaptiveRadius.cardBorder,
            boxShadow:
                _hovered ? AdaptiveShadows.cardHover : AdaptiveShadows.cardResting,
          ),
          child: ClipRRect(
            borderRadius: AdaptiveRadius.cardBorder,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(width: 3, color: widget.accent),

                  // Card body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdaptiveSpacing.rowPaddingH,
                        vertical: AdaptiveSpacing.rowPaddingV,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row + status chip
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF111111),
                                        height: 1.3,
                                        letterSpacing: -0.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.tripName != null &&
                                        widget.tripName!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.tripName!,
                                        style: AdaptiveTypography.primarySubCell,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _statusChip(task, overdue),
                              if (task.assignedTo != null) ...[
                                const SizedBox(width: 8),
                                UserAvatar(user: task.assignedTo!, size: 26),
                              ],
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Meta row: due date · priority · state label
                          Row(
                            children: [
                              if (task.dueDate != null) ...[
                                Text(
                                  _dueText(task.dueDate!, overdue),
                                  style: AdaptiveTypography.tertiaryCell.copyWith(
                                    color: _dueColor(task.dueDate!, overdue),
                                    fontWeight: overdue ||
                                            _dueText(task.dueDate!, overdue) ==
                                                'Due Today'
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD1D5DB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _priorityChip(task),
                              const Spacer(),
                              Text(
                                taskOperationalLabel(task.status, overdue),
                                style: AdaptiveTypography.tertiaryCell,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
