import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/school_admin_dashboard.dart';
import 'screens/system_owner_dashboard.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/auth_storage_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'utils/web_brand_sync.dart';

void main() async {
  try {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Log successful initialization
    print('Firebase successfully initialized');

    runApp(_buildApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
    runApp(_buildApp());
  }
}

Widget _buildApp() {
  return ChangeNotifierProvider<ThemeController>(
    create: (_) => ThemeController()..load(),
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return MaterialApp(
      title: 'School Attendance System',
      theme: AppTheme.light(primary: controller.primary),
      darkTheme: AppTheme.dark(primary: controller.primary),
      themeMode: controller.mode,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
      },
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.35,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: scale),
          child: _WebBrandListener(
            primary: controller.primary,
            isDark: controller.isDarkResolved,
            child: child!,
          ),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class _WebBrandListener extends StatefulWidget {
  const _WebBrandListener({
    required this.primary,
    required this.isDark,
    required this.child,
  });

  final AppPrimary primary;
  final bool isDark;
  final Widget child;

  @override
  State<_WebBrandListener> createState() => _WebBrandListenerState();
}

class _WebBrandListenerState extends State<_WebBrandListener> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _WebBrandListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primary != widget.primary ||
        oldWidget.isDark != widget.isDark) {
      _sync();
    }
  }

  void _sync() {
    syncWebBrand(primary: widget.primary, isDark: widget.isDark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Restore the local Firestore-backed session cache. restoreSession()
      // re-reads users/{uid} for staff + guardians and resolves linked
      // students, so the wrapper just routes by the restored role.
      final stored = await AuthStorageService.getStoredSession();
      if (stored == null) {
        if (mounted) {
          setState(() {
            _initialScreen = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      Widget targetScreen;
      final restored = await AuthService.restoreSession();
      if (restored == null) {
        await AuthStorageService.clearStoredLogin();
        targetScreen = const LoginScreen();
      } else {
        switch (restored.role) {
          case UserRole.systemOwner:
            targetScreen = const SystemOwnerDashboard();
            break;
          case UserRole.schoolAdmin:
            targetScreen = const SchoolAdminDashboard();
            break;
          case UserRole.teacher:
            targetScreen = const TeacherDashboardScreen();
            break;
          case UserRole.parent:
            targetScreen = ParentDashboardScreen(
              phoneNumber: restored.phone ?? '',
              students: restored.students,
            );
            break;
        }
      }

      if (mounted) {
        setState(() {
          _initialScreen = targetScreen;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _initialScreen = const LoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _initialScreen ?? const LoginScreen();
  }
}
