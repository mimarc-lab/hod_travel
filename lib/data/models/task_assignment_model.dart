import 'user_model.dart';

class TaskAssignment {
  final String id;
  final String taskId;
  final AppUser user;
  final String role; // 'lead' | 'collaborator'
  final bool isPrimary;
  final DateTime createdAt;

  const TaskAssignment({
    required this.id,
    required this.taskId,
    required this.user,
    required this.role,
    required this.isPrimary,
    required this.createdAt,
  });

  TaskAssignment copyWith({String? role, bool? isPrimary}) => TaskAssignment(
    id: id,
    taskId: taskId,
    user: user,
    role: role ?? this.role,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt,
  );

  String get roleLabel => isPrimary ? 'Lead' : (role == 'lead' ? 'Lead' : 'Collaborator');
}
