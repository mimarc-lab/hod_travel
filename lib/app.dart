import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/services/role_service.dart';
import 'core/supabase/app_db.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/widgets/auth_gate.dart';
import 'features/notifications/providers/notification_provider.dart';

class HODApp extends StatefulWidget {
  const HODApp({super.key});

  @override
  State<HODApp> createState() => _HODAppState();
}

class _HODAppState extends State<HODApp> {
  late final AuthProvider _authProvider;
  late final RoleService _roleService;
  late NotificationProvider _notificationProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _roleService  = RoleService();

    _notificationProvider = NotificationProvider(
      repository:    AppRepositories.instance?.notifications,
      currentUserId: null,
    );

    _authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final user   = _authProvider.currentUser;
    final userId = user?.id;

    // Sync role into RoleService so permission-gated widgets update
    if (user != null) _roleService.switchUser(user);

    // Rebuild NotificationProvider with real userId once authenticated
    if (userId != null &&
        AppRepositories.instance != null &&
        _notificationProvider.currentUserId != userId) {
      _notificationProvider.dispose();
      setState(() {
        _notificationProvider = NotificationProvider(
          repository:    AppRepositories.instance?.notifications,
          currentUserId: userId,
        );
      });
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider.dispose();
    _roleService.dispose();
    _notificationProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleScope(
      roleService: _roleService,
      child: MaterialApp(
        title: 'HOD Travel',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: AuthGate(
          authProvider:         _authProvider,
          notificationProvider: _notificationProvider,
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      colorScheme: ColorScheme.light(
        primary:   AppColors.accent,
        secondary: AppColors.accent,
        surface:   AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.accent,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
      ),
    );
  }
}
