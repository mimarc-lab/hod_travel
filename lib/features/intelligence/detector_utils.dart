/// Shared constants and helpers used across all intelligence detectors.
/// Keep this file small — only things used by two or more detectors belong here.
library;

import '../../data/models/task_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared keyword sets
// Defined once here so MissingTaskDetector and BudgetGapDetector never drift.
// ─────────────────────────────────────────────────────────────────────────────

const kAccommodationKeywords = [
  'accommodation', 'hotel', 'villa', 'lodge', 'resort', 'camp',
];

// ─────────────────────────────────────────────────────────────────────────────
// Task status predicates
// ─────────────────────────────────────────────────────────────────────────────

/// Terminal: task is done or cancelled — exclude from overdue / urgency checks.
bool isTerminalStatus(TaskStatus s) =>
    s == TaskStatus.confirmed ||
    s == TaskStatus.approved ||
    s == TaskStatus.cancelled;

/// Complete: task counts toward the completion rate in readiness scoring.
/// Broader than terminal — includes sentToClient.
bool isCompleteStatus(TaskStatus s) =>
    s == TaskStatus.approved ||
    s == TaskStatus.confirmed ||
    s == TaskStatus.sentToClient;

// ─────────────────────────────────────────────────────────────────────────────
// Task classification helpers
// ─────────────────────────────────────────────────────────────────────────────

/// True if the task name or category matches any accommodation keyword.
bool isAccommodationTask(Task t) {
  final name = t.name.toLowerCase();
  final cat  = t.category?.toLowerCase() ?? '';
  return kAccommodationKeywords.any((k) => name.contains(k) || cat.contains(k));
}

// ─────────────────────────────────────────────────────────────────────────────
// Pluralisation helpers
// Centralised here to eliminate the repeated `${n > 1 ? 's' : ''}` pattern.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `singular` when [n] == 1, otherwise [plural] (defaults to `${singular}s`).
String pl(int n, String singular, [String? plural]) =>
    n == 1 ? singular : (plural ?? '${singular}s');

/// "1 task" / "3 tasks"
String nOf(int n, String noun, [String? plural]) =>
    '$n ${pl(n, noun, plural)}';

/// "task is" / "tasks are"
String nAre(int n, String noun, [String? plural]) =>
    '${nOf(n, noun, plural)} ${n == 1 ? 'is' : 'are'}';
