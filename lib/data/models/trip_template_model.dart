// =============================================================================
// TripTemplate + TripTemplateTask
// =============================================================================

class TripTemplateTask {
  final String id;
  final String templateId;
  final String groupName; // must match one of defaultBoardGroupNames
  final String title;
  final String priority;  // 'low' | 'medium' | 'high'
  final int sortOrder;

  const TripTemplateTask({
    required this.id,
    required this.templateId,
    required this.groupName,
    required this.title,
    required this.priority,
    required this.sortOrder,
  });

  TripTemplateTask copyWith({
    String? groupName,
    String? title,
    String? priority,
    int? sortOrder,
  }) =>
      TripTemplateTask(
        id:         id,
        templateId: templateId,
        groupName:  groupName  ?? this.groupName,
        title:      title      ?? this.title,
        priority:   priority   ?? this.priority,
        sortOrder:  sortOrder  ?? this.sortOrder,
      );
}

class TripTemplate {
  final String id;
  final String teamId;
  final String name;
  final String? description;
  final List<TripTemplateTask> tasks;
  final DateTime createdAt;

  const TripTemplate({
    required this.id,
    required this.teamId,
    required this.name,
    this.description,
    required this.tasks,
    required this.createdAt,
  });

  /// Total task count
  int get taskCount => tasks.length;

  /// Returns tasks for a specific group, sorted by sortOrder
  List<TripTemplateTask> tasksForGroup(String groupName) =>
      tasks.where((t) => t.groupName == groupName).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
