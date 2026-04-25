import '../models/cost_item_model.dart';
import '../models/itinerary_models.dart';
import '../models/run_sheet_item.dart';
import '../models/task_model.dart';
import '../models/trip_component_model.dart';
import '../models/trip_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExceptionEngine
//
// Centralised exception detection. Runs all rules across tasks, components,
// budget items, and run sheet rows for a single trip.
// Returns a list sorted by severity (high → medium → low).
// ─────────────────────────────────────────────────────────────────────────────

class ExceptionEngine {
  const ExceptionEngine._();

  static List<TripException> detect({
    required List<Task> tasks,
    required List<TripComponent> components,
    required List<CostItem> costItems,
    required Map<String, List<ItineraryItem>> itemsByDayId,
    required List<RunSheetRow> runSheetRows,
  }) {
    final out = <TripException>[];
    final now     = DateTime.now();
    final in3Days = now.add(const Duration(days: 3));

    // ── Task exceptions ───────────────────────────────────────────────────────

    for (final task in tasks) {
      if (task.status == TaskStatus.cancelled) continue;

      // No assignee
      if (task.assignedTo == null) {
        out.add(TripException(
          id:                  'task_no_assignee_${task.id}',
          type:                TripExceptionType.task,
          severity:            TripExceptionSeverity.medium,
          message:             '"${task.name}" has no assignee.',
          relatedEntityName:   task.name,
          relatedEntityId:     task.id,
          suggestedAction:     'Assign a team member to this task.',
          actionType:          TripExceptionAction.assignTask,
        ));
      }

      // Overdue
      if (task.dueDate != null &&
          task.dueDate!.isBefore(now) &&
          !_isTaskTerminal(task)) {
        out.add(TripException(
          id:                'task_overdue_${task.id}',
          type:              TripExceptionType.task,
          severity:          task.priority == TaskPriority.high
              ? TripExceptionSeverity.high
              : TripExceptionSeverity.medium,
          message:           '"${task.name}" is overdue.',
          relatedEntityName: task.name,
          relatedEntityId:   task.id,
          suggestedAction:   'Complete or reschedule this task.',
          actionType:        TripExceptionAction.markComplete,
        ));
      }
    }

    // ── Component exceptions ──────────────────────────────────────────────────

    final active = components.where((c) =>
        c.status == ComponentStatus.confirmed ||
        c.status == ComponentStatus.booked).toList();

    for (final c in active) {
      final statusLabel = c.status.label.toLowerCase();

      // Missing confirmation number
      if (c.confirmationNumber == null || c.confirmationNumber!.trim().isEmpty) {
        out.add(TripException(
          id:                'comp_no_confirm_${c.id}',
          type:              TripExceptionType.component,
          severity:          TripExceptionSeverity.medium,
          message:           '"${c.title}" is $statusLabel but has no confirmation number.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Add the supplier confirmation number.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // Missing supplier link
      if (c.supplierId == null) {
        out.add(TripException(
          id:                'comp_no_supplier_${c.id}',
          type:              TripExceptionType.component,
          severity:          TripExceptionSeverity.medium,
          message:           '"${c.title}" is $statusLabel but has no linked supplier.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Link this component to a supplier.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // Transport-specific
      if (c.componentType == ComponentType.transport) {
        if (c.startTime == null) {
          out.add(TripException(
            id:                'comp_transport_no_time_${c.id}',
            type:              TripExceptionType.component,
            severity:          TripExceptionSeverity.high,
            message:           '"${c.title}" is $statusLabel transport with no departure time.',
            relatedEntityName: c.title,
            relatedEntityId:   c.id,
            suggestedAction:   'Add departure time.',
            actionType:        TripExceptionAction.addMissingData,
          ));
        }
        if (c.locationName == null && c.address == null) {
          out.add(TripException(
            id:                'comp_transport_no_loc_${c.id}',
            type:              TripExceptionType.component,
            severity:          TripExceptionSeverity.high,
            message:           '"${c.title}" is $statusLabel transport with no pickup location.',
            relatedEntityName: c.title,
            relatedEntityId:   c.id,
            suggestedAction:   'Add pickup and dropoff location details.',
            actionType:        TripExceptionAction.addMissingData,
          ));
        }
      }

      // Accommodation: missing property address
      if (c.componentType == ComponentType.accommodation &&
          c.locationName == null && c.address == null) {
        out.add(TripException(
          id:                'comp_accom_no_address_${c.id}',
          type:              TripExceptionType.component,
          severity:          TripExceptionSeverity.medium,
          message:           '"${c.title}" is $statusLabel accommodation with no property address.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Add property name and address.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // Dining: missing party size
      if (c.componentType == ComponentType.dining &&
          c.detailsJson['party_size'] == null) {
        out.add(TripException(
          id:                'comp_dining_no_party_${c.id}',
          type:              TripExceptionType.component,
          severity:          TripExceptionSeverity.low,
          message:           '"${c.title}" is a $statusLabel restaurant with no party size.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Add the party size for this restaurant booking.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // Guide: missing contact details
      if (c.componentType == ComponentType.guide &&
          c.primaryContactName == null &&
          c.supplierContactOverrideName == null) {
        out.add(TripException(
          id:                'comp_guide_no_contact_${c.id}',
          type:              TripExceptionType.component,
          severity:          TripExceptionSeverity.high,
          message:           '"${c.title}" is a $statusLabel guide with no contact details.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Add primary contact name and phone.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // ── Linking exceptions ────────────────────────────────────────────────

      if (c.itineraryItemId == null) {
        out.add(TripException(
          id:                'link_no_itinerary_${c.id}',
          type:              TripExceptionType.dataIntegrity,
          severity:          TripExceptionSeverity.medium,
          message:           '"${c.title}" is $statusLabel but not linked to the itinerary.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Link this component to an itinerary item.',
          actionType:        TripExceptionAction.linkComponent,
        ));
      }

      if (c.costItemId == null) {
        out.add(TripException(
          id:                'link_no_budget_${c.id}',
          type:              TripExceptionType.dataIntegrity,
          severity:          TripExceptionSeverity.medium,
          message:           '"${c.title}" is $statusLabel but not linked to the budget.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Link this component to a budget item.',
          actionType:        TripExceptionAction.linkComponent,
        ));
      }

      if (c.runSheetItemId == null) {
        out.add(TripException(
          id:                'link_no_runsheet_${c.id}',
          type:              TripExceptionType.dataIntegrity,
          severity:          TripExceptionSeverity.low,
          message:           '"${c.title}" is $statusLabel but not linked to the run sheet.',
          relatedEntityName: c.title,
          relatedEntityId:   c.id,
          suggestedAction:   'Link this component to the run sheet.',
          actionType:        TripExceptionAction.linkComponent,
        ));
      }
    }

    // ── Data integrity: itinerary items with no component link ────────────────
    // Build set of itineraryItemIds used by components
    final linkedItinIds = {
      for (final c in components)
        if (c.itineraryItemId != null) c.itineraryItemId!,
    };
    for (final items in itemsByDayId.values) {
      for (final item in items) {
        if (!linkedItinIds.contains(item.id)) {
          out.add(TripException(
            id:                'integrity_itin_no_comp_${item.id}',
            type:              TripExceptionType.dataIntegrity,
            severity:          TripExceptionSeverity.low,
            message:           'Itinerary item "${item.title}" is not linked to any component.',
            relatedEntityName: item.title,
            relatedEntityId:   item.id,
            suggestedAction:   'Link this itinerary item to the corresponding component.',
            actionType:        TripExceptionAction.linkComponent,
          ));
        }
      }
    }

    // ── Financial exceptions ──────────────────────────────────────────────────

    for (final cost in costItems) {
      // Deposit due within 3 days
      if (cost.paymentDueDate != null &&
          cost.paymentStatus == PaymentStatus.pending &&
          cost.paymentDueDate!.isAfter(now) &&
          cost.paymentDueDate!.isBefore(in3Days)) {
        final daysLeft = cost.paymentDueDate!.difference(now).inDays + 1;
        out.add(TripException(
          id:                'fin_due_soon_${cost.id}',
          type:              TripExceptionType.financial,
          severity:          TripExceptionSeverity.high,
          message:           '"${cost.itemName}" payment due in $daysLeft day(s).',
          relatedEntityName: cost.itemName,
          relatedEntityId:   cost.id,
          suggestedAction:   'Process payment or update payment status.',
          actionType:        TripExceptionAction.addMissingData,
        ));
      }

      // Unpaid balance past due
      if (cost.paymentDueDate != null &&
          cost.paymentStatus != PaymentStatus.paid &&
          cost.paymentStatus != PaymentStatus.cancelled &&
          cost.paymentDueDate!.isBefore(now)) {
        out.add(TripException(
          id:                'fin_overdue_${cost.id}',
          type:              TripExceptionType.financial,
          severity:          TripExceptionSeverity.high,
          message:           '"${cost.itemName}" has an unpaid balance that is past due.',
          relatedEntityName: cost.itemName,
          relatedEntityId:   cost.id,
          suggestedAction:   'Process overdue payment immediately.',
          actionType:        TripExceptionAction.escalate,
        ));
      }
    }

    // ── Supplier response delay ───────────────────────────────────────────────
    for (final task in tasks) {
      if (task.status == TaskStatus.awaitingReply &&
          task.dueDate != null &&
          task.dueDate!.isBefore(now)) {
        out.add(TripException(
          id:                'supplier_delay_${task.id}',
          type:              TripExceptionType.supplier,
          severity:          TripExceptionSeverity.medium,
          message:           '"${task.name}" is awaiting a supplier reply and is overdue.',
          relatedEntityName: task.name,
          relatedEntityId:   task.id,
          suggestedAction:   'Follow up with the supplier or escalate.',
          actionType:        TripExceptionAction.escalate,
        ));
      }
    }

    // Sort: high → medium → low, then stable within each bucket
    out.sort((a, b) => _severityRank(b.severity) - _severityRank(a.severity));
    return out;
  }

  static int _severityRank(TripExceptionSeverity s) => switch (s) {
    TripExceptionSeverity.high   => 3,
    TripExceptionSeverity.medium => 2,
    TripExceptionSeverity.low    => 1,
  };

  static bool _isTaskTerminal(Task t) =>
      t.status == TaskStatus.approved ||
      t.status == TaskStatus.confirmed ||
      t.status == TaskStatus.cancelled;
}
