import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppActionPriority
// ─────────────────────────────────────────────────────────────────────────────

/// Visual weight of an action button.
enum AppActionPriority {
  /// Solid accent fill — the main call-to-action.
  primary,

  /// Neutral surface — standard supporting actions (Edit, View, etc.).
  secondary,

  /// Red tint — destructive or irreversible actions (Delete, Archive).
  danger,

  /// Accent tint — prominent secondary action (Enrich, Discover, Import).
  ghost,

  /// Icon-only square button — utility actions (Refresh, Share, Filter).
  iconOnly,
}

// ─────────────────────────────────────────────────────────────────────────────
// AppAction
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single action to be rendered by [AppActionButton],
/// [ResponsiveActionGroup], or [ResponsiveButtonRow].
class AppAction {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final AppActionPriority priority;
  final bool enabled;

  /// Overrides the foreground (text + icon) colour derived from [priority].
  /// Background and border colours are still derived from [priority].
  final Color? overrideColor;

  const AppAction({
    required this.label,
    this.icon,
    this.onTap,
    this.priority = AppActionPriority.secondary,
    this.enabled = true,
    this.overrideColor,
  });

  AppAction copyWith({
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    AppActionPriority? priority,
    bool? enabled,
    Color? overrideColor,
  }) =>
      AppAction(
        label: label ?? this.label,
        icon: icon ?? this.icon,
        onTap: onTap ?? this.onTap,
        priority: priority ?? this.priority,
        enabled: enabled ?? this.enabled,
        overrideColor: overrideColor ?? this.overrideColor,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppActionButton — renders a single AppAction
// ─────────────────────────────────────────────────────────────────────────────

/// Renders one [AppAction] with design-system–consistent styling.
///
/// [compact] = true → icon-only (no label), useful in mobile toolbars.
class AppActionButton extends StatelessWidget {
  final AppAction action;

  /// When true the button shows the icon only (with a Tooltip for the label).
  final bool compact;

  const AppActionButton({
    super.key,
    required this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = action.priority;
    final enabled = action.enabled && action.onTap != null;

    final (Color bg, Color border, Color defaultFg) = switch (p) {
      AppActionPriority.primary   => (AppColors.accent, AppColors.accent, Colors.white),
      AppActionPriority.ghost     => (AppColors.accentFaint, AppColors.accentLight, AppColors.accent),
      AppActionPriority.danger    => (const Color(0xFFFFF0F0), const Color(0xFFFFCDD2), const Color(0xFFB00020)),
      AppActionPriority.iconOnly  => (AppColors.surfaceAlt, AppColors.border, AppColors.textSecondary),
      AppActionPriority.secondary => (AppColors.surfaceAlt, AppColors.border, AppColors.textSecondary),
    };

    final fg = action.overrideColor ?? defaultFg;

    // Icon-only mode (priority = iconOnly, OR compact flag, OR no label)
    final isIconOnly = p == AppActionPriority.iconOnly || compact;

    return GestureDetector(
      onTap: enabled ? action.onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Tooltip(
          message: isIconOnly ? action.label : '',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width:   isIconOnly ? 36 : null,
            height:  36,
            padding: isIconOnly
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              border: Border.all(
                color: action.overrideColor != null &&
                        (p == AppActionPriority.secondary ||
                         p == AppActionPriority.iconOnly)
                    ? action.overrideColor!.withAlpha(60)
                    : border,
              ),
            ),
            child: isIconOnly
                ? Center(
                    child: Icon(
                      action.icon ?? Icons.more_horiz_rounded,
                      size: 16,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (action.icon != null) ...[
                        Icon(action.icon, size: 13, color: fg),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        action.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
