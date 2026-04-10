import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'parent_dashboard_screen.dart';
import 'system_owner_dashboard.dart';
import '../services/firebase_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';
import '../models/student.dart';
import '../models/attendance.dart';

enum UserRole {
  parent,
  teacher,
  schoolAdmin,
  systemOwner,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  UserRole? _selectedRole;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Demo credentials for non-parent roles (email-based login).
  static const Map<UserRole, Map<String, String>> _demoCredentials = {
    UserRole.systemOwner: {'email': 'owner@school.com', 'password': 'owner123'},
    UserRole.schoolAdmin: {'email': 'admin@school.com', 'password': 'admin123'},
    UserRole.teacher: {'email': 'teacher@school.com', 'password': 'teacher123'},
  };

  // Demo credentials for parent role (student-number-based login).
  static const String _demoParentStudentNumber = 'STD001';
  static const String _demoParentPassword = 'parent123';

  bool _checkDemoCredentials(String email, String password, UserRole role) {
    final expected = _demoCredentials[role];
    if (expected == null) return false;

    return email.toLowerCase().trim() == expected['email']?.toLowerCase() &&
           password == expected['password'];
  }

  bool _isDemoParentCredentials(String studentNumber, String password) {
    return studentNumber.trim().toUpperCase() == _demoParentStudentNumber &&
        password == _demoParentPassword;
  }

