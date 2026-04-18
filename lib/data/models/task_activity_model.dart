// =============================================================================
// TaskActivity — immutable system-generated audit event on a task.
// Written by DB triggers; never edited or deleted by the app.
// Displayed in the task activity feed alongside user comments.
// =============================================================================

class TaskActivity {
  final String id;
  final String taskId;
  final String? actorId;
  final String? actorName; // resolved from profiles join, may be null
  final TaskActivityType activityType;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const TaskActivity({
    required this.id,
    required this.taskId,
    this.actorId,
    this.actorName,
    required this.activityType,
    required this.message,
    this.metadata = const {},
    required this.createdAt,
  });

  factory TaskActivity.fromMap(Map<String, dynamic> m) {
    // Optional profiles join: task_activities(*, profiles(full_name))
    final profileMap = m['profiles'] as Map<String, dynamic>?;

    return TaskActivity(
      id:           m['id'] as String,
      taskId:       m['task_id'] as String,
      actorId:      m['actor_id'] as String?,
      actorName:    profileMap?['full_name'] as String?,
      activityType: taskActivityTypeFromDb(m['activity_type'] as String? ?? 'updated'),
      message:      m['message'] as String,
      metadata:     (m['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt:    DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'task_id':       taskId,
        'actor_id':      actorId,
        'activity_type': activityType.dbValue,
        'message':       message,
        'metadata':      metadata,
      };
}

// =============================================================================
// TaskActivityType enum — mirrors CHECK constraint in DB
// =============================================================================

enum TaskActivityType {
  statusChanged,
  assignedUserChanged,
  commentAdded,
  approvalChanged,
  supplierLinked,
  created,
  updated,
  deleted,
}

TaskActivityType taskActivityTypeFromDb(String s) => switch (s) {
      'status_changed'        => TaskActivityType.statusChanged,
      'assigned_user_changed' => TaskActivityType.assignedUserChanged,
      'comment_added'         => TaskActivityType.commentAdded,
      'approval_changed'      => TaskActivityType.approvalChanged,
      'supplier_linked'       => TaskActivityType.supplierLinked,
      'created'               => TaskActivityType.created,
      'deleted'               => TaskActivityType.deleted,
      _                       => TaskActivityType.updated,
    };

extension TaskActivityTypeX on TaskActivityType {
  String get dbValue => switch (this) {
        TaskActivityType.statusChanged       => 'status_changed',
        TaskActivityType.assignedUserChanged => 'assigned_user_changed',
        TaskActivityType.commentAdded        => 'comment_added',
        TaskActivityType.approvalChanged     => 'approval_changed',
        TaskActivityType.supplierLinked      => 'supplier_linked',
        TaskActivityType.created             => 'created',
        TaskActivityType.updated             => 'updated',
        TaskActivityType.deleted             => 'deleted',
      };

  String get label => switch (this) {
        TaskActivityType.statusChanged       => 'Status changed',
        TaskActivityType.assignedUserChanged => 'Assignee changed',
        TaskActivityType.commentAdded        => 'Comment added',
        TaskActivityType.approvalChanged     => 'Approval updated',
        TaskActivityType.supplierLinked      => 'Supplier linked',
        TaskActivityType.created             => 'Created',
        TaskActivityType.updated             => 'Updated',
        TaskActivityType.deleted             => 'Deleted',
      };
}
