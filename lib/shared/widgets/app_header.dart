import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/mock/mock_data.dart';
import 'user_avatar.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.showMenuButton = false,
    this.onMenuTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.headerHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.headerHeight,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(120))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              onPressed: onMenuTap,
              color: AppColors.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          // Only show title text if non-empty; dashboard uses its own greeting
          if (title.isNotEmpty)
            Expanded(
              child: Text(title, style: AppTextStyles.heading1),
            )
          else
            const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: AppSpacing.sm),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
          const SizedBox(width: AppSpacing.xs),
          UserAvatar(user: currentUser, size: 32),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}
