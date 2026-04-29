import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance.dart';
import '../../models/school.dart';
import '../../models/student.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import '../../widgets/student_form/add_student_dialog.dart';
import '../../widgets/student_form/student_form_stepper.dart';

/// Admin-list style screen for managing students. Reuses the existing
/// `AddStudentDialog` and `StudentFormStepper` for create/edit, plus an
/// inline attendance viewer.
class StudentsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const StudentsScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _isLoading = true;
  List<Student> _students = [];
  String _searchQuery = '';
  String _schoolFilter = 'all';
  String _genderFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final students = await FirebaseService.getStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  List<Student> get _filtered {
    return _students.where((s) {
      if (_genderFilter != 'all' && (s.gender ?? '') != _genderFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = s.name.toLowerCase().contains(q) ||
            (s.registrationNumber ?? '').toLowerCase().contains(q) ||
            (s.fatherPhone ?? '').toLowerCase().contains(q) ||
            (s.motherPhone ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    return AdminListScaffold(
      title: 'Students',
      subtitle: 'Manage student records, attendance and contacts',
      searchHint: 'Search by name, registration, or phone...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      extraFilters: [
        FilterOption(
          value: _genderFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All genders')),
            DropdownMenuItem(value: 'M', child: Text('Male')),
            DropdownMenuItem(value: 'F', child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _genderFilter = v ?? 'all'),
        ),
      ],
      addButtonLabel: 'Add Student',
      onAddPressed: _addStudent,
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.school_outlined,
              message: 'No students found',
            )
          : AdminListCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (_, i) => _buildRow(filtered[i]),
              ),
            ),
    );
  }

  Widget _buildRow(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial =
        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?';
    final subtitleParts = <String>[
      if ((student.registrationNumber ?? '').isNotEmpty)
        student.registrationNumber!,
      if (student.sessionIds.isNotEmpty)
        '${student.sessionIds.length} session${student.sessionIds.length == 1 ? '' : 's'}',
      if ((student.fatherPhone ?? '').isNotEmpty) student.fatherPhone!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.15),
            radius: 20,
            child: Text(
              initial,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.isEmpty ? '—' : subtitleParts.join(' · '),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'View attendance',
            onPressed: () => _viewAttendance(student),
          ),
          IconButton(
            icon: Icon(
              Icons.edit,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Edit',
            onPressed: () => _editStudent(student),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(student),
          ),
        ],
      ),
    );
  }

  void _addStudent() {
    showDialog(
      context: context,
      builder: (_) => AddStudentDialog(
        onStudentAdded: (s) async {
          await _load();
          widget.onDataChanged?.call();
        },
      ),
    );
  }

  void _editStudent(Student student) {
    final formData = <String, dynamic>{
      'name': student.name,
      'registrationNumber': student.registrationNumber ?? '',
      'gender': student.gender ?? 'M',
      'birthdate': student.birthdate ?? '',
      'sessionIds': student.sessionIds,
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
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Text('Edit Student'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogCtx),
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
                await FirebaseService.updateStudent(student.id!, {
                  'name': studentData['name'],
                  'sessionIds': List<String>.from(
                    (studentData['sessionIds'] as List?) ?? const <String>[],
                  ),
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
                  'fingerprintTimestamp':
                      studentData['fingerprintTimestamp'],
                });
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student updated')),
                );
                await _load();
                widget.onDataChanged?.call();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Delete "${student.name}"? This action cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (student.id == null) {
                  throw Exception('Student ID not found');
                }
                await FirebaseService.deleteStudent(student.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student deleted')),
                );
                await _load();
                widget.onDataChanged?.call();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewAttendance(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final attendance = student.attendanceHistory;
    final present = attendance
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final late =
        attendance.where((a) => a.status == AttendanceStatus.late).length;
    final absent =
        attendance.where((a) => a.status == AttendanceStatus.absent).length;
    final total = attendance.length;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${student.name} – Attendance',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (total == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No attendance records yet',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn(present, total, 'Present', Colors.green),
                      _statColumn(late, total, 'Late', Colors.orange),
                      _statColumn(absent, total, 'Absent', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: ListView.separated(
                      itemCount: attendance.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      itemBuilder: (_, i) {
                        final a = attendance[i];
                        final color = switch (a.status) {
                          AttendanceStatus.present => Colors.green,
                          AttendanceStatus.late => Colors.orange,
                          AttendanceStatus.absent => Colors.red,
                          _ => colorScheme.outline,
                        };
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            switch (a.status) {
                              AttendanceStatus.present => Icons.check_circle,
                              AttendanceStatus.late => Icons.access_time,
                              AttendanceStatus.absent => Icons.cancel,
                              _ => Icons.help_outline,
                            },
                            color: color,
                          ),
                          title: Text(
                            DateFormat('yyyy-MM-dd').format(a.date),
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            switch (a.status) {
                              AttendanceStatus.present => 'Present',
                              AttendanceStatus.late => 'Late',
                              AttendanceStatus.absent => 'Absent',
                              _ => 'Unknown',
                            },
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statColumn(int value, int total, String label, Color color) {
    final pct = total == 0 ? 0 : (value / total * 100);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$label · $value',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
