import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/system_owner_dashboard.dart';
import 'screens/parent_dashboard_screen.dart';
import 'services/auth_storage_service.dart';
import 'services/firebase_service.dart';

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
    
    // Run the app
    runApp(const MyApp());
  } catch (e) {
    // Log any errors during initialization
    print('Error initializing Firebase: $e');
    
    // Run the app anyway, it will show error UI
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Attendance System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1E88E5),
          secondary: const Color(0xFFF5F5F5),
          surface: const Color(0xFF2A2A2A),
          background: const Color(0xFF1A1A1A),
          onPrimary: Colors.white,
          onSecondary: const Color(0xFF1A1A1A),
          onSurface: const Color(0xFFF5F5F5),
          onBackground: const Color(0xFFF5F5F5),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: const CardThemeData(
          color: Color(0xFF2A2A2A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        // Adding text theme for better responsive typography
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
      },
      builder: (context, child) {
        // Apply a MediaQuery to ensure proper sizing on all devices
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaleFactor.clamp(0.8, 1.35);
        
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaleFactor: scale, 
          ),
          child: child!,
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
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
      // Check if user is logged in
      final isLoggedIn = await AuthStorageService.isLoggedIn();
      
      if (!isLoggedIn) {
        // No user logged in, show login screen
        if (mounted) {
          setState(() {
            _initialScreen = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // Get stored login information
      final storedLogin = await AuthStorageService.getStoredDemoLogin();
      
      if (storedLogin == null) {
        // No valid stored login, show login screen
        if (mounted) {
          setState(() {
            _initialScreen = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      final role = storedLogin['role'] as UserRole;
      final studentNumber = storedLogin['studentNumber'] as String?;

      // Route based on role
      Widget? targetScreen;
      
      if (role == UserRole.systemOwner) {
        targetScreen = const SystemOwnerDashboard();
      } else if (role == UserRole.parent && studentNumber != null) {
        // For parent, fetch students by student number
        try {
          final students = await FirebaseService.getStudentsByStudentNumber(studentNumber);
          if (students.isNotEmpty) {
            final phoneNumber = students.first.fatherPhone ?? students.first.motherPhone ?? '';
            targetScreen = ParentDashboardScreen(
              phoneNumber: phoneNumber,
              students: students,
            );
          } else {
            // No students found, redirect to login
            targetScreen = const LoginScreen();
          }
        } catch (e) {
          print('Error fetching students for parent: $e');
          targetScreen = const LoginScreen();
        }
      } else {
        // Teacher or SchoolAdmin - go to HomeScreen
        targetScreen = const HomeScreen();
      }

      if (mounted) {
        setState(() {
          _initialScreen = targetScreen ?? const LoginScreen();
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return _initialScreen ?? const LoginScreen();
  }
}
