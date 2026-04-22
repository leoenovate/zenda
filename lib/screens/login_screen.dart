import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'parent_dashboard_screen.dart';
import 'system_owner_dashboard.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';

export '../services/auth_service.dart' show UserRole;

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a role'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
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

      AuthSession session;
      if (_selectedRole == UserRole.parent) {
        session = await AuthService.signInAsParent(
          studentNumber: emailOrStudentNumber,
          password: password,
        );
      } else {
        session = await AuthService.signInWithEmail(
          email: emailOrStudentNumber,
          password: password,
          expectedRole: _selectedRole,
        );
      }

      await AuthStorageService.saveSession(
        role: session.role,
        email: session.email,
        uid: session.uid,
        schoolId: session.schoolId,
        studentNumber: session.studentNumber,
      );

      if (!mounted) return;

      Widget target;
      switch (session.role) {
        case UserRole.parent:
          target = ParentDashboardScreen(
            phoneNumber: session.students.isNotEmpty
                ? (session.students.first.fatherPhone ??
                    session.students.first.motherPhone ??
                    '')
                : '',
            students: session.students,
          );
          break;
        case UserRole.systemOwner:
          target = const SystemOwnerDashboard();
          break;
        case UserRole.schoolAdmin:
        case UserRole.teacher:
          target = const HomeScreen();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
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
      body: Stack(
        children: [
          isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: const ThemeSwitcher(onAppBar: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: colorScheme.surface,
            child: _buildLoginForm(),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(48),
            color: colorScheme.primary,
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
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(48),
            color: colorScheme.surface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final onBrand = colorScheme.onPrimary;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.school_rounded,
            size: 64,
            color: onBrand,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Zenda',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: onBrand,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'School Attendance System',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: onBrand,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Streamline attendance management, parent communication, and student data with our modern, intuitive platform.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.isMobile ? 14 : 16,
            color: onBrand,
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
        _buildFeatureButton(icon: Icons.check_circle, label: 'Real-time Updates'),
        _buildFeatureButton(icon: Icons.shield, label: 'Secure & Reliable'),
        _buildFeatureButton(icon: Icons.desktop_windows, label: 'Multi-Platform'),
      ],
    );
  }

  Widget _buildFeatureButton({required IconData icon, required String label}) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onBrand.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: onBrand),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onBrand,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in to continue',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRoleSelection(),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.parent
                        ? 'Student Number'
                        : 'Email or Student Number',
                    hintText: _selectedRole == UserRole.parent
                        ? 'STD001'
                        : 'email@school.com',
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter ${_selectedRole == UserRole.parent ? "student number" : "email or student number"}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Demo Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDemoCredential('Owner', 'owner@school.com',
                          'owner123', UserRole.systemOwner),
                      _buildDemoCredential('Admin', 'admin@school.com',
                          'admin123', UserRole.schoolAdmin),
                      _buildDemoCredential('Teacher', 'teacher@school.com',
                          'teacher123', UserRole.teacher),
                      _buildDemoCredential(
                          'Parent', 'STD001', 'parent123', UserRole.parent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '\u00a92025 Zenda. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.outline,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedRole == role;
    final bg = isSelected
        ? colorScheme.primary.withValues(alpha: 0.1)
        : colorScheme.surfaceContainer;
    final border = isSelected ? colorScheme.primary : colorScheme.outlineVariant;
    final fg = isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

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
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredential(
      String role, String username, String password, UserRole userRole) {
    final colorScheme = Theme.of(context).colorScheme;
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
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Text(
                  '$role: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    '$username / $password',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
