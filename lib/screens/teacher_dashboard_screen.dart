import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../services/firebase_service.dart';
import '../widgets/dashboard/attendance_dashboard.dart';
import '../widgets/theme/theme_switcher.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;
  bool _showingAllSchoolStudents = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = AuthService.currentSession;
      final students = await FirebaseService.getStudents();
      final teachers = await FirebaseService.getTeachers();
      final classes = await FirebaseService.getClasses();

      final teacherIds = <String>{
        if (session?.uid != null && session!.uid!.isNotEmpty) session.uid!,
        for (final teacher in teachers)
          if (teacher.email?.toLowerCase() == session?.email?.toLowerCase() &&
              teacher.id != null)
            teacher.id!,
      };

      final teacherName = session?.name?.trim().toLowerCase();
      final assignedClasses =
          classes.where((group) {
            final assignedById =
                group.teacherId != null && teacherIds.contains(group.teacherId);
            final assignedByName =
                teacherName != null &&
                teacherName.isNotEmpty &&
                group.teacherName?.trim().toLowerCase() == teacherName;
            return assignedById || assignedByName;
          }).toList();

      final assignedStudentIds =
          assignedClasses
              .expand((group) => group.studentIds)
              .where((id) => id.isNotEmpty)
              .toSet();

      final teacherStudents =
          assignedStudentIds.isEmpty
              ? students
              : students
                  .where((student) => assignedStudentIds.contains(student.id))
                  .toList();

      if (!mounted) return;
      setState(() {
        _students = teacherStudents;
        _filteredStudents = List.from(teacherStudents);
        _showingAllSchoolStudents = assignedStudentIds.isEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading teacher dashboard: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _filterStudents() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredStudents =
          _students.where((student) {
            return query.isEmpty ||
                student.name.toLowerCase().contains(query) ||
                (student.registrationNumber?.toLowerCase().contains(query) ??
                    false);
          }).toList();
    });
  }

  Future<void> _recordAttendance(
    Student student,
    AttendanceStatus status,
  ) async {
    final studentId = student.id;
    if (studentId == null) return;

    try {
      await FirebaseService.recordAttendance(
        studentId: studentId,
        date: DateTime.now(),
        status: status,
      );
      await _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} marked ${status.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording attendance: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          const ThemeSwitcher(onAppBar: true),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStudents,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_showingAllSchoolStudents)
                        _InfoBanner(
                          text:
                              'No class is linked to this teacher yet, so all school students are shown.',
                        ),
                      AttendanceDashboard(students: _students),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search assigned students',
                          filled: true,
                          fillColor: colorScheme.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_filteredStudents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              'No students found',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._filteredStudents.map(_buildStudentCard),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestAttendance =
        student.attendanceHistory.isEmpty
            ? null
            : student.attendanceHistory.reduce(
              (latest, next) => next.date.isAfter(latest.date) ? next : latest,
            );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(_initialFor(student.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        student.registrationNumber ?? 'No registration number',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (latestAttendance != null)
                  Chip(
                    label: Text(latestAttendance.status.name),
                    avatar: Icon(_iconFor(latestAttendance.status), size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AttendanceButton(
                  label: 'Present',
                  icon: Icons.check_circle_rounded,
                  onPressed:
                      () =>
                          _recordAttendance(student, AttendanceStatus.present),
                ),
                _AttendanceButton(
                  label: 'Late',
                  icon: Icons.schedule_rounded,
                  onPressed:
                      () => _recordAttendance(student, AttendanceStatus.late),
                ),
                _AttendanceButton(
                  label: 'Absent',
                  icon: Icons.cancel_rounded,
                  onPressed:
                      () => _recordAttendance(student, AttendanceStatus.absent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  IconData _iconFor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.late:
        return Icons.schedule_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.unknown:
        return Icons.help_rounded;
    }
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _AttendanceButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
