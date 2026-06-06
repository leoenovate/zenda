import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/device_enrollment_lookup_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import '../../widgets/admin/enrolled_badge.dart';

/// A unified row representing one assignable person — drawn from
/// `workers/`, `teachers/` or `users/`.
class _Person {
  final String kind;
  final String id;
  final String name;
  final String schoolId;
  final String? roleId;
  final String? subtitle;

  /// Ordered cardId candidates used to match this person against the
  /// device enrollment table. Mirrors `_EnrollmentParticipant`'s lookup:
  /// `employeeId` first, falling back to the document id. Empty for kinds
  /// that aren't enrollable (admin / staff users live in `users/` and
  /// don't have an employeeId today).
  final List<String?> cardCandidates;

  const _Person({
    required this.kind,
    required this.id,
    required this.name,
    required this.schoolId,
    required this.roleId,
    this.subtitle,
    this.cardCandidates = const [],
  });
}

/// Lists every person assigned to a single custom [role] across workers,
/// teachers, and admin/staff users. Provides actions to add, move, or
/// remove employees from the role.
///
/// When passed `role.id == null` the screen behaves as the special
/// **Unassigned** bucket: it lists every person whose `roleId` is null.
class RoleEmployeesScreen extends StatefulWidget {
  final Role role;
  final List<Role> allRoles;
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const RoleEmployeesScreen({
    super.key,
    required this.role,
    required this.allRoles,
    required this.schools,
    this.onDataChanged,
  });

  @override
  State<RoleEmployeesScreen> createState() => _RoleEmployeesScreenState();
}

class _RoleEmployeesScreenState extends State<RoleEmployeesScreen> {
  bool _isLoading = true;
  List<_Person> _people = [];
  String _searchQuery = '';
  DeviceEnrollmentLookup _enrollments = const DeviceEnrollmentLookup.empty();

