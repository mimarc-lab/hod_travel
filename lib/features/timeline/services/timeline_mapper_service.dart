import '../../../data/models/task_model.dart';
import '../../../data/models/trip_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Width in pixels that one calendar day occupies on the timeline.
const double kDayWidth = 44.0;

/// Height of a single task row.
const double kRowHeight = 40.0;

/// Height of a board-group section header row.
const double kGroupHeaderHeight = 36.0;

/// Height of the date scale header (month row + day row).
const double kHeaderHeight = 56.0;

// ─────────────────────────────────────────────────────────────────────────────
// TimelineDateRange
// ─────────────────────────────────────────────────────────────────────────────

class TimelineDateRange {
  final DateTime start; // inclusive, always 00:00:00 local
  final DateTime end;   // inclusive, always 00:00:00 local

  const TimelineDateRange({required this.start, required this.end});

  int get totalDays => end.difference(start).inDays + 1;
  double get totalWidth => totalDays * kDayWidth;

  /// Pixel offset from the left edge of the timeline to [date].
  double offsetForDate(DateTime date) {
    final d = _dateOnly(date);
    return d.difference(start).inDays * kDayWidth;
  }

  /// Calendar date at a given pixel offset (used when dragging).
  DateTime dateAtOffset(double offset) {
    final days = (offset / kDayWidth).floor().clamp(0, totalDays - 1);
    return start.add(Duration(days: days));
  }

  /// True if [date] falls within this range.
  bool contains(DateTime date) {
    final d = _dateOnly(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BarMetrics
// ─────────────────────────────────────────────────────────────────────────────

class BarMetrics {
  /// Left offset in pixels from the start of the timeline canvas.
  final double left;

  /// Width in pixels (minimum one day-width).
  final double width;

  /// True when only one anchor date was available (single-day pin).
  final bool isSingleDay;

  const BarMetrics({
    required this.left,
    required this.width,
    this.isSingleDay = false,
  });

  double get right => left + width;
}

// ─────────────────────────────────────────────────────────────────────────────
// TimelineRow — sealed row model used by TimelineScreen
// ─────────────────────────────────────────────────────────────────────────────

sealed class TimelineRow {
  double get height;
}

class GroupHeaderRow extends TimelineRow {
  final String groupId;
  final String groupName;
  final int taskCount;

  GroupHeaderRow({
    required this.groupId,
    required this.groupName,
    required this.taskCount,
  });

  @override
  double get height => kGroupHeaderHeight;
}

class TaskRow extends TimelineRow {
  final Task task;
  final BarMetrics? bar; // null = unscheduled

  TaskRow({required this.task, required this.bar});

  @override
  double get height => kRowHeight;
}

// ─────────────────────────────────────────────────────────────────────────────
// TimelineMapperService — pure, stateless computation
// ─────────────────────────────────────────────────────────────────────────────

abstract class TimelineMapperService {
  // ── Date range ─────────────────────────────────────────────────────────────

  static TimelineDateRange computeDateRange(List<Task> tasks, Trip trip) {
    final dates = <DateTime>[];

    for (final t in tasks) {
      if (t.travelDate != null) dates.add(_dateOnly(t.travelDate!));
      if (t.dueDate    != null) dates.add(_dateOnly(t.dueDate!));
    }
    if (trip.startDate != null) dates.add(_dateOnly(trip.startDate!));
    if (trip.endDate   != null) dates.add(_dateOnly(trip.endDate!));

    final today = _dateOnly(DateTime.now());
    dates.add(today); // always include today so the today-line is always visible

    dates.sort();

    final rangeStart = dates.first.subtract(const Duration(days: 7));
    final rangeEnd   = dates.last.add(const Duration(days: 14));

    return TimelineDateRange(start: rangeStart, end: rangeEnd);
  }

  // ── Bar metrics ─────────────────────────────────────────────────────────────

  /// Returns null for fully unscheduled tasks (no dates at all).
  static BarMetrics? computeBar(Task task, TimelineDateRange range) {
    final d1 = task.travelDate != null ? _dateOnly(task.travelDate!) : null;
    final d2 = task.dueDate    != null ? _dateOnly(task.dueDate!)    : null;

    if (d1 == null && d2 == null) return null;

    // If both present span d1 → d2 (regardless of which is earlier).
    // In practice dueDate <= travelDate for ops tasks, but be defensive.
    final effectiveStart = _earliest(d1, d2)!;
    final effectiveEnd   = _latest(d1, d2)!;
    final isSingleDay    = effectiveStart == effectiveEnd || (d1 == null || d2 == null);

    final left  = range.offsetForDate(effectiveStart);
    final right = range.offsetForDate(effectiveEnd) + kDayWidth;
    final width = (right - left).clamp(kDayWidth, double.infinity);

    return BarMetrics(left: left, width: width, isSingleDay: isSingleDay);
  }

  // ── Overdue ────────────────────────────────────────────────────────────────

  static bool isOverdue(Task task) {
    final due = task.dueDate;
    if (due == null) return false;
    // Terminal statuses are never "overdue" — work is complete
    if (task.status == TaskStatus.confirmed ||
        task.status == TaskStatus.approved  ||
        task.status == TaskStatus.cancelled) { return false; }
    return _dateOnly(due).isBefore(_dateOnly(DateTime.now()));
  }

  // ── Row list ───────────────────────────────────────────────────────────────

  /// Builds the flat row list shown in the timeline, optionally grouped.
  static List<TimelineRow> buildRows({
    required List<({String id, String name, List<Task> tasks})> groups,
    required TimelineDateRange range,
    required bool grouped,
    required String? filterUserId,
    required bool overdueOnly,
  }) {
    final rows = <TimelineRow>[];

    for (final g in groups) {
      // Apply filter within group
      var tasks = g.tasks.where((t) {
        if (filterUserId != null && t.assignedTo?.id != filterUserId) return false;
        if (overdueOnly && !isOverdue(t)) return false;
        return true;
      }).toList();

      if (tasks.isEmpty) continue;

      if (grouped) {
        rows.add(GroupHeaderRow(
          groupId:   g.id,
          groupName: g.name,
          taskCount: tasks.length,
        ));
      }

      for (final t in tasks) {
        rows.add(TaskRow(task: t, bar: computeBar(t, range)));
      }
    }

    return rows;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static double totalBodyHeight(List<TimelineRow> rows) =>
      rows.fold(0.0, (acc, r) => acc + r.height);
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

DateTime? _earliest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
