import '../../../data/models/user_model.dart';
import 'next_action_model.dart';

// =============================================================================
// NextActionPriorityHelper
//
// Sorts NextActions by:
//   1. Priority — NextActionPriority enum order is urgent(0) → low(3),
//      so ascending index = highest priority first.
//   2. Role relevance within the same tier — actions matching the current
//      role surface before generic ones.
// =============================================================================

abstract class NextActionPriorityHelper {
  static List<NextAction> sort(List<NextAction> actions, {AppRole? role}) {
    return List<NextAction>.from(actions)
      ..sort((a, b) {
        // Primary: lower enum index = higher priority
        final cmp = a.priority.index.compareTo(b.priority.index);
        if (cmp != 0) return cmp;

        // Secondary: role-relevant actions surface first within a tier
        if (role != null) {
          final ra = _isRelevant(a, role) ? 0 : 1; // relevant = 0 (sorts first)
          final rb = _isRelevant(b, role) ? 0 : 1;
          if (ra != rb) return ra.compareTo(rb);
        }
        return 0;
      });
  }

  static bool _isRelevant(NextAction action, AppRole role) =>
      action.relevantRoles.isEmpty || action.relevantRoles.contains(role);
}
