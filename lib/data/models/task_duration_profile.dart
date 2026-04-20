/// Fallback base durations (days) by board group name.
///
/// Used by [DurationCalculator] only when the template task carries
/// an unreliable stored value (≤ 1 day — the legacy DEFAULT 1 bug).
/// For well-formed templates the stored [estimatedDurationDays] is used directly.
class TaskDurationProfile {
  static const _groupDefaults = <String, int>{
    'Pre-Planning':    2,
    'Accommodation':   4,
    'Experiences':     3,
    'Dining':          2,
    'Logistics':       2,
    'Finance':         2,
    'Client Delivery': 3,
    'Finalization':    2,
  };

  /// Returns the base duration to use for scheduling.
  ///
  /// If [storedDuration] > 1 it is treated as intentional and returned as-is.
  /// Otherwise the group default (minimum 2 days) is returned so that tasks
  /// created before the duration-fix migration still schedule realistically.
  static int baseDaysFor(String groupName, int storedDuration) {
    if (storedDuration > 1) return storedDuration;
    return _groupDefaults[groupName] ?? 2;
  }
}
