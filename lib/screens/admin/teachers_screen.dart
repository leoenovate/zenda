import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/teacher.dart';
import '../../services/device_enrollment_lookup_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import '../../widgets/admin/enrolled_badge.dart';
import '../../widgets/admin/role_dropdown.dart';

class TeachersScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const TeachersScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends State<TeachersScreen> {
  bool _isLoading = true;
  List<Teacher> _teachers = [];
  List<Role> _roles = [];
  String _searchQuery = '';
  String _schoolFilter = 'all';
  DeviceEnrollmentLookup _enrollments =
      const DeviceEnrollmentLookup.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getTeachers(),
        FirebaseService.getRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _teachers = results[0] as List<Teacher>;
        _roles = results[1] as List<Role>;
        _isLoading = false;
      });
      // Refresh enrollment badges in the background — slow HTTP queries
      // against each device shouldn't block the list from rendering.
      unawaited(_loadEnrollments());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading teachers: $e')),
      );
    }
  }

  Future<void> _loadEnrollments() async {
    try {
      final devices = await FirebaseService.getDevices();
      final lookup = await DeviceEnrollmentLookup.fetch(devices);
      if (!mounted) return;
      setState(() => _enrollments = lookup);
    } catch (_) {
      // Silently leave the badge off if we can't reach the device API.
    }
  }

  /// Display label for [t]'s custom role: looks up `roleId → Role.name`.
  String? _roleLabel(Teacher t) {
    if (t.roleId == null || t.roleId!.isEmpty) return null;
    for (final r in _roles) {
      if (r.id == t.roleId) return r.name;
    }
    return null;
  }

  List<Teacher> get _filtered {
    return _teachers.where((t) {
      if (_schoolFilter != 'all' && t.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.name.toLowerCase().contains(q) ||
            (t.email ?? '').toLowerCase().contains(q) ||
            (t.subject ?? '').toLowerCase().contains(q) ||
            (t.employeeId ?? '').toLowerCase().contains(q);
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
      title: 'Teachers',
      subtitle: widget.showSchoolFilter
          ? 'Manage teaching staff across schools'
          : 'Manage teaching staff',
      searchHint: 'Search by name, email, subject, or ID...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'Add Teacher',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(icon: Icons.person_outline, message: 'No teachers found')
          : AdminListCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                itemBuilder: (_, i) => _buildRow(filtered[i]),
              ),
            ),
    );
  }

  Widget _buildRow(Teacher t) {
    final schoolName = widget.schools
        .firstWhere((s) => s.id == t.schoolId,
            orElse: () => const School(name: 'Unknown school'))
        .name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.purple.withOpacity(0.15),
            radius: 20,
            child: Text(
              t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.purple,
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
                  t.name,
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
                    if (t.subject != null) t.subject!,
                    if ((_roleLabel(t) ?? '').isNotEmpty) _roleLabel(t)!,
                    if (t.email != null) t.email!,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Builder(
            builder: (_) {
              final hits = _enrollments.findEnrollments([t.employeeId, t.id]);
              if (hits.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: EnrolledBadge(enrollments: hits),
              );
            },
          ),
          if (!t.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'INACTIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => _showFormDialog(teacher: t),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(t),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({Teacher? teacher}) {
    final nameController = TextEditingController(text: teacher?.name ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final phoneController = TextEditingController(text: teacher?.phone ?? '');
    final subjectController = TextEditingController(text: teacher?.subject ?? '');
    final employeeIdController = TextEditingController(text: teacher?.employeeId ?? '');
    String? schoolId = teacher?.schoolId;
    String? selectedRoleId = teacher?.roleId;
    bool isActive = teacher?.isActive ?? true;
    bool isSaving = false;
    final isEdit = teacher != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }
    if (selectedRoleId != null &&
        !_roles.any((r) =>
            r.id == selectedRoleId &&
            r.appliesTo.contains(AuthRoles.kindTeacher) &&
            r.schoolId == schoolId)) {
      selectedRoleId = null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          title: Text(
            isEdit ? 'Edit Teacher' : 'Add Teacher',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Full Name', required: true),
                  ),
                  const SizedBox(height: 16),
                  if (widget.schools.length > 1) ...[
                    DropdownButtonFormField<String?>(
                      value: schoolId,
                      decoration: adminInputDecoration('School', required: true),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      items: widget.schools
                          .map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => schoolId = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Phone'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Subject'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: employeeIdController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Employee ID'),
                  ),
                  const SizedBox(height: 16),
                  RoleDropdown(
                    roles: _roles,
                    kind: AuthRoles.kindTeacher,
                    schoolId: schoolId,
                    selectedRoleId: selectedRoleId,
                    onChanged: (v) => setStateDialog(() => selectedRoleId = v),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    activeColor: Theme.of(context).colorScheme.primary,
                    title: Text('Active', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    onChanged: (v) => setStateDialog(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty || schoolId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name and school are required')),
                        );
                        return;
                      }
                      setStateDialog(() => isSaving = true);
                      try {
                        final updated = Teacher(
                          id: teacher?.id,
                          name: nameController.text.trim(),
                          schoolId: schoolId!,
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          subject: subjectController.text.trim().isEmpty
                              ? null
                              : subjectController.text.trim(),
                          employeeId: employeeIdController.text.trim().isEmpty
                              ? null
                              : employeeIdController.text.trim(),
                          roleId: selectedRoleId,
                          isActive: isActive,
                          createdAt: teacher?.createdAt,
                        );
                        if (isEdit) {
                          await FirebaseService.updateTeacher(updated);
                        } else {
                          await FirebaseService.addTeacher(updated);
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Teacher updated' : 'Teacher added'),
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
              child: Text(isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Teacher t) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
        title: Text('Delete Teacher', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Delete "${t.name}"? This action cannot be undone.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.deleteTeacher(t.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teacher deleted')),
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
}
