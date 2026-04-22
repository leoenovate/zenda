import 'package:flutter/material.dart';
import 'dart:async';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../widgets/student_form/add_student_dialog.dart';
import '../widgets/student_form/student_form_stepper.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../widgets/dashboard/attendance_dashboard.dart';
import '../widgets/theme/theme_switcher.dart';
import 'chat_list_screen.dart';
import '../utils/responsive_builder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Student> students = [];
  List<Student> filteredStudents = [];
  bool _isLoading = true;
  
  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  String? selectedPeriod;
  String? selectedGender;
  DateTime? selectedDate;
  String? selectedAttendanceStatus;
  
  // Animation controllers
  late AnimationController _controller;
  late Animation<double> _headerAnimation;
  late Animation<double> _searchAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_filterStudents);
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    
    _searchAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    
    _listAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    
    // Start animations after a short delay
    Timer(const Duration(milliseconds: 300), () {
      _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Check if Firebase is initialized
      if (!Firebase.apps.isNotEmpty) {
        // Wait for Firebase to initialize if it's not ready yet
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      final List<Student> loadedStudents = await FirebaseService.getStudents();
      
      if (!mounted) return;
      setState(() {
        students = loadedStudents;
        filteredStudents = List.from(students);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      
      // Show a more descriptive error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading students: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: _loadStudents,
          ),
        ),
      );
    }
  }
  
  void _filterStudents() {
    setState(() {
      filteredStudents = students.where((student) {
        // Search by name, registration number
        final query = _searchController.text.toLowerCase();
        final matchesSearch = query.isEmpty || 
            student.name.toLowerCase().contains(query) || 
            (student.registrationNumber?.toLowerCase().contains(query) ?? false);
        
        // Filter by period (class)
        final matchesPeriod = selectedPeriod == null || student.period == selectedPeriod;
        
        // Filter by gender
        final matchesGender = selectedGender == null || student.gender == selectedGender;
        
        // Filter by attendance date
        bool matchesDate = true;
        if (selectedDate != null && student.attendanceHistory.isNotEmpty) {
          matchesDate = student.attendanceHistory.any((attendance) => 
            attendance.date.year == selectedDate!.year && 
            attendance.date.month == selectedDate!.month && 
            attendance.date.day == selectedDate!.day);
        }
        
        // Filter by attendance status
        bool matchesStatus = true;
        if (selectedAttendanceStatus != null && student.attendanceHistory.isNotEmpty) {
          AttendanceStatus status;
          switch (selectedAttendanceStatus) {
            case 'Present':
              status = AttendanceStatus.present;
              break;
            case 'Late':
              status = AttendanceStatus.late;
              break;
            case 'Absent':
              status = AttendanceStatus.absent;
              break;
            default:
              status = AttendanceStatus.present;
          }
          matchesStatus = student.attendanceHistory.any((attendance) => 
            attendance.status == status);
        }
        
        return matchesSearch && matchesPeriod && matchesGender && matchesDate && matchesStatus;
      }).toList();
    });
  }
  
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      selectedPeriod = null;
      selectedGender = null;
      selectedDate = null;
      selectedAttendanceStatus = null;
      filteredStudents = List.from(students);
    });
  }

  void _editStudent(int index) {
    final student = students[index];
    final Map<String, dynamic> formData = {
      'name': student.name,
      'registrationNumber': student.registrationNumber ?? '',
      'gender': student.gender ?? 'M',
      'birthdate': student.birthdate ?? '',
      'period': student.period,
      'fatherName': student.fatherName ?? '',
      'fatherPhone': student.fatherPhone ?? '',
      'motherName': student.motherName ?? '',
      'motherPhone': student.motherPhone ?? '',
      'country': student.country ?? '',
      'province': student.province ?? '',
      'district': student.district ?? '',
      'sector': student.sector ?? '',
      'cell': student.cell ?? '',
      'fingerprintData': student.fingerprintData,
      'fingerprintTimestamp': student.fingerprintTimestamp,
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('Edit Student'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: StudentFormStepper(
            initialData: formData,
            onSubmit: (studentData) async {
              try {
                // Update in Firebase
                await FirebaseService.updateStudent(
                  student.id!,
                  {
                    'name': studentData['name'],
                    'period': studentData['period'],
                    'registrationNumber': studentData['registrationNumber'],
                    'gender': studentData['gender'],
                    'birthdate': studentData['birthdate'],
                    'fatherName': studentData['fatherName'],
                    'fatherPhone': studentData['fatherPhone'],
                    'motherName': studentData['motherName'],
                    'motherPhone': studentData['motherPhone'],
                    'country': studentData['country'],
                    'province': studentData['province'],
                    'district': studentData['district'],
                    'sector': studentData['sector'],
                    'cell': studentData['cell'],
                    'fingerprintData': studentData['fingerprintData'],
                    'fingerprintTimestamp': studentData['fingerprintTimestamp'],
                  }
                );

                // Update local state
                setState(() {
                  students[index] = Student(
                    id: student.id,
                    name: studentData['name'],
                    period: studentData['period'],
                    registrationNumber: studentData['registrationNumber'],
                    gender: studentData['gender'],
                    birthdate: studentData['birthdate'],
                    fatherName: studentData['fatherName'],
                    fatherPhone: studentData['fatherPhone'],
                    motherName: studentData['motherName'],
                    motherPhone: studentData['motherPhone'],
                    country: studentData['country'],
                    province: studentData['province'],
                    district: studentData['district'],
                    sector: studentData['sector'],
                    cell: studentData['cell'],
                    fingerprintData: studentData['fingerprintData'],
                    fingerprintTimestamp: studentData['fingerprintTimestamp'],
                    attendanceHistory: student.attendanceHistory,
                  );
                  _filterStudents(); // Refresh filtered list
                });

                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating student: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _deleteStudent(int index) {
    final student = students[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete from Firebase
                if (student.id == null) {
                  throw Exception('Student ID not found');
                }
                await FirebaseService.deleteStudent(student.id!);
                
                setState(() {
                  students.removeAt(index);
                  _filterStudents();
                });
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting student: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewAttendance(Student student) {
    final attendanceData = student.attendanceHistory.isEmpty ? [
      Attendance(date: DateTime.now().subtract(const Duration(days: 6)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 5)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 4)), status: AttendanceStatus.late),
      Attendance(date: DateTime.now().subtract(const Duration(days: 3)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 2)), status: AttendanceStatus.absent),
      Attendance(date: DateTime.now().subtract(const Duration(days: 1)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now(), status: AttendanceStatus.present),
    ] : student.attendanceHistory;

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
              color: student.period == 'Afternoon'
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.outlineVariant,
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
                    student.period == 'Afternoon'
                        ? Icons.wb_sunny
                        : Icons.brightness_5,
                    color: student.period == 'Afternoon'
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${student.name} Attendance',
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
                                  _ => Colors.grey.withOpacity(0.7),
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
                              _ => Colors.grey.withOpacity(0.1),
                            },
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            switch (attendance.status) {
                              AttendanceStatus.present => Icons.check_circle,
                              AttendanceStatus.late => Icons.access_time,
                              AttendanceStatus.absent => Icons.cancel,
                              _ => Icons.help_outline,
                            },
                            color: switch (attendance.status) {
                              AttendanceStatus.present => Colors.green,
                              AttendanceStatus.late => Colors.orange,
                              AttendanceStatus.absent => Colors.red,
                              _ => Colors.grey,
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
                            _ => 'Unknown',
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

  void _addStudent() {
    showDialog(
      context: context,
      builder: (context) => AddStudentDialog(
        onStudentAdded: (student) {
          setState(() {
            students.add(student);
            _filterStudents();
          });
        },
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.signOut();
    } catch (_) {}
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          students: students,
          userType: MessageSender.school, // School staff perspective
          userName: 'School Admin',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: _isLoading
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
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.spacingMd, 
                          context.spacingSm, 
                          context.spacingMd, 
                          context.spacingSm
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // App title with adaptive layout
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.school_rounded,
                                      color: colorScheme.onPrimary,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: context.spacingSm),
                                  Expanded(
                                    child: Text(
                                      'School Attendance System',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: context.isMobile ? 18 : 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const ThemeSwitcher(onAppBar: false),
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  color: colorScheme.onSurface,
                                  onPressed: _isLoading ? null : _navigateToChat,
                                  tooltip: 'Chat with Parents',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.analytics_outlined),
                                  color: colorScheme.onSurface,
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/api-logs');
                                  },
                                  tooltip: 'API Logs',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout),
                                  color: colorScheme.onSurface,
                                  onPressed: _logout,
                                  tooltip: 'Logout',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Animated Search - Adaptive to screen size
                  FadeTransition(
                    opacity: _searchAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.2),
                        end: Offset.zero,
                      ).animate(_searchAnimation),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.spacingMd, 
                          context.spacingXs, 
                          context.spacingMd, 
                          context.spacingMd
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(color: colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    hintText: context.screenWidth < 400
                                        ? 'Search students...'
                                        : 'Search by name or registration number',
                                    hintStyle: TextStyle(
                                        color: colorScheme.onSurfaceVariant),
                                    prefixIcon: Icon(Icons.search,
                                        color: colorScheme.onSurfaceVariant),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: context.spacingSm),
                            IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: colorScheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  builder: (context) =>
                                      _buildFilterBottomSheet(context),
                                );
                              },
                              icon: Icon(Icons.filter_list,
                                  color: colorScheme.onSurface),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.surfaceContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Animated Content with responsive layout
                  Expanded(
                    child: FadeTransition(
                      opacity: _listAnimation,
                      child: filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: context.isMobile ? 48 : 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                SizedBox(height: context.spacingMd),
                                Text(
                                  'No students match your filters',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: context.spacingMd),
                                ElevatedButton.icon(
                                  onPressed: _resetFilters,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reset Filters'),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.isMobile ? 4 : 8, 
                                  vertical: 0
                                ),
                                itemCount: filteredStudents.length + 1, // +1 for the dashboard
                                itemBuilder: (context, index) {
                                  // Show dashboard at the top - adapts to screen size
                                  if (index == 0) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(_headerAnimation),
                                      child: FadeTransition(
                                        opacity: _headerAnimation,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.isMobile ? 8 : 16,
                                          ),
                                          child: AttendanceDashboard(students: students),
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  // Adjust index for student items
                                  final studentIndex = index - 1;
                                  final student = filteredStudents[studentIndex];
                                  
                                  // Create a staggered animation for each list item
                                  return AnimatedBuilder(
                                    animation: _listAnimation,
                                    builder: (context, child) {
                                      final itemAnimation = Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _controller,
                                          curve: Interval(
                                            0.3 + (studentIndex * 0.05).clamp(0.0, 0.5),
                                            0.6 + (studentIndex * 0.05).clamp(0.0, 0.5),
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      );
                                      
                                      return FadeTransition(
                                        opacity: itemAnimation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.2),
                                            end: Offset.zero,
                                          ).animate(itemAnimation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: EdgeInsets.fromLTRB(
                                        context.isMobile ? 8 : 16,
                                        0,
                                        context.isMobile ? 8 : 16,
                                        context.spacingSm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: _buildStudentListItem(student),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FadeTransition(
        opacity: _listAnimation,
        child: ScaleTransition(
          scale: _listAnimation,
          child: FloatingActionButton(
            onPressed: _addStudent,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStudentListItem(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final periodAccent = student.period == 'Afternoon'
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;
    return Stack(
      children: [
        if (student.period == 'Afternoon')
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: colorScheme.secondary,
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.fromLTRB(
              20, 12, context.isMobile ? 8 : 12, 12),
          leading: CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHigh,
            radius: context.isMobile ? 20 : 24,
            child: Text(
              student.name[0].toUpperCase(),
              style: TextStyle(
                color: periodAccent,
                fontSize: context.isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            student.name.toUpperCase(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: context.isMobile ? 14 : 16,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Icon(
                Icons.brightness_5_rounded,
                color: periodAccent,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                student.period,
                style: TextStyle(
                  color: periodAccent,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              if (student.gender != null && context.screenWidth > 320)
                Icon(
                  student.gender == 'M'
                      ? Icons.male_rounded
                      : Icons.female_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 14,
                ),
            ],
          ),
          trailing: context.isMobile
              ? _buildCompactActions(student)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.visibility_rounded,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      iconColor: colorScheme.primary,
                      onTap: () => _viewAttendance(student),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      iconColor: colorScheme.primary,
                      onTap: () => _editStudent(students.indexOf(student)),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete_rounded,
                      color: colorScheme.error.withValues(alpha: 0.15),
                      iconColor: colorScheme.error,
                      onTap: () => _deleteStudent(students.indexOf(student)),
                    ),
                  ],
                ),
          onTap: context.isMobile ? () => _showStudentActions(student) : null,
        ),
      ],
    );
  }

  Widget _buildCompactActions(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
      onPressed: () => _showStudentActions(student),
    );
  }
  
  // Show actions in a bottom sheet for mobile view
  void _showStudentActions(Student student) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_rounded),
              title: const Text('View Attendance'),
              onTap: () {
                Navigator.pop(context);
                _viewAttendance(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Student'),
              onTap: () {
                Navigator.pop(context);
                _editStudent(students.indexOf(student));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete Student',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteStudent(students.indexOf(student));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: iconColor ?? onSurface,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterBottomSheet(BuildContext context) {
    String? tempPeriod = selectedPeriod;
    String? tempGender = selectedGender;
    DateTime? tempDate = selectedDate;
    String? tempAttendanceStatus = selectedAttendanceStatus;
    
    return StatefulBuilder(
      builder: (context, setModalState) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Students',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Filter options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Class',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Morning',
                          isSelected: tempPeriod == 'Morning',
                          onTap: () {
                            setModalState(() {
                              tempPeriod = tempPeriod == 'Morning' ? null : 'Morning';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Afternoon',
                          isSelected: tempPeriod == 'Afternoon',
                          onTap: () {
                            setModalState(() {
                              tempPeriod = tempPeriod == 'Afternoon' ? null : 'Afternoon';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Gender',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Male',
                          isSelected: tempGender == 'M',
                          onTap: () {
                            setModalState(() {
                              tempGender = tempGender == 'M' ? null : 'M';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Female',
                          isSelected: tempGender == 'F',
                          onTap: () {
                            setModalState(() {
                              tempGender = tempGender == 'F' ? null : 'F';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Attendance Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Present',
                          isSelected: tempAttendanceStatus == 'Present',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Present' ? null : 'Present';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Late',
                          isSelected: tempAttendanceStatus == 'Late',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Late' ? null : 'Late';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Absent',
                          isSelected: tempAttendanceStatus == 'Absent',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Absent' ? null : 'Absent';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Date',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: tempDate != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: tempDate != null
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempDate != null
                                        ? DateFormat('yyyy-MM-dd').format(tempDate!)
                                        : 'Select a date',
                                    style: TextStyle(
                                      color: tempDate != null
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: tempDate != null
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (tempDate != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setModalState(() {
                                tempDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Apply button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            tempPeriod = null;
                            tempGender = null;
                            tempDate = null;
                            tempAttendanceStatus = null;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedPeriod = tempPeriod;
                            selectedGender = tempGender;
                            selectedDate = tempDate;
                            selectedAttendanceStatus = tempAttendanceStatus;
                            _filterStudents();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
} 