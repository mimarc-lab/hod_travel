import 'approval_model.dart';
import 'user_model.dart';

// DB values: not_started | researching | awaiting_reply | ready_for_review |
//            approved | sent_to_client | confirmed | cancelled
enum TaskStatus {
  notStarted,
  researching,
  awaitingReply,
  readyForReview,
  approved,
  sentToClient,
  confirmed,
  cancelled,
}

// DB values: pending | quoted | approved | paid
enum TaskCostStatus { pending, quoted, approved, paid }

enum TaskPriority { low, medium, high }

extension TaskStatusLabel on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.notStarted:    return 'Not Started';
      case TaskStatus.researching:   return 'Researching';
      case TaskStatus.awaitingReply: return 'Awaiting Reply';
      case TaskStatus.readyForReview:return 'Ready for Review';
      case TaskStatus.approved:      return 'Approved';
      case TaskStatus.sentToClient:  return 'Sent to Client';
      case TaskStatus.confirmed:     return 'Confirmed';
      case TaskStatus.cancelled:     return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case TaskStatus.notStarted:    return 'not_started';
      case TaskStatus.researching:   return 'researching';
      case TaskStatus.awaitingReply: return 'awaiting_reply';
      case TaskStatus.readyForReview:return 'ready_for_review';
      case TaskStatus.approved:      return 'approved';
      case TaskStatus.sentToClient:  return 'sent_to_client';
      case TaskStatus.confirmed:     return 'confirmed';
      case TaskStatus.cancelled:     return 'cancelled';
    }
  }

  static TaskStatus fromDb(String raw) => switch (raw) {
    'researching'    => TaskStatus.researching,
    'awaiting_reply' => TaskStatus.awaitingReply,
    'ready_for_review'=> TaskStatus.readyForReview,
    'approved'       => TaskStatus.approved,
    'sent_to_client' => TaskStatus.sentToClient,
    'confirmed'      => TaskStatus.confirmed,
    'cancelled'      => TaskStatus.cancelled,
    _                => TaskStatus.notStarted,
  };
}

extension TaskCostStatusLabel on TaskCostStatus {
  String get label {
    switch (this) {
      case TaskCostStatus.pending:  return 'Pending';
      case TaskCostStatus.quoted:   return 'Quoted';
      case TaskCostStatus.approved: return 'Approved';
      case TaskCostStatus.paid:     return 'Paid';
    }
  }

  String get dbValue {
    switch (this) {
      case TaskCostStatus.pending:  return 'pending';
      case TaskCostStatus.quoted:   return 'quoted';
      case TaskCostStatus.approved: return 'approved';
      case TaskCostStatus.paid:     return 'paid';
    }
  }

  static TaskCostStatus fromDb(String raw) => switch (raw) {
    'quoted'   => TaskCostStatus.quoted,
    'approved' => TaskCostStatus.approved,
    'paid'     => TaskCostStatus.paid,
    _          => TaskCostStatus.pending,
  };
}

extension TaskPriorityLabel on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:    return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high:   return 'High';
    }
  }

  String get dbValue {
    switch (this) {
      case TaskPriority.low:    return 'low';
      case TaskPriority.medium: return 'medium';
      case TaskPriority.high:   return 'high';
    }
  }

  static TaskPriority fromDb(String raw) => switch (raw) {
    'low'  => TaskPriority.low,
    'high' => TaskPriority.high,
    _      => TaskPriority.medium,
  };
}

class Task {
  final String id;
  final String? tripId;
  final String? teamId;
  final String boardGroupId;
  final String name;           // maps to DB column: title
  final String? description;
  final String? category;
  final TaskStatus status;
  final TaskPriority priority;
  final TaskCostStatus costStatus;
  final AppUser? assignedTo;
  final String? destination;   // maps to DB column: destination_city
  final DateTime? travelDate;
  final DateTime? dueDate;
  final String? supplierId;    // FK → suppliers.id
  final bool clientVisible;
  final ApprovalStatus approvalStatus;

  const Task({
    required this.id,
    this.tripId,
    this.teamId,
    required this.boardGroupId,
    required this.name,
    required this.status,
    required this.priority,
    required this.costStatus,
    this.description,
    this.category,
    this.assignedTo,
    this.destination,
    this.travelDate,
    this.dueDate,
    this.supplierId,
    this.clientVisible = false,
    this.approvalStatus = ApprovalStatus.draft,
  });

  Task copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    String? category,
    bool clearCategory = false,
    TaskStatus? status,
    TaskPriority? priority,
    TaskCostStatus? costStatus,
    AppUser? assignedTo,
    bool clearAssignedTo = false,
    String? destination,
    bool clearDestination = false,
    DateTime? travelDate,
    bool clearTravelDate = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? supplierId,
    bool clearSupplierId = false,
    bool? clientVisible,
    ApprovalStatus? approvalStatus,
  }) {
    return Task(
      id:             id,
      tripId:         tripId,
      teamId:         teamId,
      boardGroupId:   boardGroupId,
      name:           name           ?? this.name,
      description:    clearDescription   ? null : (description   ?? this.description),
      category:       clearCategory      ? null : (category      ?? this.category),
      status:         status         ?? this.status,
      priority:       priority       ?? this.priority,
      costStatus:     costStatus     ?? this.costStatus,
      assignedTo:     clearAssignedTo    ? null : (assignedTo    ?? this.assignedTo),
      destination:    clearDestination   ? null : (destination   ?? this.destination),
      travelDate:     clearTravelDate    ? null : (travelDate    ?? this.travelDate),
      dueDate:        clearDueDate       ? null : (dueDate       ?? this.dueDate),
      supplierId:     clearSupplierId    ? null : (supplierId    ?? this.supplierId),
      clientVisible:  clientVisible  ?? this.clientVisible,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}

// ── Back-compat alias ─────────────────────────────────────────────────────────
// Old code that references CostStatus can use TaskCostStatus.
typedef CostStatus = TaskCostStatus;