  // Synthetic student used when the demo parent logs in but no real student
  // with registration number STD001 exists in Firestore yet. Lets the parent
  // UI be explored end-to-end without seeding data first.
  Student _buildDemoStudent() {
    final today = DateTime.now();
    return Student(
      id: 'demo-student-std001',
      name: 'Demo Student',
      period: 'Morning',
      registrationNumber: _demoParentStudentNumber,
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

  Future<void> _login() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final emailOrStudentNumber = _emailController.text.trim();
      final password = _passwordController.text;

      // Handle parent login with student number
      if (_selectedRole == UserRole.parent) {
        final isDemoParent = _isDemoParentCredentials(emailOrStudentNumber, password);

        // For parents, emailOrStudentNumber is actually a student number.
        // Try to find the student by registration number.
        List<Student> students = [];
        try {
          students = await FirebaseService.getStudentsByStudentNumber(emailOrStudentNumber);
        } catch (e) {
          // Only tolerate lookup failures for the demo parent so the UI can be
          // explored even when Firestore is unreachable or empty.
          if (!isDemoParent) rethrow;
          print('LoginScreen: Demo parent Firestore lookup failed: $e');
        }

        if (students.isEmpty) {
          if (isDemoParent) {
            // Seed a synthetic student so the parent dashboard is reachable.
            print('LoginScreen: No real student matched STD001, using demo student');
            students = [_buildDemoStudent()];
          } else {
            throw Exception('No student found with this student number');
          }
        } else if (!isDemoParent) {
          // A real student exists for this registration number. We don't have a
          // parent account system yet, so require at least a non-empty password
          // (form already enforces >= 6 chars) and treat it as a success.
        }

        print('LoginScreen: Saving parent login credentials (demo=$isDemoParent)...');
        await AuthStorageService.saveDemoLogin(
          role: UserRole.parent,
          studentNumber: emailOrStudentNumber,
        );
        print('LoginScreen: Parent login credentials saved');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ParentDashboardScreen(
              phoneNumber: students.first.fatherPhone ?? students.first.motherPhone ?? '',
              students: students,
            ),
          ),
        );
      } else {
        // Check for demo credentials first
        final isDemoLogin = _checkDemoCredentials(emailOrStudentNumber, password, _selectedRole!);
        
        if (isDemoLogin) {
          // Save demo login credentials for persistence
          print('LoginScreen: Demo login detected, saving credentials for role: ${_selectedRole!.name}');
          await AuthStorageService.saveDemoLogin(
            role: _selectedRole!,
            email: emailOrStudentNumber,
          );
          print('LoginScreen: Demo login credentials saved successfully');

          // Allow demo login without Firebase authentication
          if (!mounted) return;
          
          // Route based on role
          if (_selectedRole == UserRole.systemOwner) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SystemOwnerDashboard(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
          return;
        }
        
        // For real accounts - use email/password with Firebase
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: emailOrStudentNumber,
          password: password,
        );

        if (userCredential.user != null) {
          // Save Firebase login (not demo)
          await AuthStorageService.saveFirebaseLogin();

          if (!mounted) return;
          
          // Route based on role
          if (_selectedRole == UserRole.systemOwner) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SystemOwnerDashboard(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please try again.';
      
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with these credentials.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address or student number.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    
    return Scaffold(
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Login form section (mobile) - moved to top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white, // White background
            ),
            child: _buildLoginForm(),
          ),
          // Branding section (mobile) - moved to bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Color(0xFF1A5F5F), // Dark teal
            ),
            child: Column(
              children: [
                _buildBrandingContent(),
                const SizedBox(height: 24),
                _buildFeatureButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - 40% width
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: const BoxDecoration(
              color: Color(0xFF1A5F5F), // Dark teal
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBrandingContent(),
                const SizedBox(height: 48),
                _buildFeatureButtons(),
              ],
            ),
          ),
        ),
        // Right side - 60% width
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: const BoxDecoration(
              color: Colors.white, // White background
            ),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingContent() {
    return Column(
      children: [
        // Graduation cap icon in circle
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A8A8A), // Light teal circle
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 64,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        // Brand name
        const Text(
          'Zenda',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        const Text(
          'School Attendance System',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        // Description
        Text(
          'Streamline attendance management, parent communication, and student data with our modern, intuitive platform.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.isMobile ? 14 : 16,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildFeatureButton(
          icon: Icons.check_circle,
          label: 'Real-time Updates',
        ),
        _buildFeatureButton(
          icon: Icons.shield,
          label: 'Secure & Reliable',
        ),
        _buildFeatureButton(
          icon: Icons.desktop_windows,
          label: 'Multi-Platform',
        ),
      ],
    );
  }

  Widget _buildFeatureButton({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome text
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2C), // Dark gray
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please sign in to continue',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF666666), // Medium gray
            ),
          ),
          const SizedBox(height: 32),
          // Login card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, // White card
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role selection
                const Text(
                  'Select Role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C), // Dark gray
                  ),
                ),
                const SizedBox(height: 16),
                _buildRoleSelection(),
                const SizedBox(height: 24),
                // Email/Student Number field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Color(0xFF2C2C2C)),
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.parent
                        ? 'Student Number'
                        : 'Email or Student Number',
                    labelStyle: const TextStyle(color: Color(0xFF666666)),
                    hintText: _selectedRole == UserRole.parent
                        ? 'STD001'
                        : 'email@school.com',
                    hintStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF666666)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0), // Light gray border
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0), // Light gray border
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A5F5F), // Dark teal
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter ${_selectedRole == UserRole.parent ? "student number" : "email or student number"}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Color(0xFF2C2C2C)),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Color(0xFF666666)),
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFF666666)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF666666),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0), // Light gray border
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0), // Light gray border
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A5F5F), // Dark teal
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Sign In button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F5F), // Dark teal
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                // Demo Credentials
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5), // Light gray background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF666666),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Demo Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDemoCredential('Owner', 'owner@school.com', 'owner123', UserRole.systemOwner),
                      _buildDemoCredential('Admin', 'admin@school.com', 'admin123', UserRole.schoolAdmin),
                      _buildDemoCredential('Teacher', 'teacher@school.com', 'teacher123', UserRole.teacher),
                      _buildDemoCredential('Parent', 'STD001', 'parent123', UserRole.parent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Copyright
          const Text(
            '©2025 Zenda. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                role: UserRole.parent,
                icon: Icons.family_restroom,
                label: 'Parent',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleButton(
                role: UserRole.teacher,
                icon: Icons.school,
                label: 'Teacher',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                role: UserRole.schoolAdmin,
                icon: Icons.computer,
                label: 'School Admin',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleButton(
                role: UserRole.systemOwner,
                icon: Icons.people,
                label: 'System Owner',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleButton({
    required UserRole role,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A5F5F).withOpacity(0.1)
              : const Color(0xFFF5F5F5), // Light gray
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A5F5F) // Dark teal
                : const Color(0xFFE0E0E0), // Light gray border
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1A5F5F) : const Color(0xFF666666),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF1A5F5F) : const Color(0xFF666666),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredential(String role, String username, String password, UserRole userRole) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              _selectedRole = userRole;
              _emailController.text = username;
              _passwordController.text = password;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$role: ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    '$username / $password',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                const Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: Color(0xFF999999),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
