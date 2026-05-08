import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/services/role_service.dart';
import 'core/supabase/app_db.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/widgets/auth_gate.dart';
import 'features/client_view/client_share_screen.dart';
import 'features/run_sheet/run_sheet_share_screen.dart';
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
    // Detect public share routes on web — bypass auth entirely.
    if (kIsWeb) {
      final uri      = Uri.base;
      final segments = uri.pathSegments;

      // /share/{slug} — client itinerary
      if (segments.length >= 2 && segments[0] == 'share') {
        return MaterialApp(
          title:                    'HOD Travel',
          debugShowCheckedModeBanner: false,
          theme:                    _buildTheme(),
          home:                     ClientShareScreen(token: segments[1]),
        );
      }

      // /run-sheet/{tripId}?token={token} — role-scoped run sheet
      if (segments.length >= 2 && segments[0] == 'run-sheet') {
        final tripId = segments[1];
        final token  = uri.queryParameters['token'] ?? '';
        if (token.isNotEmpty) {
          return MaterialApp(
            title:                    'HOD Travel',
            debugShowCheckedModeBanner: false,
            theme:                    _buildTheme(),
            home:                     RunSheetShareScreen(
                                        tripId: tripId,
                                        token:  token,
                                      ),
          );
        }
      }
    }

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

    const buttonShape = StadiumBorder();
    const buttonPadding =
        EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    const buttonMinSize = Size(0, 44);
    final buttonText =
        GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);

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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.textSecondary,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: buttonShape,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          elevation: 0,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: buttonShape,
          foregroundColor: AppColors.accent,
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
