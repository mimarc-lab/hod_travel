import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/budget_mock_data.dart';
import '../../../data/mock/itinerary_mock_data.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/cost_item_model.dart';
import '../../../data/models/itinerary_models.dart';
import '../../../data/models/task_model.dart';
import '../../../shared/widgets/linked_record_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupplierLinkedRecords
// Cross-module links: tasks, itinerary items, cost items matching supplier name.
// ─────────────────────────────────────────────────────────────────────────────

class SupplierLinkedRecords extends StatelessWidget {
  final String supplierName;
  const SupplierLinkedRecords({super.key, required this.supplierName});

  @override
  Widget build(BuildContext context) {
    final tasks      = _linkedTasks();
    final items      = _linkedItineraryItems();
    final costItems  = _linkedCostItems();
    final hasLinks   = tasks.isNotEmpty || items.isNotEmpty || costItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LINKED RECORDS', style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),

        if (!hasLinks)
          const EmptyLinkedRecords(
              message: 'No linked tasks, itinerary items, or cost items yet.')
        else ...[
          if (tasks.isNotEmpty) ...[
            _SubLabel(label: 'Tasks'),
            const SizedBox(height: AppSpacing.xs),
            ...tasks.map((t) => LinkedRecordCard(
                  icon: Icons.task_outlined,
                  iconColor: AppColors.textSecondary,
                  label: 'Task',
                  title: t.name,
                  subtitle: t.destination,
                  statusColor: _taskStatusColor(t.status),
                  statusLabel: t.status.label,
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (items.isNotEmpty) ...[
            _SubLabel(label: 'Itinerary Items'),
            const SizedBox(height: AppSpacing.xs),
            ...items.map((i) => LinkedRecordCard(
                  icon: i.type.icon,
                  iconColor: i.type.color,
                  label: 'Itinerary',
                  title: i.title,
                  subtitle: i.location,
                  statusColor: i.status.color,
                  statusLabel: i.status.label,
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (costItems.isNotEmpty) ...[
            _SubLabel(label: 'Cost Items'),
            const SizedBox(height: AppSpacing.xs),
            ...costItems.map((ci) => LinkedRecordCard(
                  icon: ci.category.icon,
                  iconColor: ci.category.color,
                  label: 'Budget',
                  title: ci.itemName,
                  subtitle: '${ci.currency} ${ci.sellPrice.toStringAsFixed(0)}',
                  statusColor: ci.paymentStatus.textColor,
                  statusLabel: ci.paymentStatus.label,
                )),
          ],
        ],
      ],
    );
  }

  List<Task> _linkedTasks() {
    final q = supplierName.toLowerCase();
    return mockBoardGroupsForTrip('t1')
        .expand((g) => g.tasks)
        .where((t) => t.supplierId?.toLowerCase() == q)
        .toList();
  }

  List<ItineraryItem> _linkedItineraryItems() {
    final q = supplierName.toLowerCase();
    return mockItemsForTrip('t1')
        .values
        .expand((list) => list)
        .where((i) => i.supplierName?.toLowerCase() == q)
        .toList();
  }

  List<CostItem> _linkedCostItems() {
    final q = supplierName.toLowerCase();
    return mockCostItems
        .where((ci) => ci.itemName.toLowerCase().contains(q) ||
            (ci.notes?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Color _taskStatusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.notStarted:    return AppColors.statusNotStartedText;
      case TaskStatus.researching:   return AppColors.statusInProgressText;
      case TaskStatus.awaitingReply: return AppColors.statusWaitingText;
      case TaskStatus.readyForReview:return AppColors.statusInProgressText;
      case TaskStatus.approved:      return AppColors.statusDoneText;
      case TaskStatus.sentToClient:  return AppColors.statusInProgressText;
      case TaskStatus.confirmed:     return AppColors.statusDoneText;
      case TaskStatus.cancelled:     return AppColors.statusBlockedText;
    }
  }
}

class _SubLabel extends StatelessWidget {
  final String label;
  const _SubLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
