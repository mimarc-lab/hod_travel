import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import 'app_action.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OverflowActionMenu
// ─────────────────────────────────────────────────────────────────────────────

/// A compact "⋯" button that reveals a list of [AppAction] items in a popup.
///
/// Typically used in mobile toolbars to collapse secondary actions that
/// are shown inline on desktop.
class OverflowActionMenu extends StatelessWidget {
  final List<AppAction> actions;
  final String tooltip;
  final Offset offset;

  const OverflowActionMenu({
    super.key,
    required this.actions,
    this.tooltip = 'More actions',
    this.offset  = const Offset(0, 42),
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      tooltip:     tooltip,
      offset:      offset,
      onSelected:  (i) => actions[i].onTap?.call(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation:   8,
      shadowColor: const Color(0x18000000),
      constraints: const BoxConstraints(minWidth: 180),
      itemBuilder: (_) => [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value:   i,
            enabled: actions[i].enabled,
            child:   _MenuItem(action: actions[i]),
          ),
      ],
      child: Container(
        width:  36,
        height: 36,
        decoration: BoxDecoration(
          color:        AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border:       Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size:  16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final AppAction action;
  const _MenuItem({required this.action});

  Color get _fg {
    if (action.overrideColor != null) return action.overrideColor!;
    return switch (action.priority) {
      AppActionPriority.primary   => AppColors.accent,
      AppActionPriority.ghost     => AppColors.accent,
      AppActionPriority.danger    => const Color(0xFFB00020),
      _                           => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action.icon != null) ...[
          Icon(action.icon, size: 16, color: _fg),
          const SizedBox(width: 10),
        ],
        Text(
          action.label,
          style: AppTextStyles.labelMedium.copyWith(color: _fg),
        ),
      ],
    );
  }
}