  bool get _isUnassignedBucket => widget.role.id == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RoleEmployeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.id != widget.role.id ||
        oldWidget.role.name != widget.role.name) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getWorkers(),
        FirebaseService.getTeachers(),
        FirebaseService.getUsers(),
      ]);
      if (!mounted) return;
      final workers = results[0] as List<Worker>;
      final teachers = results[1] as List<Teacher>;
      final users = results[2] as List<app_user.AppUser>;
      setState(() {
        _people = _buildPeople(workers, teachers, users);
        _isLoading = false;
      });
      unawaited(_loadEnrollments());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
    }
  }

  Future<void> _loadEnrollments() async {
    try {
      final devices = await FirebaseService.getDevices();
      final lookup = await DeviceEnrollmentLookup.fetch(devices);
      if (!mounted) return;
      setState(() => _enrollments = lookup);
    } catch (_) {}
  }

  List<_Person> _buildPeople(
    List<Worker> workers,
    List<Teacher> teachers,
    List<app_user.AppUser> users,
  ) {
    final out = <_Person>[];

    for (final w in workers) {
      if (w.id == null) continue;
      out.add(
        _Person(
          kind: AuthRoles.kindWorker,
          id: w.id!,
          name: w.name,
          schoolId: w.schoolId,
          roleId: w.roleId,
          subtitle: [
            if ((w.employeeId ?? '').isNotEmpty) 'ID: ${w.employeeId}',
            if ((w.phone ?? '').isNotEmpty) w.phone!,
            if ((w.email ?? '').isNotEmpty) w.email!,
          ].where((s) => s.isNotEmpty).join(' · '),
          cardCandidates: [w.employeeId, w.id],
        ),
      );
    }

    for (final t in teachers) {
      if (t.id == null) continue;
      out.add(
        _Person(
          kind: AuthRoles.kindTeacher,
          id: t.id!,
          name: t.name,
          schoolId: t.schoolId,
          roleId: t.roleId,
          subtitle: [
            if ((t.subject ?? '').isNotEmpty) t.subject!,
            if ((t.phone ?? '').isNotEmpty) t.phone!,
            if ((t.email ?? '').isNotEmpty) t.email!,
          ].where((s) => s.isNotEmpty).join(' · '),
          cardCandidates: [t.employeeId, t.id],
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
      out.add(
        _Person(
          kind: kind,
          id: u.id!,
          name: displayName,
          schoolId: sid,
          roleId: u.roleId,
          subtitle: [
            u.email,
            if ((u.phone ?? '').isNotEmpty) u.phone!,
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
      );
    }

    return out;
  }

  /// People that match the focused [Role]: same school and either
  /// matching `roleId` (for normal roles) or missing `roleId` (for the
  /// Unassigned bucket).
  List<_Person> get _assigned {
    final roleSchoolId = widget.role.schoolId;
    return _people.where((p) {
        if (p.schoolId != roleSchoolId) return false;
        final matchesRole =
            _isUnassignedBucket
                ? (p.roleId == null || p.roleId!.isEmpty)
                : p.roleId == widget.role.id;
        if (!matchesRole) return false;
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          final match =
              p.name.toLowerCase().contains(q) ||
              (p.subtitle ?? '').toLowerCase().contains(q);
          if (!match) return false;
        }
        return true;
      }).toList()
      ..sort((a, b) {
        final k = AuthRoles.allKinds
            .indexOf(a.kind)
            .compareTo(AuthRoles.allKinds.indexOf(b.kind));
        if (k != 0) return k;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _assigned;
    final desc = widget.role.description;
    final headerExtras =
        _isUnassignedBucket
            ? null
            : OutlinedButton.icon(
              onPressed: _openEditRoleDialog,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit role'),
            );

    return AdminListScaffold(
      title: widget.role.name,
      subtitle:
          _isUnassignedBucket
              ? 'People without a custom role assigned'
              : ((desc != null && desc.isNotEmpty)
                  ? desc
                  : 'Manage employees assigned to this role'),
      searchHint: 'Search assigned employees...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: 'all',
      onSchoolFilterChanged: (_) {},
      showSchoolFilter: false,
      addButtonLabel: 'Add new',
      onAddPressed: _openAddDialog,
      headerExtras: headerExtras,
      listContent:
          filtered.isEmpty
              ? AdminEmptyState(
                icon: Icons.engineering_outlined,
                message:
                    _isUnassignedBucket
                        ? 'Everyone has a custom role assigned.'
                        : 'No employees assigned to this role yet',
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
                  itemBuilder: (_, i) => _buildAssignedRow(filtered[i]),
                ),
              ),
    );
  }

  // ----------------------------------------------------------------------
  // Row UI
  // ----------------------------------------------------------------------

  Widget _buildAssignedRow(_Person p) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 650;
    final hits = _enrollments.findEnrollments(p.cardCandidates);
    final subtitle = [
      AuthRoles.kindLabel(p.kind),
      if ((p.subtitle ?? '').isNotEmpty) p.subtitle!,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.15),
            radius: 20,
            child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
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
                  p.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: isMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isMobile && hits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: EnrolledBadge(enrollments: hits),
                  ),
                ],
              ],
            ),
          ),
          if (!isMobile && hits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: EnrolledBadge(enrollments: hits),
            ),
          PopupMenuButton<_RowAction>(
            tooltip: 'More',
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            onSelected: (action) {
              switch (action) {
                case _RowAction.move:
                  _openMoveDialog(p);
                  break;
                case _RowAction.remove:
                  _confirmRemove(p);
                  break;
              }
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem<_RowAction>(
                    value: _RowAction.move,
                    child: Row(
                      children: const [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('Move to another role'),
                      ],
                    ),
                  ),
                  if (!_isUnassignedBucket)
                    PopupMenuItem<_RowAction>(
                      value: _RowAction.remove,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.person_remove_outlined,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Remove from this role',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Add / move / remove dialogs
  // ----------------------------------------------------------------------

  /// Picker dialog used by the "Add new" button. Lists every person
  /// in the same school who is not already in this role. Person kind is
  /// not filtered — any worker / teacher / admin / staff record can be
  /// assigned to any role.
  Future<void> _openAddDialog() async {
    final available =
        _people
            .where(
              (p) =>
                  p.schoolId == widget.role.schoolId &&
                  p.roleId != widget.role.id,
            )
            .toList()
          ..sort((a, b) {
            final k = AuthRoles.allKinds
                .indexOf(a.kind)
                .compareTo(AuthRoles.allKinds.indexOf(b.kind));
            if (k != 0) return k;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

    String query = '';
    final selected = <String>{}; // compoundKey: kind:id
    bool isSaving = false;

    String compoundKey(_Person p) => '${p.kind}:${p.id}';

    String currentRoleNameForPerson(_Person p) {
      if (p.roleId == null || p.roleId!.isEmpty) return 'Unassigned';
      for (final r in widget.allRoles) {
        if (r.id == p.roleId) return r.name;
      }
      return 'Unassigned';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              final filtered =
                  available.where((p) {
                    if (query.isEmpty) return true;
                    final q = query.toLowerCase();
                    return p.name.toLowerCase().contains(q) ||
                        (p.subtitle ?? '').toLowerCase().contains(q);
                  }).toList();

              final dialogTitle =
                  _isUnassignedBucket
                      ? 'Unassign people from their roles'
                      : 'Add employees to ${widget.role.name}';
              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  dialogTitle,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 460,
                  height: 480,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search by name, ID, email or phone...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged:
                            (v) => setStateDialog(() => query = v.trim()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            available.isEmpty
                                ? Center(
                                  child: Text(
                                    _isUnassignedBucket
                                        ? 'No assigned people to unassign'
                                        : 'Every existing person is already assigned. Create a new one instead.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : filtered.isEmpty
                                ? Center(
                                  child: Text(
                                    'No matching employees',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                                : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder:
                                      (_, __) => Divider(
                                        height: 1,
                                        color: colorScheme.outlineVariant,
                                      ),
                                  itemBuilder: (_, i) {
                                    final p = filtered[i];
                                    final key = compoundKey(p);
                                    final hasOtherRole =
                                        p.roleId != null &&
                                        p.roleId!.isNotEmpty &&
                                        p.roleId != widget.role.id;
                                    final isSelected = selected.contains(key);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (v) {
                                        setStateDialog(() {
                                          if (v == true) {
                                            selected.add(key);
                                          } else {
                                            selected.remove(key);
                                          }
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        p.name,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          AuthRoles.kindLabel(p.kind),
                                          'Currently: ${currentRoleNameForPerson(p)}',
                                        ].join(' · '),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                      secondary:
                                          hasOtherRole
                                              ? Tooltip(
                                                message:
                                                    'Will be moved from ${currentRoleNameForPerson(p)}',
                                                child: const Icon(
                                                  Icons.swap_horiz,
                                                  size: 18,
                                                  color: Colors.orange,
                                                ),
                                              )
                                              : null,
                                    );
                                  },
                                ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${selected.length} selected',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSaving
                            ? null
                            : () {
                              Navigator.pop(dialogCtx);
                              unawaited(_openCreateNewPersonDialog());
                            },
                    child: const Text('Create new'),
                  ),
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (isSaving || selected.isEmpty)
                            ? null
                            : () async {
                              setStateDialog(() => isSaving = true);
                              try {
                                // Group selected ids by kind so we hit the
                                // right collection per batch.
                                final byKind = <String, List<String>>{};
                                for (final key in selected) {
                                  final colon = key.indexOf(':');
                                  if (colon < 0) continue;
                                  final kind = key.substring(0, colon);
                                  final id = key.substring(colon + 1);
                                  (byKind[kind] ??= <String>[]).add(id);
                                }
                                for (final entry in byKind.entries) {
                                  await FirebaseService.setPersonsRole(
                                    kind: entry.key,
                                    ids: entry.value,
                                    roleId: widget.role.id,
                                  );
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                final personLabel =
                                    selected.length == 1 ? 'person' : 'people';
                                final msg =
                                    _isUnassignedBucket
                                        ? 'Unassigned ${selected.length} $personLabel'
                                        : 'Assigned ${selected.length} $personLabel '
                                            'to ${widget.role.name}';
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
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
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isSaving
                          ? 'Saving...'
                          : (selected.isEmpty
                              ? 'Add'
                              : 'Add ${selected.length}'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _openCreateNewPersonDialog() async {
    final roleId = _isUnassignedBucket ? null : widget.role.id;
    String kind = AuthRoles.kindWorker;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final employeeIdController = TextEditingController();
    final subjectController = TextEditingController();
    final passwordController = TextEditingController(text: 'admin123');
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              final isUserAccount =
                  kind == AuthRoles.kindAdmin || kind == AuthRoles.kindStaff;
              final isTeacher = kind == AuthRoles.kindTeacher;
              final isWorker = kind == AuthRoles.kindWorker;

              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  'Add new',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: kind,
                          decoration: adminInputDecoration(
                            'Employee type',
                            required: true,
                          ),
                          items: [
                            for (final k in AuthRoles.allKinds)
                              DropdownMenuItem(
                                value: k,
                                child: Text(AuthRoles.kindLabel(k)),
                              ),
                          ],
                          onChanged:
                              (v) => setStateDialog(
                                () => kind = v ?? AuthRoles.kindWorker,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          decoration: adminInputDecoration(
                            'Full name',
                            required: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isWorker || isTeacher) ...[
                          TextField(
                            controller: employeeIdController,
                            decoration: adminInputDecoration('Employee ID'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (isTeacher) ...[
                          TextField(
                            controller: subjectController,
                            decoration: adminInputDecoration('Subject'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: adminInputDecoration(
                            'Email',
                            required: isUserAccount,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: adminInputDecoration('Phone'),
                        ),
                        if (isUserAccount) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: adminInputDecoration(
                              'Temporary password',
                              required: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              final name = nameController.text.trim();
                              final email = emailController.text.trim();
                              final phone = phoneController.text.trim();
                              final employeeId =
                                  employeeIdController.text.trim();
                              final subject = subjectController.text.trim();
                              final password = passwordController.text;

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Full name is required'),
                                  ),
                                );
                                return;
                              }
                              if (isUserAccount && !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'A valid email is required for admin/staff accounts',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (isUserAccount && password.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password must be at least 6 characters',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setStateDialog(() => isSaving = true);
                              try {
                                switch (kind) {
                                  case AuthRoles.kindTeacher:
                                    await FirebaseService.addTeacher(
                                      Teacher(
                                        name: name,
                                        schoolId: widget.role.schoolId,
                                        email: email.isEmpty ? null : email,
                                        phone: phone.isEmpty ? null : phone,
                                        subject:
                                            subject.isEmpty ? null : subject,
                                        employeeId:
                                            employeeId.isEmpty
                                                ? null
                                                : employeeId,
                                        roleId: roleId,
                                      ),
                                    );
                                    break;
                                  case AuthRoles.kindAdmin:
                                  case AuthRoles.kindStaff:
                                    await FirebaseService.addAdmin(
                                      email: email,
                                      password: password,
                                      role:
                                          kind == AuthRoles.kindAdmin
                                              ? AuthRoles.admin
                                              : AuthRoles.staff,
                                      name: name,
                                      schoolId: widget.role.schoolId,
                                      phone: phone.isEmpty ? null : phone,
                                      roleId: roleId,
                                    );
                                    break;
                                  case AuthRoles.kindWorker:
                                  default:
                                    await FirebaseService.addWorker(
                                      Worker(
                                        name: name,
                                        schoolId: widget.role.schoolId,
                                        employeeId:
                                            employeeId.isEmpty
                                                ? null
                                                : employeeId,
                                        phone: phone.isEmpty ? null : phone,
                                        email: email.isEmpty ? null : email,
                                        roleId: roleId,
                                      ),
                                    );
                                    break;
                                }

                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Created $name'
                                      '${roleId == null ? '' : ' in ${widget.role.name}'}',
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
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isSaving ? 'Saving...' : 'Create'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _openMoveDialog(_Person person) async {
    // Move targets: every other active role for this school, plus a
    // synthetic "Unassigned" option. Person kind is not filtered.
    final targetRoles =
        widget.allRoles
            .where(
              (r) =>
                  r.id != widget.role.id &&
                  r.schoolId == widget.role.schoolId &&
                  r.isActive,
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    String? targetRoleId; // null => Unassigned
    bool selectedUnassigned = _isUnassignedBucket ? false : false;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  'Move ${person.name}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isUnassignedBucket
                            ? 'Currently unassigned'
                            : 'Currently in ${widget.role.name}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (targetRoles.isEmpty && _isUnassignedBucket)
                        Text(
                          'No other roles defined yet for this kind.',
                          style: TextStyle(color: colorScheme.onSurface),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          initialValue:
                              selectedUnassigned
                                  ? '__unassigned'
                                  : targetRoleId,
                          decoration: const InputDecoration(
                            labelText: 'Move to',
                          ),
                          items: [
                            if (!_isUnassignedBucket)
                              const DropdownMenuItem<String?>(
                                value: '__unassigned',
                                child: Text('Unassigned'),
                              ),
                            for (final r in targetRoles)
                              DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(r.name),
                              ),
                          ],
                          onChanged:
                              (v) => setStateDialog(() {
                                if (v == '__unassigned') {
                                  selectedUnassigned = true;
                                  targetRoleId = null;
                                } else {
                                  selectedUnassigned = false;
                                  targetRoleId = v;
                                }
                              }),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        (isSaving ||
                                (targetRoleId == null && !selectedUnassigned))
                            ? null
                            : () async {
                              setStateDialog(() => isSaving = true);
                              try {
                                await FirebaseService.setPersonsRole(
                                  kind: person.kind,
                                  ids: [person.id],
                                  roleId:
                                      selectedUnassigned ? null : targetRoleId,
                                );
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                final destLabel =
                                    selectedUnassigned
                                        ? 'Unassigned'
                                        : (targetRoles
                                                .where(
                                                  (r) => r.id == targetRoleId,
                                                )
                                                .map((r) => r.name)
                                                .firstOrNull ??
                                            'role');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${person.name} moved to $destLabel',
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
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isSaving ? 'Saving...' : 'Apply'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // ----------------------------------------------------------------------
  // Edit / delete role dialogs
  // ----------------------------------------------------------------------

  Future<void> _openEditRoleDialog() async {
    final role = widget.role;
    final nameController = TextEditingController(text: role.name);
    final descriptionController = TextEditingController(
      text: role.description ?? '',
    );
    bool isActive = role.isActive;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit role',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          isSaving
                              ? null
                              : () {
                                Navigator.pop(dialogCtx);
                                _confirmDeleteRole();
                              },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: adminInputDecoration(
                            'Role name',
                            required: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          maxLines: 2,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: adminInputDecoration('Description'),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          activeColor: colorScheme.primary,
                          title: Text(
                            'Active',
                            style: TextStyle(color: colorScheme.onSurface),
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
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Role name is required'),
                                  ),
                                );
                                return;
                              }
                              if (role.id == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Role is missing an id'),
                                  ),
                                );
                                return;
                              }
                              setStateDialog(() => isSaving = true);
                              try {
                                final description =
                                    descriptionController.text.trim();
                                final updated = role.copyWith(
                                  name: name,
                                  description:
                                      description.isEmpty ? null : description,
                                  isActive: isActive,
                                );
                                await FirebaseService.updateRole(updated);
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Role updated')),
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
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _confirmDeleteRole() async {
    final role = widget.role;
    await showDialog<void>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete role',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete "${role.name}"? '
              'Any employees currently assigned to this role will be unassigned.',
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
                  if (role.id == null) {
                    Navigator.pop(dialogCtx);
                    return;
                  }
                  try {
                    final cleared = await FirebaseService.clearRoleAssignments(
                      roleId: role.id!,
                      schoolId: role.schoolId,
                    );
                    await FirebaseService.deleteRole(role.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    final msg =
                        cleared > 0
                            ? 'Role deleted · '
                                '$cleared ${cleared == 1 ? 'employee' : 'employees'} '
                                'unassigned'
                            : 'Role deleted';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
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

  Future<void> _confirmRemove(_Person person) async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Remove from role',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Remove ${person.name} from "${widget.role.name}"? '
              'The ${AuthRoles.kindLabel(person.kind).toLowerCase()} record stays — only the role assignment is cleared.',
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
                    await FirebaseService.setPersonsRole(
                      kind: person.kind,
                      ids: [person.id],
                      roleId: null,
                    );
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${person.name} removed from ${widget.role.name}',
                        ),
                      ),
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
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }
}

enum _RowAction { move, remove }
