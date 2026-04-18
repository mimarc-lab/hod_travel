import 'user_model.dart';

/// Represents either a user comment or a system activity entry on a task.
class TaskComment {
  final String id;
  final String taskId;
  final AppUser author;
  final String message;
  final DateTime createdAt;

  /// When true this is a system-generated activity line (e.g. "Status changed"),
  /// not a user-typed comment. Displayed differently in the UI.
  final bool isActivity;

  const TaskComment({
    required this.id,
    required this.taskId,
    required this.author,
    required this.message,
    required this.createdAt,
    this.isActivity = false,
  });
}
