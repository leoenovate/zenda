import 'package:flutter/material.dart';
import 'parent_dashboard_screen.dart';
import '../services/firebase_service.dart';
import '../models/student.dart';
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loginWithPhone() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      final List<Student> students = await FirebaseService.getStudentsByParentPhone(
        phoneNumber,
      );

      if (!mounted) return;
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No students found associated with this phone number.',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParentDashboardScreen(
            phoneNumber: phoneNumber,
            students: students,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
                        Icons.family_restroom,
                        size: 48,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(height: context.spacingXl),
                    Text(
                      'Parent Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: context.spacingSm),
                    Text(
                      'Enter your phone number to view your child\'s attendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 14 : 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacingXl),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '0781234567',
                        prefixIcon: const Icon(Icons.phone),
                        prefixText: '+250 ',
                        prefixStyle: TextStyle(color: colorScheme.onSurface),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 9) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.spacingLg),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithPhone,
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
                                'Continue',
                                style: TextStyle(
                                  fontSize: context.isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                    SizedBox(height: context.spacingMd),
                    Text(
                      'Note: Use the phone number registered with the school',
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
