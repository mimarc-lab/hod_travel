import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/trip_component_model.dart';

/// Shown when a component's status is moved to Confirmed or Booked.
/// Lets the user choose which modules to link the component to.
/// Returns a [LinkingChoice] — caller is responsible for actually creating links.
class LinkingChoice {
  final bool linkItinerary;
  final bool linkBudget;
  final bool linkRunSheet;

  const LinkingChoice({
    required this.linkItinerary,
    required this.linkBudget,
    required this.linkRunSheet,
  });

  bool get anySelected => linkItinerary || linkBudget || linkRunSheet;
}

Future<LinkingChoice?> showComponentLinkingDialog(
  BuildContext context, {
  required TripComponent component,
}) {
  return showDialog<LinkingChoice>(
    context: context,
    builder: (_) => _ComponentLinkingDialog(component: component),
  );
}

class _ComponentLinkingDialog extends StatefulWidget {
  final TripComponent component;
  const _ComponentLinkingDialog({required this.component});

  @override
  State<_ComponentLinkingDialog> createState() => _ComponentLinkingDialogState();
}

class _ComponentLinkingDialogState extends State<_ComponentLinkingDialog> {
  bool _itinerary  = false;
  bool _budget     = false;
  bool _runSheet   = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.component;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.status.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.link_rounded, size: 16, color: c.status.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${c.status.label}: Link to modules?',
              style: AppTextStyles.heading2,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${c.title}" has been marked as ${c.status.label.toLowerCase()}. '
              'Would you like to add it to any of the following?',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.base),
            _LinkOption(
              icon:        Icons.list_alt_rounded,
              title:       'Itinerary',
              description: 'Add as an itinerary activity on its scheduled date.',
              selected:    _itinerary,
              onChanged:   (v) => setState(() => _itinerary = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LinkOption(
              icon:        Icons.attach_money_rounded,
              title:       'Budget',
              description: 'Create a cost item in the trip budget.',
              selected:    _budget,
              onChanged:   (v) => setState(() => _budget = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LinkOption(
              icon:        Icons.assignment_rounded,
              title:       'Run Sheet',
              description: 'Include in the operational run sheet.',
              selected:    _runSheet,
              onChanged:   (v) => setState(() => _runSheet = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            LinkingChoice(
              linkItinerary: _itinerary,
              linkBudget:    _budget,
              linkRunSheet:  _runSheet,
            ),
          ),
          child: const Text('Link Selected'),
        ),
      ],
    );
  }
}

class _LinkOption extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   description;
  final bool     selected;
  final ValueChanged<bool> onChanged;

  const _LinkOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentFaint : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading3.copyWith(
                      color: selected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Checkbox(
              value:     selected,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}
