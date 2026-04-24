import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_component_model.dart';

class ComponentStatusChip extends StatelessWidget {
  final ComponentStatus status;
  final bool small;

  const ComponentStatusChip({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical:   small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color:        status.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: (small ? AppTextStyles.labelSmall : AppTextStyles.labelMedium)
            .copyWith(color: status.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
