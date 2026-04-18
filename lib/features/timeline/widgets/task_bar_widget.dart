import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/task_model.dart';
import '../services/timeline_mapper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaskBarWidget
// ─────────────────────────────────────────────────────────────────────────────

/// A single horizontal task bar positioned inside the timeline canvas.
///
/// Features:
///   • Status-keyed muted color (no bright palette)
///   • Overdue: left edge rendered in red
///   • Drag horizontally to shift both travelDate + dueDate
///   • Hover tooltip shows task name, dates, status, assignee
///   • Tap → [onTap] callback to open task detail
class TaskBarWidget extends StatefulWidget {
  final Task task;
  final BarMetrics bar;
  final TimelineDateRange range;
  final VoidCallback? onTap;

  /// Called with the number of days to shift when drag ends.
  /// The parent is responsible for persisting the change.
  final void Function(int daysDelta)? onDragEnd;

  const TaskBarWidget({
    super.key,
    required this.task,
    required this.bar,
    required this.range,
    this.onTap,
    this.onDragEnd,
  });

  @override
  State<TaskBarWidget> createState() => _TaskBarWidgetState();
}

class _TaskBarWidgetState extends State<TaskBarWidget> {
  int _dragDayOffset = 0;
  double _dragStartGlobal = 0;
  bool _isDragging = false;
  bool _isHovered = false;

  OverlayEntry? _tooltip;

  final _barKey = GlobalKey();

  // ── Drag ─────────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails d) {
    _dragStartGlobal = d.globalPosition.dx;
    setState(() {
      _dragDayOffset = 0;
      _isDragging    = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta     = d.globalPosition.dx - _dragStartGlobal;
    final daysDelta = (delta / kDayWidth).round();
    if (daysDelta != _dragDayOffset) {
      setState(() => _dragDayOffset = daysDelta);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final days = _dragDayOffset;
    setState(() {
      _dragDayOffset = 0;
      _isDragging    = false;
    });
    if (days != 0) widget.onDragEnd?.call(days);
  }

  // ── Tooltip ───────────────────────────────────────────────────────────────

  void _showTooltip() {
    _removeTooltip();
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);

    _tooltip = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.dx,
        top:  pos.dy - 88,
        child: _TooltipCard(task: widget.task),
      ),
    );
    Overlay.of(context).insert(_tooltip!);
  }

  void _removeTooltip() {
    _tooltip?.remove();
    _tooltip = null;
  }

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isOverdue = TimelineMapperService.isOverdue(widget.task);
    final bgColor   = _barBg(widget.task.status);
    final textColor = _barText(widget.task.status);

    // Drag is handled via Transform.translate so the parent Positioned
    // stays fixed and we avoid a Positioned-inside-Positioned nesting.
    return Transform.translate(
      offset: Offset(_dragDayOffset * kDayWidth, 0),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _showTooltip();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _removeTooltip();
        },
        child: GestureDetector(
          key:        _barKey,
          onTap:      widget.onTap,
          onHorizontalDragStart:  _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd:    _onDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              // Hover: darker tint (not transparent) so the bar stays visible.
              color: _isDragging
                  ? _darken(bgColor, 0.08)
                  : (_isHovered ? _darken(bgColor, 0.05) : bgColor),
              borderRadius: BorderRadius.circular(5),
              border: Border(
                left: isOverdue
                    ? const BorderSide(color: Color(0xFFEF4444), width: 3)
                    : BorderSide.none,
              ),
              boxShadow: _isHovered || _isDragging
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.task.name,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (widget.task.assignedTo != null) ...[
                    const SizedBox(width: 4),
                    _MiniAvatar(name: widget.task.assignedTo!.initials),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Darkens a color by [amount] (0.0–1.0) without changing opacity.
Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  const _MiniAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFFC9A96E),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TooltipCard extends StatelessWidget {
  final Task task;
  const _TooltipCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isOverdue = TimelineMapperService.isOverdue(task);
    return Material(
      color:       Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240, minWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1814),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.name,
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (task.dueDate != null)
              _Row(
                label: 'Due',
                value: DateFormat('d MMM yyyy').format(task.dueDate!),
                valueColor: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFF9CA3AF),
              ),
            if (task.travelDate != null)
              _Row(
                label: 'Travel',
                value: DateFormat('d MMM yyyy').format(task.travelDate!),
              ),
            _Row(label: 'Status', value: task.status.label),
            if (task.assignedTo != null)
              _Row(label: 'Assignee', value: task.assignedTo!.name),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(label,
                style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.labelSmall.copyWith(
                    color: valueColor ?? const Color(0xFF9CA3AF))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unscheduled placeholder shown in the bar area when task has no dates
// ─────────────────────────────────────────────────────────────────────────────

class UnscheduledBarPlaceholder extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;

  const UnscheduledBarPlaceholder({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: kBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 10, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('No dates',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color mapping — intentionally muted, not saturated
// ─────────────────────────────────────────────────────────────────────────────

const double kBarHeight = 26.0;

Color _barBg(TaskStatus status) => switch (status) {
  TaskStatus.notStarted     => const Color(0xFFEAE9E6),
  TaskStatus.researching    => const Color(0xFFDCEBFD),
  TaskStatus.awaitingReply  => const Color(0xFFFEF0C7),
  TaskStatus.readyForReview => const Color(0xFFEDE9FE),
  TaskStatus.approved       => const Color(0xFFD2F5E4),
  TaskStatus.sentToClient   => const Color(0xFFFEF0C7),
  TaskStatus.confirmed      => const Color(0xFFD2F5E4),
  TaskStatus.cancelled      => const Color(0xFFF1F0EE),
};

Color _barText(TaskStatus status) => switch (status) {
  TaskStatus.notStarted     => const Color(0xFF6B7280),
  TaskStatus.researching    => const Color(0xFF1E40AF),
  TaskStatus.awaitingReply  => const Color(0xFF92400E),
  TaskStatus.readyForReview => const Color(0xFF5B21B6),
  TaskStatus.approved       => const Color(0xFF065F46),
  TaskStatus.sentToClient   => const Color(0xFFB45309),
  TaskStatus.confirmed      => const Color(0xFF065F46),
  TaskStatus.cancelled      => const Color(0xFF9CA3AF),
};
