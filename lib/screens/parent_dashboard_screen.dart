import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import '../services/firebase_service.dart';
import '../services/auth_storage_service.dart';
import 'chat_screen.dart';
import '../utils/responsive_builder.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String phoneNumber;
  final List<Student> students;

  const ParentDashboardScreen({
    Key? key,
    required this.phoneNumber,
    required this.students,
  }) : super(key: key);

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  Student? _selectedStudent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentsData();
  }

  Future<void> _loadStudentsData() async {
    try {
      final List<Student> updatedStudents = await FirebaseService.getStudentsByParentPhone(
        widget.phoneNumber,
      );
      
      setState(() {
        if (updatedStudents.isNotEmpty) {
          _selectedStudent = updatedStudents.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.students.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: const Text('Parent Portal'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No students found',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _logout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    final student = _selectedStudent ?? widget.students.first;
    final attendanceData = student.attendanceHistory.isEmpty
        ? []
        : student.attendanceHistory;

    // Calculate statistics
    final present = attendanceData
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final late = attendanceData.where((a) => a.status == AttendanceStatus.late).length;
    final absent =
        attendanceData.where((a) => a.status == AttendanceStatus.absent).length;
    final total = attendanceData.length;
    final presentPercentage = total > 0 ? (present / total * 100) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Parent Portal'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              if (student.id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      student: student,
                      userType: MessageSender.parent,
                      userName: student.fatherName ?? student.motherName ?? 'Parent',
                    ),
                  ),
                );
              }
            },
            tooltip: 'Chat with School',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Student selector
            if (widget.students.length > 1)
              Container(
                padding: EdgeInsets.all(context.spacingMd),
                color: const Color(0xFF2A2A2A),
                child: DropdownButtonFormField<Student>(
                  value: _selectedStudent ?? widget.students.first,
                  decoration: InputDecoration(
                    labelText: 'Select Child',
                    labelStyle: const TextStyle(color: Colors.white),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  items: widget.students.map((s) {
                    return DropdownMenuItem<Student>(
                      value: s,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (Student? newStudent) {
                    setState(() {
                      _selectedStudent = newStudent;
                    });
                  },
                ),
              ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.all(context.spacingMd),
                children: [
                  // Student info card
                  Card(
                    color: const Color(0xFF2A2A2A),
                    child: Padding(
                      padding: EdgeInsets.all(context.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: student.period == 'Morning'
                                    ? Colors.amber.shade800
                                    : Colors.blue,
                                radius: 30,
                                child: Text(
                                  student.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: context.spacingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: context.spacingXs),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.class_,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                        SizedBox(width: context.spacingXs),
                                        Text(
                                          student.period,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (student.registrationNumber != null) ...[
                                          SizedBox(width: context.spacingMd),
                                          Icon(
                                            Icons.badge,
                                            size: 16,
                                            color: Colors.grey.shade400,
                                          ),
                                          SizedBox(width: context.spacingXs),
                                          Text(
                                            student.registrationNumber!,
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: context.spacingMd),

                  // Statistics card
                  Card(
                    color: const Color(0xFF2A2A2A),
                    child: Padding(
                      padding: EdgeInsets.all(context.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance Statistics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: context.spacingMd),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Present',
                                  present,
                                  total,
                                  Colors.green,
                                  context,
                                ),
                              ),
                              SizedBox(width: context.spacingSm),
                              Expanded(
                                child: _buildStatCard(
                                  'Late',
                                  late,
                                  total,
                                  Colors.orange,
                                  context,
                                ),
                              ),
                              SizedBox(width: context.spacingSm),
                              Expanded(
                                child: _buildStatCard(
                                  'Absent',
                                  absent,
                                  total,
                                  Colors.red,
                                  context,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.spacingMd),
                          Container(
                            padding: EdgeInsets.all(context.spacingSm),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Overall Attendance Rate',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  '${presentPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: context.spacingMd),

                  // Recent attendance card
                  Card(
                    color: const Color(0xFF2A2A2A),
                    child: Padding(
                      padding: EdgeInsets.all(context.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Attendance',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: context.spacingMd),
                          attendanceData.isEmpty
                              ? Padding(
                                  padding: EdgeInsets.all(context.spacingMd),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 48,
                                          color: Colors.grey.shade600,
                                        ),
                                        SizedBox(height: context.spacingSm),
                                        Text(
                                          'No attendance records yet',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: attendanceData.length > 7
                                      ? 7
                                      : attendanceData.length,
                                  itemBuilder: (context, index) {
                                    final attendance = attendanceData[index];
                                    return _buildAttendanceItem(
                                      attendance,
                                      context,
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    int count,
    int total,
    Color color,
    BuildContext context,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Container(
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(Attendance attendance, BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (attendance.status) {
      case AttendanceStatus.present:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Present';
        break;
      case AttendanceStatus.late:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Late';
        break;
      case AttendanceStatus.absent:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(attendance.date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.spacingXs),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

