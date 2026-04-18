import '../../../data/models/ai_suggestion_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/task_model.dart';

// ── Result types ──────────────────────────────────────────────────────────────

/// What the UI should do after calling [SuggestionApplyService.apply].
enum ApplyAction {
  /// Open the item editor pre-filled with [itemPrefill].
  openItemEditor,

  /// Open the task editor pre-filled with [taskPrefill].
  openTaskEditor,

  /// No editor needed — mark as acknowledged in place.
  acknowledged,
}

class SuggestionApplyResult {
  final ApplyAction action;

  /// Pre-filled item for [ApplyAction.openItemEditor].
  final ItemPrefill? itemPrefill;

  /// Pre-filled task data for [ApplyAction.openTaskEditor].
  final TaskPrefill? taskPrefill;

  const SuggestionApplyResult._({
    required this.action,
    this.itemPrefill,
    this.taskPrefill,
  });

  factory SuggestionApplyResult.openItemEditor(ItemPrefill prefill) =>
      SuggestionApplyResult._(
          action: ApplyAction.openItemEditor, itemPrefill: prefill);

  factory SuggestionApplyResult.openTaskEditor(TaskPrefill prefill) =>
      SuggestionApplyResult._(
          action: ApplyAction.openTaskEditor, taskPrefill: prefill);

  factory SuggestionApplyResult.acknowledged() =>
      const SuggestionApplyResult._(action: ApplyAction.acknowledged);
}

// ── Pre-fill dataclasses ──────────────────────────────────────────────────────

class ItemPrefill {
  final String title;
  final String? description;
  final String? location;
  final ItemType type;
  final TimeBlock timeBlock;

  /// If non-null, the editor should target this specific day.
  final int? dayNumber;

  const ItemPrefill({
    required this.title,
    this.description,
    this.location,
    this.type = ItemType.experience,
    this.timeBlock = TimeBlock.morning,
    this.dayNumber,
  });
}

class TaskPrefill {
  final String name;
  final String? description;
  final String? category;
  final TaskPriority priority;

  const TaskPrefill({
    required this.name,
    this.description,
    this.category,
    this.priority = TaskPriority.medium,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Converts an [AiSuggestion] into an [SuggestionApplyResult] that tells the
/// UI exactly what editor to open and with what pre-filled data.
///
/// This service NEVER writes data directly — it is always the user who saves.
class SuggestionApplyService {
  const SuggestionApplyService();

  SuggestionApplyResult apply(AiSuggestion suggestion) {
    return switch (suggestion.type) {
      AiSuggestionType.draftItinerary =>
        _applyItinerary(suggestion.proposedPayload),
      AiSuggestionType.missingGap => SuggestionApplyResult.acknowledged(),
      AiSuggestionType.supplierRecommendation =>
        SuggestionApplyResult.acknowledged(),
      AiSuggestionType.signatureExperience =>
        _applySignatureExperience(suggestion),
      AiSuggestionType.taskSuggestion => _applyTask(suggestion.proposedPayload),
      AiSuggestionType.flowImprovement => SuggestionApplyResult.acknowledged(),
    };
  }

  // ── Itinerary ──────────────────────────────────────────────────────────────

  SuggestionApplyResult _applyItinerary(Map<String, dynamic> payload) {
    final title = payload['title'] as String? ?? '';
    final description = payload['description'] as String?;
    final location = payload['location'] as String?;
    final dayNumber = _parseInt(payload['day_number']);
    final type = _parseItemType(payload['type'] as String?);
    final timeBlock = _parseTimeBlock(payload['time_block'] as String?);

    return SuggestionApplyResult.openItemEditor(ItemPrefill(
      title: title.isNotEmpty ? title : 'New Item',
      description: description,
      location: location,
      type: type,
      timeBlock: timeBlock,
      dayNumber: dayNumber,
    ));
  }

  // ── Signature Experience (maps to an itinerary item) ──────────────────────

  SuggestionApplyResult _applySignatureExperience(AiSuggestion suggestion) {
    final payload = suggestion.proposedPayload;
    final title =
        (payload['experience_title'] as String?) ?? suggestion.title;
    final dayNumber = _parseInt(payload['day_number']);
    final timeBlock = _parseTimeBlock(payload['time_block'] as String?);

    return SuggestionApplyResult.openItemEditor(ItemPrefill(
      title: title,
      description: suggestion.description,
      type: ItemType.experience,
      timeBlock: timeBlock,
      dayNumber: dayNumber,
    ));
  }

  // ── Task ───────────────────────────────────────────────────────────────────

  SuggestionApplyResult _applyTask(Map<String, dynamic> payload) {
    final name = payload['name'] as String? ?? '';
    final description = payload['description'] as String?;
    final category = payload['category'] as String?;
    final priority = _parsePriority(payload['priority'] as String?);

    return SuggestionApplyResult.openTaskEditor(TaskPrefill(
      name: name.isNotEmpty ? name : 'New Task',
      description: description,
      category: category,
      priority: priority,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  ItemType _parseItemType(String? v) => switch (v?.toLowerCase()) {
        'hotel' => ItemType.hotel,
        'transport' => ItemType.transport,
        'dining' => ItemType.dining,
        'flight' => ItemType.flight,
        'note' => ItemType.note,
        _ => ItemType.experience,
      };

  TimeBlock _parseTimeBlock(String? v) => switch (v?.toLowerCase()) {
        'afternoon' => TimeBlock.afternoon,
        'evening' => TimeBlock.evening,
        'all_day' || 'allday' || 'full_day' => TimeBlock.allDay,
        _ => TimeBlock.morning,
      };

  TaskPriority _parsePriority(String? v) => switch (v?.toLowerCase()) {
        'low' => TaskPriority.low,
        'high' || 'urgent' => TaskPriority.high,
        _ => TaskPriority.medium,
      };
}
