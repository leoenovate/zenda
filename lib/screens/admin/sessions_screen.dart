import 'package:flutter/material.dart';
import '../../models/class_group.dart';
import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/session.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class SessionsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const SessionsScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

/// Selectable role option in the "Who will attend?" picker. Wraps either a
/// built-in role (teacher / admin / staff / worker) or a custom [Role]
/// definition from the `roles/` collection.
class _RoleOption {
  final String key;
  final String label;
  final String assigneeKind;
  final String schoolId;

  /// Set for built-in roles so the same option works across schools.
  final bool isBuiltIn;

  const _RoleOption({
    required this.key,
    required this.label,
    required this.assigneeKind,
    required this.schoolId,
    this.isBuiltIn = false,
  });
}

/// A specific person who can be picked when `audienceMode == 'single'`.
class _RolePerson {
  final String assigneeKind;
  final String id;
  final String name;
  final String schoolId;

  const _RolePerson({
    required this.assigneeKind,
    required this.id,
    required this.name,
    required this.schoolId,
  });
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _isLoading = true;
  List<Session> _sessions = [];
  List<Teacher> _teachers = [];
  List<ClassGroup> _classes = [];
  List<Worker> _workers = [];
  List<Role> _roles = [];
  List<app_user.AppUser> _users = [];
  String _searchQuery = '';
  String _schoolFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getSessions(),
        FirebaseService.getTeachers(),
        FirebaseService.getClasses(),
        FirebaseService.getWorkers(),
        FirebaseService.getRoles(),
        FirebaseService.getUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<Session>;
        _teachers = results[1] as List<Teacher>;
        _classes = results[2] as List<ClassGroup>;
        _workers = results[3] as List<Worker>;
        _roles = results[4] as List<Role>;
        _users = results[5] as List<app_user.AppUser>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sessions: $e')));
    }
  }

  List<Session> get _filtered {
    return _sessions.where((s) {
      if (_schoolFilter != 'all' && s.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            (s.className ?? '').toLowerCase().contains(q) ||
            (s.teacherName ?? '').toLowerCase().contains(q) ||
            (s.assigneeName ?? '').toLowerCase().contains(q) ||
            (s.audienceRole ?? '').toLowerCase().contains(q) ||
            _audienceLabel(s).toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Role / person catalog used by the form dialog.
  // ---------------------------------------------------------------------------

  /// Returns every selectable role for [schoolId], built-in roles first and
  /// then custom roles defined for the school.
  List<_RoleOption> _rolesForSchool(String schoolId) {
    return [
      _RoleOption(
        key: 'teacher',
        label: 'Teachers',
        assigneeKind: 'teacher',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'admin',
        label: 'Administrators',
        assigneeKind: 'admin',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'staff',
        label: 'Staff accounts',
        assigneeKind: 'staff',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'worker',
        label: 'Workers (all)',
        assigneeKind: 'worker',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      for (final r in _roles)
        if (r.isActive && r.schoolId == schoolId && r.id != null)
          _RoleOption(
            key: r.name,
            label: r.name,
            assigneeKind: 'worker',
            schoolId: schoolId,
          ),
    ];
  }

  bool _isSchoolAdminUser(app_user.AppUser u) {
    final r = (u.role ?? '').toLowerCase();
    return r == 'admin' || r == 'school_admin';
  }

  /// Returns every person that belongs to [option] in the same school.
  /// For custom roles, this is workers whose `role` field matches the role
  /// name (case-insensitive). For the built-in `worker` role this is every
  /// worker, regardless of custom-role assignment.
  List<_RolePerson> _peopleInRole(_RoleOption option) {
    final out = <_RolePerson>[];
    final schoolId = option.schoolId;

    switch (option.key) {
      case 'teacher':
        for (final t in _teachers) {
          if (!t.isActive || t.id == null) continue;
          if (t.schoolId != schoolId) continue;
          out.add(
            _RolePerson(
              assigneeKind: 'teacher',
              id: t.id!,
              name: t.name,
              schoolId: t.schoolId,
            ),
          );
        }
        break;
      case 'admin':
        for (final u in _users) {
          if (!u.isActive || u.id == null) continue;
          if (!_isSchoolAdminUser(u)) continue;
          if (u.schoolId != schoolId) continue;
          final name = (u.name != null && u.name!.trim().isNotEmpty)
              ? u.name!.trim()
              : u.email;
          out.add(
            _RolePerson(
              assigneeKind: 'admin',
              id: u.id!,
              name: name,
              schoolId: schoolId,
            ),
          );
        }
        break;
      case 'staff':
        for (final u in _users) {
          if (!u.isActive || u.id == null) continue;
          if ((u.role ?? '').toLowerCase() != 'staff') continue;
          if (u.schoolId != schoolId) continue;
          final name = (u.name != null && u.name!.trim().isNotEmpty)
              ? u.name!.trim()
              : u.email;
          out.add(
            _RolePerson(
              assigneeKind: 'staff',
              id: u.id!,
              name: name,
              schoolId: schoolId,
            ),
          );
        }
        break;
      case 'worker':
        for (final w in _workers) {
          if (!w.isActive || w.id == null) continue;
          if (w.schoolId != schoolId) continue;
          out.add(
            _RolePerson(
              assigneeKind: 'worker',
              id: w.id!,
              name: w.name,
              schoolId: w.schoolId,
            ),
          );
        }
        break;
      default:
        // Custom role: workers whose .role matches the role's name.
        final target = option.key.trim().toLowerCase();
        for (final w in _workers) {
          if (!w.isActive || w.id == null) continue;
          if (w.schoolId != schoolId) continue;
          if ((w.role ?? '').trim().toLowerCase() != target) continue;
          out.add(
            _RolePerson(
              assigneeKind: 'worker',
              id: w.id!,
              name: w.name,
              schoolId: w.schoolId,
            ),
          );
        }
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    return AdminListScaffold(
      title: 'Sessions',
      subtitle:
          widget.showSchoolFilter
              ? 'Daily class sessions and attendance windows'
              : 'Class sessions and attendance windows for your school',
      searchHint: 'Search by class, role or person...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'New Session',
      onAddPressed: () => _showFormDialog(),
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.event_note_outlined,
                message: 'No sessions found',
              )
              : AdminListCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  itemBuilder: (_, i) => _buildRow(filtered[i]),
                ),
              ),
    );
  }

  IconData _iconForAudience(Session s) {
    if (s.audienceType == 'students') return Icons.school_outlined;
    return switch (s.assigneeKind ?? s.audienceRole ?? '') {
      'teacher' => Icons.groups_2_outlined,
      'admin' => Icons.admin_panel_settings_outlined,
      'staff' => Icons.support_agent_outlined,
      _ => Icons.badge_outlined,
    };
  }

  Widget _buildRow(Session s) {
    final schoolName =
        widget.schools
            .firstWhere(
              (sc) => sc.id == s.schoolId,
              orElse: () => const School(name: 'Unknown school'),
            )
            .name;

    final statusColor = s.isActive ? Colors.green : Colors.grey;
    final audienceColor =
        s.audienceType == 'students'
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.tertiary;
    final audienceLabel = _audienceLabel(s);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: audienceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForAudience(s), color: audienceColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(s.date)}${s.className != null ? ' · ${s.className}' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (widget.showSchoolFilter && widget.schools.length > 1)
                      schoolName,
                    audienceLabel,
                    if (s.audienceType == 'students' &&
                        s.teacherName != null &&
                        !audienceLabel.contains(s.teacherName!))
                      'Teacher: ${s.teacherName}',
                    if (s.startTime != null && s.endTime != null)
                      '${s.startTime} - ${s.endTime}',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.isActive ? 'ACTIVE' : 'ENDED',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          if (s.isActive)
            IconButton(
              icon: const Icon(
                Icons.stop_circle,
                size: 20,
                color: Colors.orange,
              ),
              tooltip: 'End session',
              onPressed: () => _endSession(s),
            ),
          IconButton(
            icon: Icon(
              Icons.edit,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showFormDialog(session: s),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(s),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _roleDisplayName(String key) {
    switch (key.toLowerCase()) {
      case 'teacher':
        return 'Teachers';
      case 'admin':
        return 'Administrators';
      case 'staff':
        return 'Staff accounts';
      case 'worker':
        return 'Workers';
      default:
        return key;
    }
  }

  String _audienceLabel(Session s) {
    if (s.audienceLabel != null && s.audienceLabel!.trim().isNotEmpty) {
      return s.audienceLabel!;
    }
    if (s.audienceType == 'students') {
      if (s.className != null && s.className!.trim().isNotEmpty) {
        return 'Class: ${s.className}';
      }
      return 'Students';
    }
    final role = _roleDisplayName(s.audienceRole ?? '');
    if (s.audienceMode == 'single' && (s.assigneeName ?? '').isNotEmpty) {
      return '$role: ${s.assigneeName}';
    }
    return s.audienceRole == null ? 'Role' : 'All $role'.trim();
  }

  Widget _dialogSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.55),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _showFormDialog({Session? session}) {
    final dateController = TextEditingController(
      text:
          session != null
              ? _formatDate(session.date)
              : _formatDate(DateTime.now()),
    );
    final startController = TextEditingController(
      text: session?.startTime ?? '',
    );
    final endController = TextEditingController(text: session?.endTime ?? '');
    final lateTimeController = TextEditingController(
      text: session?.lateTime ?? '',
    );
    final classNameController = TextEditingController(
      text: session?.className ?? '',
    );
    String? schoolId = session?.schoolId;
    String? classId = session?.classId;
    String? teacherId = session?.teacherId;
    String audienceType = session?.audienceType ?? 'students';
    // 'class' for students; 'all' / 'single' for role audiences.
    String audienceMode =
        session?.audienceMode ??
        (audienceType == 'role' ? 'all' : 'class');
    String? selectedRoleKey = session?.audienceRole;
    String? assigneeId = session?.assigneeId ?? session?.teacherId;
    bool isActive = session?.isActive ?? true;
    bool isSaving = false;
    final isEdit = session != null;
    DateTime pickedDate = session?.date ?? DateTime.now();

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              final classesForSchool =
                  _classes.where((c) => c.schoolId == schoolId).toList();
              final teachersForSchool =
                  _teachers.where((t) => t.schoolId == schoolId).toList();

              final roleOptions = schoolId == null
                  ? const <_RoleOption>[]
                  : _rolesForSchool(schoolId!);
              if (audienceType == 'role' &&
                  selectedRoleKey != null &&
                  !roleOptions.any(
                    (r) => r.key.toLowerCase() ==
                        selectedRoleKey!.toLowerCase(),
                  )) {
                selectedRoleKey = null;
                assigneeId = null;
              }
              if (audienceType == 'role' &&
                  selectedRoleKey == null &&
                  roleOptions.isNotEmpty) {
                selectedRoleKey = roleOptions.first.key;
              }

              final selectedRole = audienceType == 'role'
                  ? roleOptions.firstWhere(
                      (r) =>
                          r.key.toLowerCase() ==
                          (selectedRoleKey ?? '').toLowerCase(),
                      orElse: () => roleOptions.isNotEmpty
                          ? roleOptions.first
                          : _RoleOption(
                              key: 'teacher',
                              label: 'Teachers',
                              assigneeKind: 'teacher',
                              schoolId: schoolId ?? '',
                              isBuiltIn: true,
                            ),
                    )
                  : null;

              final peopleInRole = selectedRole == null
                  ? const <_RolePerson>[]
                  : _peopleInRole(selectedRole);

              if (audienceMode == 'single' &&
                  assigneeId != null &&
                  !peopleInRole.any((p) => p.id == assigneeId)) {
                assigneeId = null;
              }
              return AlertDialog(
                backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                title: Text(
                  isEdit ? 'Edit Session' : 'New Session',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.schools.length > 1) ...[
                          DropdownButtonFormField<String?>(
                            value: schoolId,
                            decoration: adminInputDecoration(
                              'School',
                              required: true,
                            ),
                            dropdownColor:
                                Theme.of(dialogCtx).colorScheme.surface,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            items:
                                widget.schools
                                    .map(
                                      (s) => DropdownMenuItem<String?>(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setStateDialog(() {
                                  schoolId = v;
                                  teacherId = null;
                                  classId = null;
                                  classNameController.clear();
                                  selectedRoleKey = null;
                                  assigneeId = null;
                                }),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _dialogSection(
                          context: dialogCtx,
                          icon: Icons.schedule_outlined,
                          title: 'Schedule',
                          subtitle: 'Set when this attendance window is open.',
                          child: Column(
                            children: [
                              TextField(
                                controller: dateController,
                                readOnly: true,
                                style: TextStyle(color: colorScheme.onSurface),
                                decoration: adminInputDecoration(
                                  'Date',
                                  required: true,
                                ).copyWith(
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogCtx,
                                    initialDate: pickedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    pickedDate = picked;
                                    dateController.text = _formatDate(picked);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: startController,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: adminInputDecoration(
                                        'Start (HH:mm)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: endController,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                      decoration: adminInputDecoration(
                                        'End (HH:mm)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: lateTimeController,
                                style: TextStyle(color: colorScheme.onSurface),
                                decoration: adminInputDecoration(
                                  'Late threshold (HH:mm)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _dialogSection(
                          context: dialogCtx,
                          icon: Icons.how_to_reg_outlined,
                          title: 'Who will attend?',
                          subtitle:
                              'Choose a student class or any role — built-in or custom.',
                          child: DefaultTabController(
                            length: 2,
                            initialIndex: audienceType == 'role' ? 1 : 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainer
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TabBar(
                                    labelColor: colorScheme.primary,
                                    unselectedLabelColor:
                                        colorScheme.onSurfaceVariant,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    tabs: const [
                                      Tab(
                                        icon: Icon(Icons.school_outlined),
                                        text: 'Students',
                                      ),
                                      Tab(
                                        icon: Icon(Icons.badge_outlined),
                                        text: 'Role',
                                      ),
                                    ],
                                    onTap:
                                        (index) => setStateDialog(() {
                                          audienceType =
                                              index == 0 ? 'students' : 'role';
                                          if (index == 0) {
                                            audienceMode = 'class';
                                            selectedRoleKey = null;
                                            assigneeId = null;
                                          } else {
                                            audienceMode = 'all';
                                            classId = null;
                                            classNameController.clear();
                                            teacherId = null;
                                          }
                                        }),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (audienceType == 'students') ...[
                                  DropdownButtonFormField<String?>(
                                    value:
                                        classesForSchool.any(
                                              (c) => c.id == classId,
                                            )
                                            ? classId
                                            : null,
                                    decoration: adminInputDecoration(
                                      'Class / group',
                                    ),
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Type class name manually'),
                                      ),
                                      ...classesForSchool.map(
                                        (c) => DropdownMenuItem<String?>(
                                          value: c.id,
                                          child: Text(
                                            '${c.name} (${c.studentIds.length} students)',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        (v) => setStateDialog(() {
                                          classId = v;
                                          final selectedClass =
                                              v == null
                                                  ? null
                                                  : classesForSchool.firstWhere(
                                                    (c) => c.id == v,
                                                    orElse:
                                                        () => const ClassGroup(
                                                          name: '',
                                                          schoolId: '',
                                                        ),
                                                  );
                                          if (selectedClass != null &&
                                              selectedClass.name.isNotEmpty) {
                                            classNameController.text =
                                                selectedClass.name;
                                            teacherId = selectedClass.teacherId;
                                          }
                                        }),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: classNameController,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                    decoration: adminInputDecoration(
                                      'Class name',
                                      required: true,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String?>(
                                    value:
                                        teachersForSchool.any(
                                              (t) => t.id == teacherId,
                                            )
                                            ? teacherId
                                            : null,
                                    decoration: adminInputDecoration(
                                      'Responsible teacher',
                                    ),
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned'),
                                      ),
                                      ...teachersForSchool.map(
                                        (t) => DropdownMenuItem<String?>(
                                          value: t.id,
                                          child: Text(t.name),
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        (v) =>
                                            setStateDialog(() => teacherId = v),
                                  ),
                                ] else ...[
                                  DropdownButtonFormField<String?>(
                                    value: selectedRoleKey,
                                    decoration: adminInputDecoration(
                                      'Role',
                                      required: true,
                                    ),
                                    dropdownColor: colorScheme.surface,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
                                    items: [
                                      for (final role in roleOptions)
                                        DropdownMenuItem<String?>(
                                          value: role.key,
                                          child: Text(
                                            role.isBuiltIn
                                                ? role.label
                                                : '${role.label} (custom)',
                                          ),
                                        ),
                                    ],
                                    onChanged:
                                        (v) => setStateDialog(() {
                                          selectedRoleKey = v;
                                          assigneeId = null;
                                        }),
                                  ),
                                  const SizedBox(height: 12),
                                  RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    value: 'all',
                                    groupValue: audienceMode,
                                    activeColor: colorScheme.primary,
                                    title: Text(
                                      'Everyone in this role',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      selectedRole == null
                                          ? 'Pick a role above first.'
                                          : '${peopleInRole.length} '
                                              '${peopleInRole.length == 1 ? 'person' : 'people'} '
                                              'will be expected.',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    onChanged:
                                        (v) => setStateDialog(() {
                                          audienceMode = v ?? 'all';
                                          assigneeId = null;
                                        }),
                                  ),
                                  RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    value: 'single',
                                    groupValue: audienceMode,
                                    activeColor: colorScheme.primary,
                                    title: Text(
                                      'Only one person',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Use this for a session that targets a single individual in the role.',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    onChanged:
                                        (v) => setStateDialog(() {
                                          audienceMode = v ?? 'single';
                                        }),
                                  ),
                                  if (audienceMode == 'single') ...[
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String?>(
                                      value: peopleInRole.any(
                                        (p) => p.id == assigneeId,
                                      )
                                          ? assigneeId
                                          : null,
                                      decoration: adminInputDecoration(
                                        'Person',
                                        required: true,
                                      ),
                                      dropdownColor: colorScheme.surface,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                      items: peopleInRole.isEmpty
                                          ? [
                                              const DropdownMenuItem<String?>(
                                                value: null,
                                                child: Text(
                                                  'No people in this role yet',
                                                ),
                                              ),
                                            ]
                                          : peopleInRole
                                              .map(
                                                (p) => DropdownMenuItem<
                                                    String?>(
                                                  value: p.id,
                                                  child: Text(p.name),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: peopleInRole.isEmpty
                                          ? null
                                          : (v) => setStateDialog(
                                                () => assigneeId = v,
                                              ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          activeColor: Theme.of(context).colorScheme.primary,
                          title: Text(
                            'Active',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          onChanged: (v) => setStateDialog(() => isActive = v),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              if (schoolId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('School is required'),
                                  ),
                                );
                                return;
                              }
                              if (audienceType == 'students' &&
                                  classNameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Class name is required'),
                                  ),
                                );
                                return;
                              }
                              if (audienceType == 'role' &&
                                  (selectedRoleKey == null ||
                                      selectedRole == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Choose a role'),
                                  ),
                                );
                                return;
                              }
                              if (audienceType == 'role' &&
                                  audienceMode == 'single' &&
                                  assigneeId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Choose a person'),
                                  ),
                                );
                                return;
                              }
                              setStateDialog(() => isSaving = true);
                              try {
                                final selectedTeacher =
                                    teacherId == null
                                        ? null
                                        : _teachers.firstWhere(
                                          (t) => t.id == teacherId,
                                          orElse:
                                              () => const Teacher(
                                                name: '',
                                                schoolId: '',
                                              ),
                                        );
                                final selectedPerson = (audienceType ==
                                            'role' &&
                                        audienceMode == 'single' &&
                                        assigneeId != null)
                                    ? peopleInRole.firstWhere(
                                        (p) => p.id == assigneeId,
                                        orElse: () => _RolePerson(
                                          assigneeKind:
                                              selectedRole!.assigneeKind,
                                          id: assigneeId!,
                                          name: '',
                                          schoolId: schoolId!,
                                        ),
                                      )
                                    : null;

                                final roleDisplay = audienceType == 'role'
                                    ? (selectedRole!.isBuiltIn
                                        ? _roleDisplayName(selectedRole.key)
                                        : selectedRole.label)
                                    : '';

                                String? sessionAudienceLabel;
                                if (audienceType == 'students') {
                                  final cn = classNameController.text.trim();
                                  if (cn.isNotEmpty) {
                                    sessionAudienceLabel = 'Class: $cn';
                                  }
                                } else if (audienceMode == 'all') {
                                  sessionAudienceLabel = 'All $roleDisplay';
                                } else if (audienceMode == 'single') {
                                  sessionAudienceLabel =
                                      '$roleDisplay: ${selectedPerson?.name ?? ''}';
                                }

                                // Keep teacherId/teacherName populated when
                                // the audience role is `teacher` so the
                                // existing teacher dashboard keeps seeing
                                // these sessions.
                                final resolvedTeacherId =
                                    audienceType == 'students'
                                        ? teacherId
                                        : (selectedRole?.key == 'teacher' &&
                                                audienceMode == 'single')
                                            ? assigneeId
                                            : null;
                                final resolvedTeacherName =
                                    audienceType == 'students'
                                        ? (selectedTeacher != null &&
                                                selectedTeacher.name.isNotEmpty
                                            ? selectedTeacher.name
                                            : null)
                                        : (selectedRole?.key == 'teacher' &&
                                                audienceMode == 'single')
                                            ? selectedPerson?.name
                                            : null;

                                final updated = Session(
                                  id: session?.id,
                                  schoolId: schoolId!,
                                  date: pickedDate,
                                  isActive: isActive,
                                  startTime:
                                      startController.text.trim().isEmpty
                                          ? null
                                          : startController.text.trim(),
                                  endTime:
                                      endController.text.trim().isEmpty
                                          ? null
                                          : endController.text.trim(),
                                  lateTime:
                                      lateTimeController.text.trim().isEmpty
                                          ? null
                                          : lateTimeController.text.trim(),
                                  className: audienceType == 'students' &&
                                          classNameController.text
                                              .trim()
                                              .isNotEmpty
                                      ? classNameController.text.trim()
                                      : null,
                                  classId: audienceType == 'students'
                                      ? classId
                                      : null,
                                  teacherId: resolvedTeacherId,
                                  teacherName: resolvedTeacherName,
                                  audienceType: audienceType,
                                  audienceMode: audienceMode,
                                  audienceRole: audienceType == 'role'
                                      ? selectedRole!.key
                                      : null,
                                  assigneeKind: audienceType == 'role'
                                      ? selectedRole!.assigneeKind
                                      : null,
                                  assigneeId: audienceType == 'role' &&
                                          audienceMode == 'single'
                                      ? assigneeId
                                      : null,
                                  assigneeName: audienceType == 'role' &&
                                          audienceMode == 'single'
                                      ? selectedPerson?.name
                                      : null,
                                  audienceLabel:
                                      (sessionAudienceLabel ?? '').trim().isEmpty
                                          ? null
                                          : sessionAudienceLabel,
                                );
                                if (isEdit) {
                                  await FirebaseService.updateSession(updated);
                                } else {
                                  await FirebaseService.createSession(updated);
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Session updated'
                                          : 'Session created',
                                    ),
                                  ),
                                );
                                await _load();
                                widget.onDataChanged?.call();
                              } catch (e) {
                                setStateDialog(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _endSession(Session s) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'End Session',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Mark this session as ended? Attendance recording will stop.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.endSession(s.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session ended')),
                    );
                    await _load();
                    widget.onDataChanged?.call();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End'),
              ),
            ],
          ),
    );
  }

  void _confirmDelete(Session s) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete Session',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete this session? This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.deleteSession(s.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session deleted')),
                    );
                    await _load();
                    widget.onDataChanged?.call();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
}
