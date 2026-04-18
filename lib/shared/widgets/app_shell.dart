import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/notifications/providers/notification_provider.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/suppliers/screens/suppliers_screen.dart';
import '../../features/tasks/screens/task_center_screen.dart';
import '../../features/client_dossiers/screens/client_dossier_list_screen.dart';
import '../../features/signature_experiences/screens/signature_experiences_screen.dart';
import '../../features/trips/screens/trips_list_screen.dart';
import 'app_sidebar.dart';
import 'placeholder_screen.dart';

/// Root shell that holds the sidebar + active screen.
class AppShell extends StatefulWidget {
  final NotificationProvider notificationProvider;
  final AuthProvider? authProvider;

  const AppShell({
    super.key,
    required this.notificationProvider,
    this.authProvider,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    if (Responsive.isMobile(context)) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen(
            onNavigate: (i) => setState(() => _currentIndex = i));
      case 1:
        return const TripsListScreen();
      case 2:
        return const TaskCenterScreen();
      case 3:
        return const SuppliersScreen();
      case 4:
        return const BudgetScreen();
      case 5:
        return NotificationsScreen(
            provider: widget.notificationProvider);
      case 6:
        return const SettingsScreen();
      case 7:
        return const SignatureExperiencesScreen();
      case 8:
        return const ClientDossierListScreen();
      default:
        return const PlaceholderScreen(
            title: 'Coming Soon', icon: Icons.construction_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar = Responsive.showSidebar(context);

    if (showSidebar) {
      return Scaffold(
        body: Row(
          children: [
            AppSidebar(
              currentIndex: _currentIndex,
              onItemTap: _onNavTap,
              notificationProvider: widget.notificationProvider,
              onSignOut: widget.authProvider?.signOut,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    } else {
      return Scaffold(
        drawer: Drawer(
          width: 228,
          backgroundColor: Colors.transparent,
          child: AppSidebar(
            currentIndex: _currentIndex,
            onItemTap: _onNavTap,
            notificationProvider: widget.notificationProvider,
            onSignOut: widget.authProvider?.signOut,
          ),
        ),
        body: _buildBody(),
      );
    }
  }
}
