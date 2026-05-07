import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../design_system/typography_tokens.dart';

/// Data class for a single row action (edit, delete, assign, approve…).
class AdaptiveAction<T> {
  final String label;
  final IconData icon;
  final void Function(T item) onTap;
  final Color? color;
  final bool isDestructive;

  const AdaptiveAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });
}

/// Three-dot popup menu rendered for a specific [item].
///
/// On desktop rows the menu icon fades in on hover (opacity controlled by
/// [AdaptiveRow]). On mobile it is always visible at the trailing edge.
class AdaptiveRowActions<T> extends StatelessWidget {
  final T item;
  final List<AdaptiveAction<T>> actions;

  const AdaptiveRowActions({
    super.key,
    required this.item,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      onSelected: (i) => actions[i].onTap(item),
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: AppColors.textMuted,
      ),
      itemBuilder: (context) => [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 38,
            child: Row(
              children: [
                Icon(
                  actions[i].icon,
                  size: 14,
                  color: actions[i].isDestructive
                      ? const Color(0xFFEF4444)
                      : (actions[i].color ?? AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  actions[i].label,
                  style: AdaptiveTypography.secondaryCell.copyWith(
                    color: actions[i].isDestructive
                        ? const Color(0xFFEF4444)
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      color: Colors.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
