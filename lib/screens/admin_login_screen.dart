import 'package:flutter/material.dart';
import 'school_admin_dashboard.dart';
import 'system_owner_dashboard.dart';
import 'teacher_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session = await AuthService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await AuthStorageService.saveSession(
        role: session.role,
        email: session.email,
        uid: session.uid,
        schoolId: session.schoolId,
      );

      if (!mounted) return;
      final target = _dashboardForRole(session.role);
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
          duration: const Duration(seconds: 4),
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

  Widget _dashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.systemOwner:
        return const SystemOwnerDashboard();
      case UserRole.teacher:
        return const TeacherDashboardScreen();
      case UserRole.schoolAdmin:
      case UserRole.parent:
      case null:
        return const SchoolAdminDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: const [ThemeSwitcher(onAppBar: false)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.screenPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isDesktop ? 500 : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(height: context.spacingXl),
                    Text(
                      'Admin Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: context.spacingSm),
                    Text(
                      'Sign in to manage student attendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 14 : 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacingXl),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.spacingMd),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                    SizedBox(height: context.spacingMd),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: context.isMobile ? 16 : 18,
                        ),
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
                              : Text(
                                'Login with Email',
                                style: TextStyle(
                                  fontSize: context.isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                    SizedBox(height: context.spacingMd),
                    Text(
                      'Note: Contact your administrator if you need an account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 12 : 14,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
