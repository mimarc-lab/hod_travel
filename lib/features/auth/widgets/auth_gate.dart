import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

/// Sits between app.dart and AppShell.
/// Watches [AuthProvider] and routes to LoginScreen or the authenticated shell.
class AuthGate extends StatelessWidget {
  final AuthProvider authProvider;
  final NotificationProvider notificationProvider;

  const AuthGate({
    super.key,
    required this.authProvider,
    required this.notificationProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Skip login when Supabase credentials have not been provided at build time.
    // Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
    // to enable the full auth flow.
    if (!SupabaseConfig.isConfigured) {
      return AppShell(
        notificationProvider: notificationProvider,
        authProvider: authProvider,
      );
    }

    return ListenableBuilder(
      listenable: authProvider,
      builder: (context, _) {
        switch (authProvider.status) {
          case AuthStatus.loading:
            return const _SplashScreen();
          case AuthStatus.authenticated:
            return AppShell(
              notificationProvider: notificationProvider,
              authProvider: authProvider,
            );
          case AuthStatus.unauthenticated:
            return LoginScreen(authProvider: authProvider);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal splash while session is being restored
// ─────────────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC9A96E), // AppColors.accent without import cycle
          strokeWidth: 2,
        ),
      ),
    );
  }
}
