import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/parent_login_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/system_owner_dashboard.dart';
import 'screens/api_logs_screen.dart';
import 'services/firebase_service.dart';
import 'services/auth_storage_service.dart';
import 'models/student.dart';

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
          primary: const Color(0xFFD4AF37), // Mustard yellow
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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/parent-login': (context) => const ParentLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/system-owner': (context) => const SystemOwnerDashboard(),
        '/api-logs': (context) => const ApiLogsScreen(),
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
  bool _isLoadingStudents = false;
  bool _isCheckingDemoLogin = true;
  List<Student>? _parentStudents;
  String? _parentPhone;
  Widget? _demoLoginScreen;

  @override
  void initState() {
    super.initState();
    _checkDemoLogin();
  }

  Future<void> _checkDemoLogin() async {
    try {
      // Debug: Print all stored values
      await AuthStorageService.debugPrintStoredValues();
      
      // Check for stored demo login credentials
      final storedLogin = await AuthStorageService.getStoredDemoLogin();
      
      if (!mounted) return;
      
      if (storedLogin != null) {
        print('AuthWrapper: Found stored demo login: ${storedLogin['role']}');
        final role = storedLogin['role'] as UserRole;
        final studentNumber = storedLogin['studentNumber'] as String?;

        // Navigate based on role
        if (role == UserRole.parent && studentNumber != null) {
          print('AuthWrapper: Loading parent students for demo login');
          // Load parent students - this will set _demoLoginScreen and _isCheckingDemoLogin when done
          await _loadParentStudentsForDemo(studentNumber);
        } else if (role == UserRole.systemOwner) {
          print('AuthWrapper: Navigating to SystemOwnerDashboard');
          setState(() {
            _demoLoginScreen = const SystemOwnerDashboard();
            _isCheckingDemoLogin = false;
          });
        } else {
          print('AuthWrapper: Navigating to HomeScreen');
          // schoolAdmin or teacher
          setState(() {
            _demoLoginScreen = const HomeScreen();
            _isCheckingDemoLogin = false;
          });
        }
      } else {
        print('AuthWrapper: No stored demo login found');
        // No stored demo login - proceed to check Firebase Auth
        setState(() {
          _isCheckingDemoLogin = false;
        });
      }
    } catch (e) {
      print('Error checking demo login: $e');
      // On error, proceed to check Firebase Auth
      if (mounted) {
        setState(() {
          _isCheckingDemoLogin = false;
        });
      }
    }
  }

  Future<void> _loadParentStudentsForDemo(String studentNumber) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final students = await FirebaseService.getStudentsByStudentNumber(studentNumber);
      
      if (!mounted) return;
      
      setState(() {
        _parentStudents = students;
        _isLoadingStudents = false;
        _isCheckingDemoLogin = false; // Mark demo check as complete
        if (students.isNotEmpty) {
          _parentPhone = students.first.fatherPhone ?? students.first.motherPhone ?? '';
          _demoLoginScreen = ParentDashboardScreen(
            phoneNumber: _parentPhone!,
            students: students,
          );
        } else {
          // No students found - clear demo login and show login screen
          _demoLoginScreen = const LoginScreen();
        }
      });
      
      // Clear stored login if no students found
      if (students.isEmpty) {
        await AuthStorageService.clearStoredLogin();
      }
    } catch (e) {
      print('Error loading parent students for demo: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoadingStudents = false;
        _isCheckingDemoLogin = false; // Mark demo check as complete
        // On error, clear demo login and show login screen
        _demoLoginScreen = const LoginScreen();
      });
      
      // Clear stored login on error
      await AuthStorageService.clearStoredLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking demo login
    if (_isCheckingDemoLogin) {
      print('AuthWrapper: Checking demo login...');
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If demo login screen is set, show it
    if (_demoLoginScreen != null) {
      print('AuthWrapper: Showing demo login screen');
      return _demoLoginScreen!;
    }
    
    print('AuthWrapper: No demo login, checking Firebase Auth...');

    // Use userChanges() instead of authStateChanges() for better persistence handling
    // userChanges() emits the current user immediately, making it better for checking persisted sessions
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser, // Check current user immediately
      builder: (context, snapshot) {
        // Get user from snapshot
        final user = snapshot.data;

        // Debug: Log auth state for troubleshooting
        if (user != null) {
          print('AuthWrapper: User logged in - ${user.email ?? user.phoneNumber}');
        } else {
          print('AuthWrapper: No user logged in');
        }

        // If user is logged in, check if they're admin or parent
        if (user != null) {
          return _buildUserScreen(user);
        }

        // No user logged in - show login screen
        // Reset parent data when logged out
        if (_parentStudents != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _parentStudents = null;
                _parentPhone = null;
                _demoLoginScreen = null;
              });
            }
          });
        }
        return const LoginScreen();
      },
    );
  }

  Widget _buildUserScreen(User user) {
    // Check if user has email (admin) or phone (parent)
    if (user.email != null && user.email!.isNotEmpty) {
      // Admin user - go to home screen
      return const HomeScreen();
    } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      // Parent user - fetch students and navigate to dashboard
      // Only fetch if we haven't already fetched or if phone number changed
      if (!_isLoadingStudents && 
          (_parentStudents == null || _parentPhone != user.phoneNumber)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadParentStudents(user.phoneNumber!);
        });
      }
      
      // Show loading while fetching students
      if (_isLoadingStudents || _parentStudents == null) {
        return const Scaffold(
          backgroundColor: Color(0xFF1A1A1A),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      
      // Navigate to parent dashboard (handles empty students list gracefully)
      return ParentDashboardScreen(
        phoneNumber: _parentPhone ?? user.phoneNumber!,
        students: _parentStudents!,
      );
    }
    
    // Fallback to login screen if user type can't be determined
    return const LoginScreen();
  }

  Future<void> _loadParentStudents(String phoneNumber) async {
    setState(() {
      _isLoadingStudents = true;
      _parentPhone = phoneNumber;
    });

    try {
      // Normalize phone number (remove +250 if present)
      String normalizedPhone = phoneNumber.replaceAll('+250', '').replaceAll(' ', '');
      
      final List<Student> students = await FirebaseService.getStudentsByParentPhone(
        normalizedPhone,
      );

      if (mounted) {
        setState(() {
          _parentStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      print('Error loading parent students: $e');
      if (mounted) {
        setState(() {
          _parentStudents = [];
          _isLoadingStudents = false;
        });
      }
    }
  }
}
