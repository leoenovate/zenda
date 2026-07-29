import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/device_enrollment.dart';
import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/student.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/device_enrollment_lookup_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
import '../../utils/responsive_builder.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import '../../widgets/admin/enrolled_badge.dart';
import '../../widgets/admin/enrollment_participant.dart';
import '../../widgets/admin/person_device_enroll_dialog.dart';
import '../../widgets/admin/student_attendance_dialog.dart';
import '../../widgets/admin/student_fingerprint_dialog.dart';
import 'custom_roles_screen.dart';

const String _kindStudent = 'student';
const String _kindParent = 'parent';

/// Unified roster of every person in the school with Enroll and View
/// attendance actions on each row.
class AllPeopleScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const AllPeopleScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
  });

  @override
  State<AllPeopleScreen> createState() => _AllPeopleScreenState();
}

class _SchoolPerson {
  final String kind;
  final String id;
  final String name;
  final String? subtitle;
  final List<String?> cardCandidates;
  final Student? student;
  final Teacher? teacher;
  final Worker? worker;
  final app_user.AppUser? user;

  /// Guardian (parent) login account, when [kind] == `parent`.
  final app_user.AppUser? parent;

  const _SchoolPerson({
    required this.kind,
    required this.id,
    required this.name,
    this.subtitle,
    this.cardCandidates = const [],
    this.student,
    this.teacher,
    this.worker,
    this.user,
    this.parent,
  });

  bool get canEnrollOnDevice =>
      kind == AuthRoles.kindTeacher ||
      kind == AuthRoles.kindWorker ||
      kind == AuthRoles.kindAdmin ||
      kind == AuthRoles.kindStaff;

  bool get canEnrollFingerprint => kind == _kindStudent;

  bool get canEnroll => canEnrollOnDevice || canEnrollFingerprint;

  bool get canViewAttendance => kind == _kindStudent || kind == _kindParent;
}

