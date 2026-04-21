import 'user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subtask — a checklist item belonging to a Task
// ─────────────────────────────────────────────────────────────────────────────

class Subtask {
  final String   id;
  final String   parentTaskId;
  final String   teamId;
  final String   title;
  final bool     isCompleted;
  final AppUser? assignedTo;
  final int      orderIndex;
  final DateTime createdAt;

  const Subtask({
    required this.id,
    required this.parentTaskId,
    required this.teamId,
    required this.title,
    required this.orderIndex,
    required this.createdAt,
    this.isCompleted = false,
    this.assignedTo,
  });

  Subtask copyWith({
    String?   title,
    bool?     isCompleted,
    AppUser?  assignedTo,
    bool      clearAssignedTo = false,
    int?      orderIndex,
  }) {
    return Subtask(
      id:           id,
      parentTaskId: parentTaskId,
      teamId:       teamId,
      title:        title       ?? this.title,
      isCompleted:  isCompleted ?? this.isCompleted,
      assignedTo:   clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      orderIndex:   orderIndex  ?? this.orderIndex,
      createdAt:    createdAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SubtaskTemplate — default subtasks seeded per board group (task_type)
// ─────────────────────────────────────────────────────────────────────────────

class SubtaskTemplate {
  final String  id;
  final String? taskType;             // group-name key (legacy seed data)
  final String? tripTemplateTaskId;   // per-task link (new style)
  final String  title;
  final int     orderIndex;

  const SubtaskTemplate({
    required this.id,
    this.taskType,
    this.tripTemplateTaskId,
    required this.title,
    required this.orderIndex,
  });

  SubtaskTemplate copyWith({String? title, int? orderIndex}) => SubtaskTemplate(
    id:                  id,
    taskType:            taskType,
    tripTemplateTaskId:  tripTemplateTaskId,
    title:               title      ?? this.title,
    orderIndex:          orderIndex ?? this.orderIndex,
  );
}
