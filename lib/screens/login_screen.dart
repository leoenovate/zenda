import 'package:flutter/material.dart';
import 'parent_dashboard_screen.dart';
import 'school_admin_dashboard.dart';
import 'system_owner_dashboard.dart';
import 'teacher_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';
import '../widgets/zenda_logo.dart';

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
  bool _rememberUser = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedUser() async {
    final identifier = await AuthStorageService.getLastLoginIdentifier();
    if (!mounted || identifier == null || identifier.isEmpty) return;
    setState(() {
      _emailController.text = identifier;
    });
  }

  Future<void> _login() async {
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
      if (_isStudentNumber(emailOrStudentNumber)) {
        session = await AuthService.signInAsParent(
          studentNumber: emailOrStudentNumber,
          password: password,
        );
      } else {
        session = await AuthService.signInWithEmail(
          email: emailOrStudentNumber,
          password: password,
        );
      }

      if (_rememberUser) {
        await AuthStorageService.saveLastLoginIdentifier(emailOrStudentNumber);
      } else {
        await AuthStorageService.clearLastLoginIdentifier();
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
            phoneNumber:
                session.students.isNotEmpty
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
          target = const SchoolAdminDashboard();
          break;
        case UserRole.teacher:
          target = const TeacherDashboardScreen();
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

  bool _isStudentNumber(String value) => !value.contains('@');

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
            child: SafeArea(child: const ThemeSwitcher(onAppBar: false)),
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
        ZendaLogo(
          size: context.isMobile ? 64 : 80,
          tone: ZendaLogoTone.onBrand,
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
        _buildFeatureButton(label: 'Real-time Updates'),
        _buildFeatureButton(label: 'Secure & Reliable'),
        _buildFeatureButton(label: 'Multi-Platform'),
      ],
    );
  }

  Widget _buildFeatureButton({required String label}) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onBrand.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: onBrand, shape: BoxShape.circle),
          ),
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
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
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
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Email or Student Number',
                    hintText: 'email@school.com or STD001',
                    prefixIcon: _FieldPrefix(label: 'ID'),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email or student number';
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
                    prefixIcon: _FieldPrefix(label: 'PW'),
                    suffixIcon: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(56, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(_obscurePassword ? 'Show' : 'Hide'),
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
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _rememberUser,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    'Remember this user',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged:
                      _isLoading
                          ? null
                          : (value) {
                            setState(() {
                              _rememberUser = value ?? true;
                            });
                          },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
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
                          : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                      Text(
                        'Demo Credentials',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDemoCredential(
                        'Owner',
                        'owner@school.com',
                        'owner123',
                      ),
                      _buildDemoCredential(
                        'Admin',
                        'admin@school.com',
                        'admin123',
                      ),
                      _buildDemoCredential(
                        'Teacher',
                        'teacher@school.com',
                        'teacher123',
                      ),
                      _buildDemoCredential('Parent', 'STD001', 'parent123'),
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
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCredential(String role, String username, String password) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
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
                Text(
                  'Tap',
                  style: TextStyle(fontSize: 11, color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPrefix extends StatelessWidget {
  final String label;

  const _FieldPrefix({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      widthFactor: 1,
      child: Container(
        width: 28,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
