import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/task_model.dart';
import '../../data/models/trip_model.dart';

/// Chip showing a task status with appropriate background/text colors.
class TaskStatusChip extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return _Chip(label: status.label, bg: bg, fg: fg);
  }

  static (Color bg, Color fg) _colors(TaskStatus s) {
    switch (s) {
      case TaskStatus.notStarted:     return (AppColors.statusNotStarted,  AppColors.statusNotStartedText);
      case TaskStatus.researching:    return (AppColors.statusInProgress,   AppColors.statusInProgressText);
      case TaskStatus.awaitingReply:  return (AppColors.statusWaiting,      AppColors.statusWaitingText);
      case TaskStatus.readyForReview: return (const Color(0xFFFEF3C7),      const Color(0xFF92400E));
      case TaskStatus.approved:       return (AppColors.statusDone,         AppColors.statusDoneText);
      case TaskStatus.sentToClient:   return (const Color(0xFFE0F2FE),      const Color(0xFF0369A1));
      case TaskStatus.confirmed:      return (AppColors.statusDone,         AppColors.statusDoneText);
      case TaskStatus.cancelled:      return (AppColors.statusBlocked,      AppColors.statusBlockedText);
    }
  }
}

/// Chip showing a trip status.
class TripStatusChip extends StatelessWidget {
  final TripStatus status;

  const TripStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return _Chip(label: status.label, bg: bg, fg: fg);
  }

  static (Color bg, Color fg) _colors(TripStatus s) {
    switch (s) {
      case TripStatus.planning:    return (AppColors.statusNotStarted,  AppColors.statusNotStartedText);
      case TripStatus.confirmed:   return (AppColors.statusInProgress,  AppColors.statusInProgressText);
      case TripStatus.inProgress:  return (AppColors.statusDone,        AppColors.statusDoneText);
      case TripStatus.completed:   return (const Color(0xFFF3F4F6),     const Color(0xFF6B7280));
      case TripStatus.cancelled:   return (AppColors.statusBlocked,     AppColors.statusBlockedText);
    }
  }
}

/// Chip showing task priority.
class PriorityChip extends StatelessWidget {
  final TaskPriority priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(priority);
    return _Chip(label: priority.label, bg: bg, fg: fg);
  }

  static (Color bg, Color fg) _colors(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:    return (AppColors.priorityLow,    AppColors.priorityLowText);
      case TaskPriority.medium: return (AppColors.priorityMedium, AppColors.priorityMediumText);
      case TaskPriority.high:   return (AppColors.priorityHigh,   AppColors.priorityHighText);
    }
  }
}

/// Chip showing cost status.
class CostStatusChip extends StatelessWidget {
  final TaskCostStatus status;

  const CostStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return _Chip(label: status.label, bg: bg, fg: fg);
  }

  static (Color bg, Color fg) _colors(TaskCostStatus s) {
    switch (s) {
      case TaskCostStatus.pending:  return (AppColors.costNotCosted,  AppColors.costNotCostedText);
      case TaskCostStatus.quoted:   return (AppColors.costEstimated,  AppColors.costEstimatedText);
      case TaskCostStatus.approved: return (AppColors.costConfirmed,  AppColors.costConfirmedText);
      case TaskCostStatus.paid:     return (AppColors.costInvoiced,   AppColors.costInvoicedText);
    }
  }
}

// ── Internal chip widget ─────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
