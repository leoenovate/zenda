import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isVerifyingCode = false;
  String? _verificationId;
  final _codeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+250$phoneNumber';
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });

          String errorMessage = 'Verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number. Please check and try again.';
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _isVerifyingCode = true;
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
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

  Future<void> _verifyCode() async {
    if (_verificationId == null || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the verification code'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );

      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Invalid verification code. Please try again.';
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'The verification code is incorrect.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
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

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final List<Student> students =
            await FirebaseService.getStudentsByParentPhone(
          _phoneController.text.trim(),
        );

        if (!mounted) return;

        if (students.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'No students found associated with this phone number.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
          setState(() {
            _isLoading = false;
            _isVerifyingCode = false;
            _verificationId = null;
            _codeController.clear();
          });
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ParentDashboardScreen(
              phoneNumber: _phoneController.text.trim(),
              students: students,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing in: ${e.toString()}'),
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
                      _isVerifyingCode
                          ? 'Enter the verification code sent to your phone'
                          : 'Enter your phone number to view your child\'s attendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.isMobile ? 14 : 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacingXl),
                    if (!_isVerifyingCode) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '0781234567',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '+250 ',
                          prefixStyle:
                              TextStyle(color: colorScheme.onSurface),
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
                        onPressed: _isLoading ? null : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: context.isMobile ? 16 : 18,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary),
                                ),
                              )
                            : Text(
                                'Send Verification Code',
                                style: TextStyle(
                                  fontSize: context.isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: context.isMobile ? 24 : 28,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                        ),
                        maxLength: 6,
                      ),
                      SizedBox(height: context.spacingLg),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: context.isMobile ? 16 : 18,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary),
                                ),
                              )
                            : Text(
                                'Verify Code',
                                style: TextStyle(
                                  fontSize: context.isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      SizedBox(height: context.spacingMd),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isVerifyingCode = false;
                            _verificationId = null;
                            _codeController.clear();
                          });
                        },
                        child: const Text('Change Phone Number'),
                      ),
                    ],
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