class _AllPeopleScreenState extends State<AllPeopleScreen> {
  bool _isLoading = true;
  List<_SchoolPerson> _people = [];
  List<Device> _devices = [];
  Map<String, Set<int>> _usedSlotsByDevice = {};
  String _searchQuery = '';
  String _kindFilter = 'all';
  DeviceEnrollmentLookup _enrollments = const DeviceEnrollmentLookup.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getStudents(),
        FirebaseService.getTeachers(),
        FirebaseService.getWorkers(),
        FirebaseService.getUsers(),
        FirebaseService.getGuardians(),
        FirebaseService.getDevices(),
        FirebaseService.getRoles(),
        FirebaseService.getDeviceEnrollments(),
      ]);
      if (!mounted) return;

      final students = results[0] as List<Student>;
      final teachers = results[1] as List<Teacher>;
      final workers = results[2] as List<Worker>;
      final users = results[3] as List<app_user.AppUser>;
      final parents = results[4] as List<app_user.AppUser>;
      final devices = results[5] as List<Device>;
      final roles = results[6] as List<Role>;
      final allEnrollments = results[7] as List<DeviceEnrollment>;

      final roleNames = {
        for (final r in roles)
          if (r.id != null) r.id!: r.name,
      };

      final usedSlots = <String, Set<int>>{};
      for (final e in allEnrollments) {
        usedSlots.putIfAbsent(e.deviceId, () => {}).add(e.slotId);
      }

      setState(() {
        _people = _buildPeople(
          students: students,
          teachers: teachers,
          workers: workers,
          users: users,
          parents: parents,
          roleNames: roleNames,
        );
        _devices = devices;
        _usedSlotsByDevice = usedSlots;
        _isLoading = false;
      });
      unawaited(_loadEnrollments(devices));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading people: $e')),
      );
    }
  }

  Future<void> _loadEnrollments(List<Device> devices) async {
    try {
      final lookup = await DeviceEnrollmentLookup.fetch(devices);
      if (!mounted) return;
      setState(() => _enrollments = lookup);
    } catch (_) {}
  }

  List<_SchoolPerson> _buildPeople({
    required List<Student> students,
    required List<Teacher> teachers,
    required List<Worker> workers,
    required List<app_user.AppUser> users,
    required List<app_user.AppUser> parents,
    required Map<String, String> roleNames,
  }) {
    final out = <_SchoolPerson>[];

    for (final s in students) {
      if (s.id == null) continue;
      out.add(
        _SchoolPerson(
          kind: _kindStudent,
          id: s.id!,
          name: s.name,
          subtitle: [
            if ((s.registrationNumber ?? '').isNotEmpty) s.registrationNumber!,
            if ((s.fatherPhone ?? '').isNotEmpty) s.fatherPhone!,
          ].join(' · '),
          student: s,
        ),
      );
    }

    for (final t in teachers) {
      if (t.id == null) continue;
      final roleName = t.roleId != null ? roleNames[t.roleId!] : null;
      out.add(
        _SchoolPerson(
          kind: AuthRoles.kindTeacher,
          id: t.id!,
          name: t.name,
          subtitle: [
            if ((t.subject ?? '').isNotEmpty) t.subject!,
            if (roleName != null) roleName,
            if ((t.phone ?? '').isNotEmpty) t.phone!,
          ].where((x) => x.isNotEmpty).join(' · '),
          cardCandidates: [t.employeeId, t.id],
          teacher: t,
        ),
      );
    }

    for (final w in workers) {
      if (w.id == null) continue;
      final roleName = w.roleId != null ? roleNames[w.roleId!] : null;
      out.add(
        _SchoolPerson(
          kind: AuthRoles.kindWorker,
          id: w.id!,
          name: w.name,
          subtitle: [
            if (roleName != null) roleName,
            if ((w.phone ?? '').isNotEmpty) w.phone!,
          ].where((x) => x.isNotEmpty).join(' · '),
          cardCandidates: [w.employeeId, w.id],
          worker: w,
        ),
      );
    }

    for (final u in users) {
      if (u.id == null) continue;
      final kind = AuthRoles.kindForUserRole(u.role);
      if (kind == null) continue;
      final sid = u.schoolId;
      if (sid == null || sid.isEmpty) continue;
      final displayName =
          (u.name != null && u.name!.trim().isNotEmpty)
              ? u.name!.trim()
              : u.email;
      final roleName = u.roleId != null ? roleNames[u.roleId!] : null;
      out.add(
        _SchoolPerson(
          kind: kind,
          id: u.id!,
          name: displayName,
          subtitle: [
            if (roleName != null) roleName,
            u.email,
            if ((u.phone ?? '').isNotEmpty) u.phone!,
          ].where((x) => x.isNotEmpty).join(' · '),
          cardCandidates: [u.id],
          user: u,
        ),
      );
    }

    for (final p in parents) {
      if (p.id == null) continue;
      out.add(
        _SchoolPerson(
          kind: _kindParent,
          id: p.id!,
          name: (p.name != null && p.name!.trim().isNotEmpty)
              ? p.name!.trim()
              : (p.phone ?? '(guardian)'),
          subtitle: [
            if ((p.phone ?? '').isNotEmpty) p.phone!,
            if (p.email.isNotEmpty) p.email,
            '${p.linkedStudentIds.length} children',
          ].where((x) => x.isNotEmpty).join(' · '),
          parent: p,
        ),
      );
    }

    out.sort((a, b) {
      final kindOrder = _kindSortIndex(a.kind).compareTo(_kindSortIndex(b.kind));
      if (kindOrder != 0) return kindOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  int _kindSortIndex(String kind) {
    const order = [
      _kindStudent,
      AuthRoles.kindTeacher,
      AuthRoles.kindWorker,
      AuthRoles.kindAdmin,
      AuthRoles.kindStaff,
      _kindParent,
    ];
    final idx = order.indexOf(kind);
    return idx < 0 ? order.length : idx;
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case _kindStudent:
        return 'Student';
      case _kindParent:
        return 'Parent';
      case AuthRoles.kindTeacher:
        return 'Teacher';
      case AuthRoles.kindWorker:
        return 'Worker';
      case AuthRoles.kindAdmin:
        return 'Admin';
      case AuthRoles.kindStaff:
        return 'Staff';
      default:
        return kind;
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case _kindStudent:
        return Icons.school_outlined;
      case _kindParent:
        return Icons.family_restroom_outlined;
      case AuthRoles.kindTeacher:
        return Icons.person_outlined;
      case AuthRoles.kindWorker:
        return Icons.engineering_outlined;
      case AuthRoles.kindAdmin:
        return Icons.admin_panel_settings_outlined;
      case AuthRoles.kindStaff:
        return Icons.badge_outlined;
      default:
        return Icons.person_outline;
    }
  }

  List<_SchoolPerson> get _filtered {
    return _people.where((p) {
      if (_kindFilter != 'all') {
        if (_kindFilter == 'admins') {
          if (p.kind != AuthRoles.kindAdmin && p.kind != AuthRoles.kindStaff) {
            return false;
          }
        } else if (p.kind != _kindFilter) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            p.name.toLowerCase().contains(q) ||
            (p.subtitle ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  String get _schoolId =>
      widget.schools.isNotEmpty ? (widget.schools.first.id ?? '') : '';

  void _openCustomRoles() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (routeCtx) => Scaffold(
              appBar: AppBar(title: const Text('Roles')),
              body: CustomRolesScreen(
                schools: widget.schools,
                onDataChanged: () {
                  _load();
                  widget.onDataChanged?.call();
                },
                showSchoolFilter: false,
              ),
            ),
      ),
    );
  }

  Future<void> _enroll(_SchoolPerson person) async {
    if (person.kind == _kindParent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint enrollment is available for students and school staff only.',
          ),
        ),
      );
      return;
    }

    if (!person.canEnroll) return;

    if (person.kind == _kindStudent && person.student != null) {
      final saved = await showStudentFingerprintDialog(
        context: context,
        student: person.student!,
      );
      if (saved) {
        await _load();
        widget.onDataChanged?.call();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint saved')),
        );
      }
      return;
    }

    EnrollmentParticipant? participant;
    if (person.teacher != null && person.teacher!.isActive) {
      participant = EnrollmentParticipant.fromTeacher(person.teacher!);
    } else if (person.worker != null && person.worker!.isActive) {
      participant = EnrollmentParticipant.fromWorker(person.worker!);
    } else if (person.user != null && person.user!.isActive) {
      participant = EnrollmentParticipant.fromAdminUser(person.user!);
    }
    if (participant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This person is inactive or missing an ID')),
      );
      return;
    }

    final result = await showPersonDeviceEnrollDialog(
      context: context,
      participant: participant,
      devices: _devices,
      schoolId: _schoolId,
      usedSlotsByDevice: _usedSlotsByDevice,
    );
    if (result != null) {
      await _load();
      widget.onDataChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${person.name} enrolled successfully')),
      );
    }
  }

  List<Student> _linkedStudentsForParent(app_user.AppUser parent) {
    if (parent.linkedStudentIds.isEmpty) return const [];
    final ids = parent.linkedStudentIds.toSet();
    return _people
        .where((p) => p.student?.id != null && ids.contains(p.student!.id))
        .map((p) => p.student!)
        .toList();
  }

  Future<void> _viewAttendance(_SchoolPerson person) async {
    if (person.kind == _kindStudent && person.student != null) {
      await showStudentAttendanceDialog(context, person.student!);
      return;
    }

    if (person.kind == _kindParent && person.parent != null) {
      final linked = _linkedStudentsForParent(person.parent!);
      if (linked.isEmpty) {
        await _showAttendanceUnavailableDialog(
          person.name,
          'No linked students with attendance records were found for this parent.',
        );
        return;
      }
      if (linked.length == 1) {
        await showStudentAttendanceDialog(context, linked.first);
        return;
      }
      final picked = await showDialog<Student>(
        context: context,
        builder: (dialogCtx) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;
          return AlertDialog(
            title: Text('${person.name} – linked students'),
            content: SizedBox(
              width: 360,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: linked.length,
                separatorBuilder:
                    (_, __) => Divider(
                      height: 1,
                      color: colorScheme.outlineVariant,
                    ),
                itemBuilder: (_, i) {
                  final student = linked[i];
                  return ListTile(
                    title: Text(student.name),
                    subtitle: Text(student.registrationNumber ?? '—'),
                    onTap: () => Navigator.pop(dialogCtx, student),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
      if (picked != null && mounted) {
        await showStudentAttendanceDialog(context, picked);
      }
      return;
    }

    await _showAttendanceUnavailableDialog(
      person.name,
      'Attendance history is recorded for students only.',
    );
  }

  Future<void> _showAttendanceUnavailableDialog(
    String personName,
    String message,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: Text('$personName – Attendance'),
            content: Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;

    return AdminListScaffold(
      title: 'People',
      subtitle: 'Everyone in your school — enroll fingerprints and view attendance',
      searchHint: 'Search by name, phone, or registration...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: 'all',
      onSchoolFilterChanged: (_) {},
      showSchoolFilter: false,
      extraFilters: [
        FilterOption(
          value: _kindFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All kinds')),
            DropdownMenuItem(value: _kindStudent, child: Text('Students')),
            DropdownMenuItem(
              value: AuthRoles.kindTeacher,
              child: Text('Teachers'),
            ),
            DropdownMenuItem(
              value: AuthRoles.kindWorker,
              child: Text('Workers'),
            ),
            DropdownMenuItem(value: 'admins', child: Text('Admins')),
            DropdownMenuItem(value: _kindParent, child: Text('Parents')),
          ],
          onChanged: (v) => setState(() => _kindFilter = v ?? 'all'),
        ),
      ],
      headerExtras: OutlinedButton.icon(
        onPressed: _openCustomRoles,
        icon: const Icon(Icons.badge_outlined, size: 18),
        label: const Text('Custom roles'),
      ),
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.groups_outlined,
                message: 'No people found',
              )
              : AdminListCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                  itemBuilder: (_, i) => _buildRow(filtered[i], isMobile),
                ),
              ),
    );
  }

  Widget _buildRow(_SchoolPerson person, bool isMobile) {
    final colorScheme = Theme.of(context).colorScheme;
    final hits = _enrollments.findEnrollments(person.cardCandidates);
    final enrollTooltip =
        person.kind == _kindParent
            ? 'Enrollment is for students and staff only'
            : 'Enroll fingerprint';
    final attendanceTooltip =
        person.kind == _kindStudent
            ? 'View attendance'
            : person.kind == _kindParent
            ? 'View linked student attendance'
            : 'View attendance info';

    return Padding(
      key: ValueKey('person-${person.kind}-${person.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              _kindIcon(person.kind),
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _kindLabel(person.kind),
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hits.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      EnrolledBadge(enrollments: hits),
                    ],
                  ],
                ),
                if ((person.subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    person.subtitle!,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isMobile) ...[
            Tooltip(
              message: enrollTooltip,
              child: IconButton(
                icon: const Icon(Icons.fingerprint_outlined, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
                onPressed: () => _enroll(person),
              ),
            ),
            Tooltip(
              message: attendanceTooltip,
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
                onPressed: () => _viewAttendance(person),
              ),
            ),
          ] else ...[
            Tooltip(
              message: enrollTooltip,
              child: OutlinedButton.icon(
                onPressed: () => _enroll(person),
                icon: const Icon(Icons.fingerprint_outlined, size: 16),
                label: const Text('Enroll'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: attendanceTooltip,
              child: OutlinedButton.icon(
                onPressed: () => _viewAttendance(person),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Attendance'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
