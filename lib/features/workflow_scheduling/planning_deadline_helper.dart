// Pure helper — no Flutter or Supabase dependencies.
// All date math for the backward planning engine.

class PlanningDeadlineHelper {
  static const int defaultBufferDays = 7;

  // Planning must complete this many days before the trip starts.
  static DateTime computeDeadline(DateTime tripStartDate, int bufferDays) {
    final d = tripStartDate.subtract(Duration(days: bufferDays));
    return DateTime(d.year, d.month, d.day);
  }

  // Days available from today to the planning deadline (inclusive).
  static int availableDays(DateTime deadline) {
    final today = planningStart();
    if (deadline.isBefore(today)) return 0;
    return deadline.difference(today).inDays + 1;
  }

  // Today at midnight — the earliest a task can be scheduled to start.
  static DateTime planningStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String formatDeadline(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }
}
