import '../models/task_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CriticalPathEngine
//
// Identifies tasks on the critical path and computes an overall status.
// A task is critical when it:
//   • has high priority, OR
//   • belongs to a critical category (pre-planning, accommodation,
//     client delivery, finalization)
//
// Status:
//   atRisk  — any critical task is overdue
//   watch   — any critical task is due within 3 days
//   healthy — no critical task issues
// ─────────────────────────────────────────────────────────────────────────────

enum CriticalPathStatus { healthy, watch, atRisk }

class CriticalTask {
  final Task   task;
  final String reason;
  final bool   isOverdue;
  final bool   isDueSoon;

  const CriticalTask({
    required this.task,
    required this.reason,
    required this.isOverdue,
    required this.isDueSoon,
  });
}

class CriticalPathResult {
  final List<CriticalTask> criticalTasks;
  final CriticalPathStatus status;

  const CriticalPathResult({
    required this.criticalTasks,
    required this.status,
  });

  static const CriticalPathResult healthy = CriticalPathResult(
    criticalTasks: [],
    status:        CriticalPathStatus.healthy,
  );
}

class CriticalPathEngine {
  const CriticalPathEngine._();

  static const _criticalCategories = [
    'pre-planning', 'pre planning', 'preplanning',
    'accommodation',
    'client delivery', 'client',
    'finalization', 'finalisation', 'final',
  ];

  static CriticalPathResult evaluate(List<Task> tasks) {
    final now  = DateTime.now();
    final soon = now.add(const Duration(days: 3));

    final critical = <CriticalTask>[];

    for (final task in tasks) {
      if (task.status == TaskStatus.cancelled) continue;
      if (!_isCritical(task)) continue;

      final completed = _isCompleted(task);
      final overdue   = !completed &&
          task.dueDate != null && task.dueDate!.isBefore(now);
      final dueSoon   = !completed && !overdue &&
          task.dueDate != null && task.dueDate!.isBefore(soon);

      // Only surface tasks that need attention or are high priority
      if (overdue || dueSoon || task.priority == TaskPriority.high) {
        critical.add(CriticalTask(
          task:      task,
          reason:    _reason(task),
          isOverdue: overdue,
          isDueSoon: dueSoon,
        ));
      }
    }

    // Overdue first, then due-soon, then others
    critical.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      if (a.isDueSoon != b.isDueSoon) return a.isDueSoon ? -1 : 1;
      return 0;
    });

    return CriticalPathResult(
      criticalTasks: critical,
      status:        _status(critical),
    );
  }

  static bool _isCritical(Task task) {
    if (task.priority == TaskPriority.high) return true;
    final cat  = task.category?.toLowerCase() ?? '';
    final name = task.name.toLowerCase();
    return _criticalCategories.any((c) => cat.contains(c) || name.contains(c));
  }

  static bool _isCompleted(Task task) =>
      task.status == TaskStatus.approved ||
      task.status == TaskStatus.confirmed ||
      task.status == TaskStatus.sentToClient;

  static String _reason(Task task) {
    if (task.priority == TaskPriority.high) return 'High priority';
    final cat = task.category?.toLowerCase() ?? '';
    if (cat.contains('accommodation')) return 'Accommodation';
    if (cat.contains('client'))        return 'Client delivery';
    if (cat.contains('final'))         return 'Finalization';
    if (cat.contains('pre'))           return 'Pre-planning';
    return 'Critical category';
  }

  static CriticalPathStatus _status(List<CriticalTask> tasks) {
    if (tasks.any((t) => t.isOverdue)) return CriticalPathStatus.atRisk;
    if (tasks.any((t) => t.isDueSoon)) return CriticalPathStatus.watch;
    return CriticalPathStatus.healthy;
  }
}
