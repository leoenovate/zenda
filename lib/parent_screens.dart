import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:zenda/models/worker.dart';
import 'main.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> 
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _verificationController = TextEditingController();
  List<Worker> workers = [];
  Worker? matchedStudent;
  String? parentName;
  bool isLoading = false;
  bool showVerification = false;
  String? errorMessage;
  
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<double> _formAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _iconAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _formAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    _buttonAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    // Start animations after a short delay
    Timer(const Duration(milliseconds: 200), () {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _verificationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      
      setState(() {
        workers = jsonData
            .where((data) => data['LastName']?.isNotEmpty == true)
            .map((data) => Worker(
                  name: [
                    data['LastName'] ?? '',
                    data['middleName'] ?? '',
                    data['Firstname'] ?? ''
                  ].where((s) => s.isNotEmpty).join(' '),
                  period: (data['Class']?.toString().toLowerCase() ?? '')
                          .contains('night') 
                      ? 'Afternoon'
                      : 'Morning',
                  registrationNumber: data['Registration_Number'],
                  gender: data['Gender'],
                  birthdate: data['Birthdate'],
                  fatherName: data['Father_Names'],
                  fatherPhone: data['Father_PhoneNumber'],
                  motherName: data['Mother_Names'],
                  motherPhone: data['Mother_PhoneNumber'],
                  country: data['Country'],
                  province: data['Province'],
                  district: data['District'],
                  sector: data['Sector'],
                  cell: data['Cell'],
                  attendanceHistory: [],
                ))
            .toList();
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load student data';
      });
    }
  }

  void _verifyPhoneNumber() {
    final phoneNumber = _phoneController.text.trim();
    
    if (phoneNumber.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your phone number';
        return;
      });
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    // Always show verification screen regardless of whether the number exists
    // But search in the background to know if the number exists
    _findMatchingStudent(phoneNumber);
    
    // Simulate a delay for the verification code to be "sent"
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          isLoading = false;
          showVerification = true;
        });
      }
    });
  }
  
  void _findMatchingStudent(String phoneNumber) {
    // Search for matching parent phone number but don't show result yet
    final matchedWorker = workers.firstWhere(
      (worker) => 
        worker.fatherPhone == phoneNumber || 
        worker.motherPhone == phoneNumber,
      orElse: () => Worker(
        name: '',
        period: '',
        attendanceHistory: [],
      ),
    );
    
    if (matchedWorker.name.isNotEmpty) {
      matchedStudent = matchedWorker;
      parentName = matchedWorker.fatherPhone == phoneNumber
          ? matchedWorker.fatherName
          : matchedWorker.motherName;
    } else {
      matchedStudent = null;
      parentName = null;
    }
  }

  void _verifyCode() {
    final code = _verificationController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    
    // In a real app, you would verify this code against a backend
    // For demo purposes, we'll accept any 6-digit code
    if (code.length == 6 && RegExp(r'^\d+$').hasMatch(code)) {
      // Now check if the phone number actually exists in our system
      if (matchedStudent != null && matchedStudent!.name.isNotEmpty) {
        // Phone number exists, proceed to dashboard
        Navigator.pushReplacementNamed(
          context,
          '/parent-dashboard',
          arguments: {
            'parentName': parentName,
            'parentPhone': phoneNumber,
          },
        );
      } else {
        // Show error only after verification attempt
        setState(() {
          errorMessage = 'No student found with this parent phone number';
        });
      }
    } else {
      setState(() {
        errorMessage = 'Please enter a valid 6-digit code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Animated Icon
                    ScaleTransition(
                      scale: _iconAnimation,
                      child: FadeTransition(
                        opacity: _iconAnimation,
                        child: Icon(
                          Icons.family_restroom_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Animated Title
                    FadeTransition(
                      opacity: _formAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(_formAnimation),
                        child: Text(
                          'Parent Login',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Animated Form
                    FadeTransition(
                      opacity: _buttonAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(_buttonAnimation),
                        child: Card(
                          elevation: 4,
                          shadowColor: Theme.of(context).shadowColor.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!showVerification) ...[
                                  TextField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number',
                                      hintText: 'Enter your phone number',
                                      prefixIcon: const Icon(Icons.phone_rounded),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _verifyPhoneNumber,
                                      style: ElevatedButton.styleFrom(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.message_rounded, color: Colors.white),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Verify Phone Number',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                                if (showVerification) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.info_rounded,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Verification Required',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'A verification code has been sent to ${_phoneController.text}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _verificationController,
                                    decoration: InputDecoration(
                                      labelText: 'Verification Code',
                                      hintText: 'Enter 6-digit code',
                                      prefixIcon: const Icon(Icons.lock_rounded),
                                      helperText: 'For demo purposes, enter any 6 digits',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _verifyCode,
                                      style: ElevatedButton.styleFrom(
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login_rounded, color: Colors.white),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Verify Code',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        showVerification = false;
                                        _verificationController.clear();
                                        errorMessage = null;
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                    label: const Text('Back to Phone Entry'),
                                  ),
                                ],
                                if (errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Theme.of(context).colorScheme.error,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            errorMessage!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.error,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (!showVerification)
                      TextButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Welcome Screen'),
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

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> 
    with SingleTickerProviderStateMixin {
  List<Worker> children = [];
  bool isLoading = true;
  String? parentName;
  String? parentPhone;
  
  late AnimationController _controller;
  late Animation<double> _headerAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    
    _listAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    
    _loadChildren();
    
    // Start animations after data loads
    Timer(const Duration(milliseconds: 300), () {
      _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      
      // Get parent info from route arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      parentName = args?['parentName'];
      parentPhone = args?['parentPhone'];

      if (parentPhone == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        children = jsonData
            .where((data) => 
              (data['Father_PhoneNumber'] == parentPhone || 
               data['Mother_PhoneNumber'] == parentPhone) &&
              data['LastName']?.isNotEmpty == true)
            .map((data) => Worker(
                  name: [
                    data['LastName'] ?? '',
                    data['middleName'] ?? '',
                    data['Firstname'] ?? ''
                  ].where((s) => s.isNotEmpty).join(' '),
                  period: (data['Class']?.toString().toLowerCase() ?? '')
                          .contains('night') 
                      ? 'Afternoon'
                      : 'Morning',
                  registrationNumber: data['Registration_Number'],
                  gender: data['Gender'],
                  birthdate: data['Birthdate'],
                  fatherName: data['Father_Names'],
                  fatherPhone: data['Father_PhoneNumber'],
                  motherName: data['Mother_Names'],
                  motherPhone: data['Mother_PhoneNumber'],
                  country: data['Country'],
                  province: data['Province'],
                  district: data['District'],
                  sector: data['Sector'],
                  cell: data['Cell'],
                  attendanceHistory: [],
                ))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _viewAttendance(Worker child) {
    // Generate some sample attendance data if empty
    final attendanceData = child.attendanceHistory.isEmpty ? [
      Attendance(date: DateTime.now().subtract(const Duration(days: 6)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 5)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 4)), status: AttendanceStatus.late),
      Attendance(date: DateTime.now().subtract(const Duration(days: 3)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 2)), status: AttendanceStatus.absent),
      Attendance(date: DateTime.now().subtract(const Duration(days: 1)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now(), status: AttendanceStatus.present),
    ] : child.attendanceHistory;

    // Calculate attendance statistics
    int present = attendanceData.where((a) => a.status == AttendanceStatus.present).length;
    int late = attendanceData.where((a) => a.status == AttendanceStatus.late).length;
    int absent = attendanceData.where((a) => a.status == AttendanceStatus.absent).length;
    int total = attendanceData.length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: child.period == 'Afternoon'
                  ? const Color(0xFF1E88E5)
                  : const Color(0xFFF5F5F5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    child.period == 'Afternoon'
                        ? Icons.wb_sunny_rounded
                        : Icons.brightness_5_rounded,
                    color: child.period == 'Afternoon'
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFFF5F5F5),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${child.name} Attendance',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(context, present, total, 'Present', Colors.green),
                    Container(
                      height: 30,
                      width: 1,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    _buildStatColumn(context, late, total, 'Late', Colors.orange),
                    Container(
                      height: 30,
                      width: 1,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    _buildStatColumn(context, absent, total, 'Absent', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last 7 Days:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: attendanceData.take(7).map((attendance) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 60,
                              decoration: BoxDecoration(
                                color: switch (attendance.status) {
                                  AttendanceStatus.present => Colors.green.withOpacity(0.7),
                                  AttendanceStatus.late => Colors.orange.withOpacity(0.7),
                                  AttendanceStatus.absent => Colors.red.withOpacity(0.7),
                                },
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${attendance.date.day}/${attendance.date.month}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: attendanceData.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: switch (attendance.status) {
                              AttendanceStatus.present => Colors.green.withOpacity(0.1),
                              AttendanceStatus.late => Colors.orange.withOpacity(0.1),
                              AttendanceStatus.absent => Colors.red.withOpacity(0.1),
                            },
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            switch (attendance.status) {
                              AttendanceStatus.present => Icons.check_circle_rounded,
                              AttendanceStatus.late => Icons.access_time_rounded,
                              AttendanceStatus.absent => Icons.cancel_rounded,
                            },
                            color: switch (attendance.status) {
                              AttendanceStatus.present => Colors.green,
                              AttendanceStatus.late => Colors.orange,
                              AttendanceStatus.absent => Colors.red,
                            },
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${attendance.date.year}-${attendance.date.month.toString().padLeft(2, '0')}-${attendance.date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          switch (attendance.status) {
                            AttendanceStatus.present => 'Present',
                            AttendanceStatus.late => 'Late',
                            AttendanceStatus.absent => 'Absent',
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, int value, int total, String label, Color color) {
    double percentage = total > 0 ? (value / total * 100) : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Animated Header
                    FadeTransition(
                      opacity: _headerAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.2),
                          end: Offset.zero,
                        ).animate(_headerAnimation),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'My Children',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.logout_rounded),
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(context, '/parent-login');
                                    },
                                    tooltip: 'Logout',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Welcome, ${parentName ?? 'Parent'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Animated Content
                    Expanded(
                      child: FadeTransition(
                        opacity: _listAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(_listAnimation),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Theme.of(context).colorScheme.background,
                                  Theme.of(context).colorScheme.surface,
                                ],
                              ),
                            ),
                            child: children.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.child_care_rounded,
                                          size: 64,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No children found',
                                          style: Theme.of(context).textTheme.headlineSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Please contact the school administration',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                                          icon: const Icon(Icons.home_rounded),
                                          label: const Text('Go to Home Screen'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: children.length,
                                    itemBuilder: (context, index) {
                                      final child = children[index];
                                      return Hero(
                                        tag: 'child-${child.name}',
                                        child: Card(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          elevation: 4,
                                          shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border(
                                                left: BorderSide(
                                                  color: child.period == 'Afternoon'
                                                      ? const Color(0xFF1E88E5)
                                                      : const Color(0xFFF5F5F5),
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 16,
                                              ),
                                              leading: CircleAvatar(
                                                backgroundColor: child.period == 'Afternoon'
                                                    ? const Color(0xFF1E88E5).withOpacity(0.2)
                                                    : const Color(0xFFF5F5F5).withOpacity(0.2),
                                                radius: 28,
                                                child: Text(
                                                  child.name[0],
                                                  style: TextStyle(
                                                    color: child.period == 'Afternoon'
                                                        ? const Color(0xFF1E88E5)
                                                        : const Color(0xFFF5F5F5),
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                child.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              subtitle: Row(
                                                children: [
                                                  Icon(
                                                    child.period == 'Afternoon'
                                                        ? Icons.wb_sunny_rounded
                                                        : Icons.brightness_5_rounded,
                                                    color: child.period == 'Afternoon'
                                                        ? const Color(0xFF1E88E5)
                                                        : const Color(0xFFF5F5F5),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    child.period,
                                                    style: TextStyle(
                                                      color: child.period == 'Afternoon'
                                                          ? const Color(0xFF1E88E5)
                                                          : const Color(0xFFF5F5F5),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: ElevatedButton.icon(
                                                onPressed: () => _viewAttendance(child),
                                                icon: const Icon(Icons.visibility_rounded, size: 18),
                                                label: const Text('View'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
} 