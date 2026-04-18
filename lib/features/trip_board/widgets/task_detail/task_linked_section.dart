import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/mock/budget_mock_data.dart';
import '../../../../data/mock/itinerary_mock_data.dart';
import '../../../../data/models/cost_item_model.dart';
import '../../../../data/models/itinerary_models.dart';
import '../../../../data/models/task_model.dart';
import '../../../../shared/widgets/linked_record_card.dart';
import 'task_info_section.dart';

/// Real linked records for a task — supplier, itinerary items, cost items.
class TaskLinkedSection extends StatelessWidget {
  final Task task;
  const TaskLinkedSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final itineraryItems = _linkedItineraryItems();
    final costItems      = _linkedCostItems();
    final hasAny = task.supplierId != null ||
        itineraryItems.isNotEmpty ||
        costItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelSectionHeader(label: 'LINKED RECORDS'),

        // Supplier (ID-based link)
        if (task.supplierId != null)
          LinkedRecordCard(
            icon: Icons.storefront_outlined,
            iconColor: AppColors.accent,
            label: 'Supplier',
            title: task.supplierId!,
            subtitle: 'View in Suppliers',
          ),

        if (task.supplierId != null && (itineraryItems.isNotEmpty || costItems.isNotEmpty))
          const SizedBox(height: AppSpacing.xs),

        // Itinerary items linked via linkedTaskId
        ...itineraryItems.map((item) => LinkedRecordCard(
              icon: item.type.icon,
              iconColor: item.type.color,
              label: 'Itinerary Item',
              title: item.title,
              subtitle: item.location,
              statusColor: item.status.color,
              statusLabel: item.status.label,
            )),

        if (itineraryItems.isNotEmpty && costItems.isNotEmpty)
          const SizedBox(height: AppSpacing.xs),

        // Cost items linked via taskId
        ...costItems.map((ci) => LinkedRecordCard(
              icon: ci.category.icon,
              iconColor: ci.category.color,
              label: 'Cost Item',
              title: ci.itemName,
              subtitle: '${ci.currency} ${ci.sellPrice.toStringAsFixed(0)}',
              statusColor: ci.paymentStatus.textColor,
              statusLabel: ci.paymentStatus.label,
            )),

        if (!hasAny)
          const EmptyLinkedRecords(
              message: 'No linked records. Add a supplier or link an itinerary item.'),
      ],
    );
  }

  List<ItineraryItem> _linkedItineraryItems() {
    return mockItemsForTrip('t1')
        .values
        .expand((list) => list)
        .where((i) => i.linkedTaskId == task.id)
        .toList();
  }

  List<CostItem> _linkedCostItems() {
    return mockCostItems
        .where((ci) => ci.taskId == task.id)
        .toList();
  }
}
