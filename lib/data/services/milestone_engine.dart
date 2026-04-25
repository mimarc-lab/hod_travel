import '../models/cost_item_model.dart';
import '../models/itinerary_models.dart';
import '../models/milestone_status.dart';
import '../models/run_sheet_item.dart';
import '../models/task_model.dart';
import '../models/trip_component_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MilestoneEngine
//
// Evaluates the five standard HOD trip milestones from existing data.
// All rules are pure functions — no DB calls, no side effects.
// ─────────────────────────────────────────────────────────────────────────────

class MilestoneEngine {
  const MilestoneEngine._();

  static List<MilestoneStatus> evaluate({
    required List<Task> tasks,
    required List<TripComponent> components,
    required List<TripDay> days,
    required Map<String, List<ItineraryItem>> itemsByDayId,
    required List<CostItem> costItems,
    required List<RunSheetRow> runSheetRows,
  }) {
    return [
      _intakeComplete(tasks),
      _sourcingComplete(components),
      _proposalReady(days, itemsByDayId, costItems),
      _finalPresentationApproved(tasks),
      _opsHandoffComplete(components, runSheetRows),
    ];
  }

  // ── 1. Intake Complete ──────────────────────────────────────────────────────
  static MilestoneStatus _intakeComplete(List<Task> tasks) {
    final pending = <String>[];

    final intakeTasks = tasks.where((t) =>
        t.name.toLowerCase().contains('intake') ||
        t.name.toLowerCase().contains('questionnaire') ||
        (t.category?.toLowerCase().contains('intake') ?? false)).toList();

    if (intakeTasks.isEmpty) {
      pending.add('Create and complete an intake / questionnaire task');
    } else {
      final done = intakeTasks.any(_isTaskComplete);
      if (!done) pending.add('Complete the intake task');
    }

    return MilestoneStatus(
      id:               MilestoneId.intakeComplete,
      completion:       pending.isEmpty
          ? MilestoneCompletion.complete
          : MilestoneCompletion.pending,
      pendingCriteria:  pending,
    );
  }

  // ── 2. Sourcing Complete ────────────────────────────────────────────────────
  static MilestoneStatus _sourcingComplete(List<TripComponent> components) {
    final pending = <String>[];

    final hasAccom    = components.any((c) => c.componentType == ComponentType.accommodation);
    final accomOk     = components.any((c) =>
        c.componentType == ComponentType.accommodation && _isCompApproved(c));
    final hasExp      = components.any((c) => c.componentType == ComponentType.experience);
    final expOk       = components.any((c) =>
        c.componentType == ComponentType.experience && _isCompApproved(c));

    if (!hasAccom)       pending.add('Add at least one accommodation component');
    else if (!accomOk)   pending.add('Approve accommodation component(s)');
    if (!hasExp)         pending.add('Add at least one experience component');
    else if (!expOk)     pending.add('Approve experience component(s)');

    return MilestoneStatus(
      id:              MilestoneId.sourcingComplete,
      completion:      pending.isEmpty
          ? MilestoneCompletion.complete
          : MilestoneCompletion.pending,
      pendingCriteria: pending,
    );
  }

  // ── 3. Proposal Ready ───────────────────────────────────────────────────────
  static MilestoneStatus _proposalReady(
    List<TripDay> days,
    Map<String, List<ItineraryItem>> itemsByDayId,
    List<CostItem> costItems,
  ) {
    final pending = <String>[];

    final hasItinerary = days.isNotEmpty &&
        days.any((d) => (itemsByDayId[d.id] ?? []).isNotEmpty);
    final hasPricing   = costItems.isNotEmpty;

    if (!hasItinerary) pending.add('Build itinerary with at least one scheduled item');
    if (!hasPricing)   pending.add('Add budget / pricing items');

    return MilestoneStatus(
      id:              MilestoneId.proposalReady,
      completion:      pending.isEmpty
          ? MilestoneCompletion.complete
          : MilestoneCompletion.pending,
      pendingCriteria: pending,
    );
  }

  // ── 4. Final Presentation Approved ─────────────────────────────────────────
  static MilestoneStatus _finalPresentationApproved(List<Task> tasks) {
    final pending = <String>[];

    bool _isPresTask(Task t) =>
        t.name.toLowerCase().contains('proposal') ||
        t.name.toLowerCase().contains('presentation') ||
        t.name.toLowerCase().contains('client approval');

    final presTask = tasks.any(_isPresTask);
    final approved = tasks.any((t) =>
        _isPresTask(t) &&
        (t.status == TaskStatus.sentToClient ||
         t.status == TaskStatus.approved ||
         t.status == TaskStatus.confirmed));

    if (!presTask)    pending.add('Create a proposal / presentation task');
    else if (!approved) pending.add('Get client approval on the final presentation');

    return MilestoneStatus(
      id:              MilestoneId.finalPresentationApproved,
      completion:      pending.isEmpty
          ? MilestoneCompletion.complete
          : MilestoneCompletion.pending,
      pendingCriteria: pending,
    );
  }

  // ── 5. Ops Handoff Complete ─────────────────────────────────────────────────
  static MilestoneStatus _opsHandoffComplete(
    List<TripComponent> components,
    List<RunSheetRow> runSheetRows,
  ) {
    final pending = <String>[];

    final active = components.where((c) => c.status != ComponentStatus.cancelled).toList();
    final allConfirmed = active.isNotEmpty &&
        active.every((c) =>
            c.status == ComponentStatus.confirmed ||
            c.status == ComponentStatus.booked);
    final hasRunSheet = runSheetRows.isNotEmpty;

    if (active.isEmpty) {
      pending.add('Add trip components');
    } else if (!allConfirmed) {
      final n = active.where((c) =>
          c.status != ComponentStatus.confirmed &&
          c.status != ComponentStatus.booked).length;
      pending.add('$n component(s) not yet confirmed or booked');
    }
    if (!hasRunSheet) pending.add('Create run sheet items for operational execution');

    return MilestoneStatus(
      id:              MilestoneId.opsHandoffComplete,
      completion:      pending.isEmpty
          ? MilestoneCompletion.complete
          : pending.length > 1
              ? MilestoneCompletion.atRisk
              : MilestoneCompletion.pending,
      pendingCriteria: pending,
    );
  }

  static bool _isTaskComplete(Task t) =>
      t.status == TaskStatus.approved ||
      t.status == TaskStatus.confirmed ||
      t.status == TaskStatus.sentToClient;

  static bool _isCompApproved(TripComponent c) =>
      c.status == ComponentStatus.approved ||
      c.status == ComponentStatus.confirmed ||
      c.status == ComponentStatus.booked;
}
