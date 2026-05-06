import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/role_service.dart';
import '../../features/notifications/providers/notification_provider.dart';
import 'role_badge.dart';
import 'user_avatar.dart';

// ── Nav item data ─────────────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final IconData icon;
  final IconData iconActive;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.iconActive,
    required this.label,
  });
}

const _navItems = <_NavItem>[
  _NavItem(index: 0, icon: Icons.space_dashboard_outlined,        iconActive: Icons.space_dashboard_rounded,         label: 'Dashboard'),
  _NavItem(index: 1, icon: Icons.flight_takeoff_outlined,         iconActive: Icons.flight_takeoff_rounded,          label: 'Trips'),
  _NavItem(index: 2, icon: Icons.task_outlined,                   iconActive: Icons.task_rounded,                    label: 'Tasks'),
  _NavItem(index: 3, icon: Icons.storefront_outlined,             iconActive: Icons.storefront_rounded,              label: 'Suppliers'),
  _NavItem(index: 4, icon: Icons.account_balance_wallet_outlined, iconActive: Icons.account_balance_wallet_rounded,  label: 'Budget'),
  _NavItem(index: 5, icon: Icons.notifications_none_rounded,      iconActive: Icons.notifications_rounded,           label: 'Notifications'),
  _NavItem(index: 6, icon: Icons.settings_outlined,               iconActive: Icons.settings_rounded,                label: 'Settings'),
  _NavItem(index: 7, icon: Icons.auto_awesome_outlined,           iconActive: Icons.auto_awesome_rounded,            label: 'Experiences'),
  _NavItem(index: 8, icon: Icons.folder_shared_outlined,          iconActive: Icons.folder_shared_rounded,           label: 'Client Dossiers'),
];

// ── Sidebar widget ────────────────────────────────────────────────────────────

class AppSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemTap;
  final NotificationProvider notificationProvider;
  final Future<void> Function()? onSignOut;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onItemTap,
    required this.notificationProvider,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.sidebarWidth,
      color: AppColors.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandSection(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              children: [
                // ── WORKSPACE ─────────────────────────────────────────────
                const _SectionLabel('Workspace'),
                ..._navItems.take(5).map((item) => _NavTile(
                      item: item,
                      isActive: currentIndex == item.index,
                      onTap: () => onItemTap(item.index),
                    )),

                const SizedBox(height: AppSpacing.sm),

                // ── OPERATIONS ────────────────────────────────────────────
                const _SectionLabel('Operations'),
                ListenableBuilder(
                  listenable: notificationProvider,
                  builder: (context, _) => _NavTile(
                    item: _navItems[5],
                    isActive: currentIndex == 5,
                    onTap: () => onItemTap(5),
                    badge: notificationProvider.unreadCount > 0
                        ? notificationProvider.unreadCount
                        : null,
                  ),
                ),
                _NavTile(
                  item: _navItems[7],
                  isActive: currentIndex == 7,
                  onTap: () => onItemTap(7),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── CRM ───────────────────────────────────────────────────
                const _SectionLabel('CRM'),
                _NavTile(
                  item: _navItems[8],
                  isActive: currentIndex == 8,
                  onTap: () => onItemTap(8),
                ),

                // ── Settings (bottom utility) ─────────────────────────────
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: AppColors.sidebarDivider,
                ),
                const SizedBox(height: AppSpacing.sm),
                _NavTile(
                  item: _navItems[6],
                  isActive: currentIndex == 6,
                  onTap: () => onItemTap(6),
                ),
              ],
            ),
          ),
          _UserFooter(onSignOut: onSignOut),
        ],
      ),
    );
  }
}

// ── Brand / logo section ──────────────────────────────────────────────────────

class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.sidebarDivider)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'H',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('HOD Travel', style: AppTextStyles.sidebarBrand),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 14, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.sidebarSectionLabel,
          letterSpacing: 1.1,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Individual nav item ───────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Material(
            color: isActive
                ? AppColors.sidebarActiveBg
                : _hovered
                    ? AppColors.sidebarHoverBg
                    : Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Stack(
                children: [
                  // Gold left accent line
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: 0,
                    top: 6,
                    bottom: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: isActive ? 2 : 0,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Nav item content
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 10,
                      top: 9,
                      bottom: 9,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? widget.item.iconActive : widget.item.icon,
                          size: 16,
                          color: isActive
                              ? AppColors.sidebarActiveIcon
                              : AppColors.sidebarIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.label,
                            style: isActive
                                ? AppTextStyles.sidebarItemActive
                                : AppTextStyles.sidebarItem,
                          ),
                        ),
                        if (widget.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.badge! > 9 ? '9+' : '${widget.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── User footer ───────────────────────────────────────────────────────────────

class _UserFooter extends StatelessWidget {
  final Future<void> Function()? onSignOut;
  const _UserFooter({this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.sidebarDivider)),
      ),
      child: Builder(builder: (context) {
        final rs = RoleScope.of(context);
        return ListenableBuilder(
          listenable: rs,
          builder: (context, _) {
            final user = rs.user;
            return Row(
              children: [
                UserAvatar(user: user, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        style: AppTextStyles.sidebarItemActive
                            .copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.role,
                        style:
                            AppTextStyles.sidebarItem.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (onSignOut != null)
                  GestureDetector(
                    onTap: onSignOut,
                    child: const Tooltip(
                      message: 'Sign out',
                      child: Icon(Icons.logout_rounded,
                          size: 14, color: AppColors.sidebarIcon),
                    ),
                  )
                else
                  RoleBadge(role: user.appRole, compact: true),
              ],
            );
          },
        );
      }),
    );
  }
}
