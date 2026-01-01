import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'parent_dashboard_screen.dart';
import 'system_owner_dashboard.dart';
import '../services/firebase_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';

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

  bool _checkDemoCredentials(String email, String password, UserRole role) {
    // Demo credentials mapping
    final demoCredentials = {
      UserRole.systemOwner: {'email': 'owner@school.com', 'password': 'owner123'},
      UserRole.schoolAdmin: {'email': 'admin@school.com', 'password': 'admin123'},
      UserRole.teacher: {'email': 'teacher@school.com', 'password': 'teacher123'},
    };

    final expected = demoCredentials[role];
    if (expected == null) return false;

    return email.toLowerCase().trim() == expected['email']?.toLowerCase() &&
           password == expected['password'];
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
        // For parents, emailOrStudentNumber is actually a student number
        // Find the student by registration number
        final students = await FirebaseService.getStudentsByStudentNumber(emailOrStudentNumber);
        
        if (students.isEmpty) {
          throw Exception('No student found with this student number');
        }

        // Save demo login credentials for persistence
        print('LoginScreen: Saving parent demo login credentials...');
        await AuthStorageService.saveDemoLogin(
          role: UserRole.parent,
          studentNumber: emailOrStudentNumber,
        );
        print('LoginScreen: Parent demo login credentials saved');

        // For parent login, we'll verify the student exists and navigate to parent dashboard
        // In a production app, you'd verify parent credentials separately
        // For demo purposes, we'll allow login if student exists
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
              color: Color(0xFF0A2E1A), // Dark navy green
            ),
            child: _buildLoginForm(),
          ),
          // Branding section (mobile) - moved to bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Color(0xFFD4AF37), // Mustard yellow
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
              color: Color(0xFFD4AF37), // Mustard yellow
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
              color: Color(0xFF0A2E1A), // Dark navy green
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
            color: const Color(0xFFF5E6A3), // Light yellow circle
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 64,
            color: Color(0xFF2C2C2C), // Dark gray
          ),
        ),
        const SizedBox(height: 24),
        // Brand name
        const Text(
          'Zenda',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C2C2C), // Dark gray
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
            color: Color(0xFF2C2C2C), // Dark gray
          ),
        ),
        const SizedBox(height: 24),
        // Description
        Text(
          'Streamline attendance management, parent communication, and student data with our modern, intuitive platform.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.isMobile ? 14 : 16,
            color: const Color(0xFF2C2C2C), // Dark gray
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
        color: const Color(0xFFF5E6A3), // Light yellow
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2C2C2C).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2C2C2C)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2C2C2C),
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please sign in to continue',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),
          // Login card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A), // Dark gray
              borderRadius: BorderRadius.circular(16),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRoleSelection(),
                const SizedBox(height: 24),
                // Email/Student Number field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.parent
                        ? 'Student Number'
                        : 'Email or Student Number',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: _selectedRole == UserRole.parent
                        ? 'STD001'
                        : 'email@school.com',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD4AF37),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFD4AF37),
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
                    backgroundColor: const Color(0xFFD4AF37), // Yellow
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
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Demo Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDemoCredential('Owner', 'owner@school.com', 'owner123'),
                      _buildDemoCredential('Admin', 'admin@school.com', 'admin123'),
                      _buildDemoCredential('Teacher', 'teacher@school.com', 'teacher123'),
                      _buildDemoCredential('Parent', 'STD001', 'parent123'),
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
              color: Colors.white54,
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
                icon: Icons.business,
                label: 'School Admin',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleButton(
                role: UserRole.systemOwner,
                icon: Icons.person,
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
              ? const Color(0xFFD4AF37).withOpacity(0.2)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD4AF37)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredential(String role, String username, String password) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$role: ',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              '$username / $password',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
