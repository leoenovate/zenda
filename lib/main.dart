import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/system_owner_dashboard.dart';
import 'screens/parent_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/auth_storage_service.dart';
import 'services/firebase_service.dart';
import 'models/student.dart';
import 'models/attendance.dart';

// Synthetic student used when the demo parent (STD001) resumes a session but
// no matching student exists in Firestore. Kept in sync with the equivalent
// helper in `login_screen.dart` so the parent UI is usable end-to-end.
Student _buildDemoStudent() {
  final today = DateTime.now();
  return Student(
    id: 'demo-student-std001',
    name: 'Demo Student',
    period: 'Morning',
    registrationNumber: 'STD001',
    gender: 'Male',
    birthdate: DateTime(today.year - 10, 1, 1).toIso8601String(),
    fatherName: 'Demo Father',
    fatherPhone: '0780000001',
    motherName: 'Demo Mother',
    motherPhone: '0780000002',
    country: 'Rwanda',
    province: 'Kigali',
    district: 'Gasabo',
    sector: 'Kimironko',
    cell: 'Kibagabaga',
    attendanceHistory: [
      Attendance(
        date: today.subtract(const Duration(days: 1)),
        status: AttendanceStatus.present,
      ),
      Attendance(
        date: today.subtract(const Duration(days: 2)),
        status: AttendanceStatus.late,
      ),
      Attendance(
        date: today.subtract(const Duration(days: 3)),
        status: AttendanceStatus.present,
      ),
    ],
  );
}

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
      // Prefer a live Firebase Auth session if one exists (admin/teacher).
      final restored = await AuthService.restoreSession();
      if (restored != null) {
        Widget target;
        switch (restored.role) {
          case UserRole.systemOwner:
            target = const SystemOwnerDashboard();
            break;
          case UserRole.schoolAdmin:
          case UserRole.teacher:
            target = const HomeScreen();
            break;
          case UserRole.parent:
            // Parents don't sign in via Firebase Auth, fall through to the
            // cached-session path below.
            target = const LoginScreen();
            break;
        }
        if (restored.role != UserRole.parent) {
          if (mounted) {
            setState(() {
              _initialScreen = target;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Fall back to the cached session (parents & demo logins).
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

      final role = stored['role'] as UserRole;
      final studentNumber = stored['studentNumber'] as String?;

      Widget? targetScreen;

      if (role == UserRole.parent && studentNumber != null) {
        final isDemoParent = studentNumber.trim().toUpperCase() == 'STD001';
        List<Student> students = [];
        try {
          students =
              await FirebaseService.getStudentsByStudentNumber(studentNumber);
        } catch (e) {
          print('Error fetching students for parent: $e');
          if (!isDemoParent) {
            targetScreen = const LoginScreen();
          }
        }

        if (targetScreen == null) {
          if (students.isEmpty && isDemoParent) {
            students = [_buildDemoStudent()];
          }

          if (students.isNotEmpty) {
            AuthService.setSession(AuthSession(
              role: UserRole.parent,
              studentNumber: studentNumber,
              students: students,
            ));
            final phone =
                students.first.fatherPhone ?? students.first.motherPhone ?? '';
            targetScreen = ParentDashboardScreen(
              phoneNumber: phone,
              students: students,
            );
          } else {
            targetScreen = const LoginScreen();
          }
        }
      } else if (role == UserRole.systemOwner) {
        AuthService.setSession(AuthSession(
          role: role,
          email: stored['email'] as String?,
          uid: stored['uid'] as String?,
          schoolId: stored['schoolId'] as String?,
        ));
        targetScreen = const SystemOwnerDashboard();
      } else {
        AuthService.setSession(AuthSession(
          role: role,
          email: stored['email'] as String?,
          uid: stored['uid'] as String?,
          schoolId: stored['schoolId'] as String?,
        ));
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
