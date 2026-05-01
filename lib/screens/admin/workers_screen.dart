import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/worker.dart';
import '../../services/device_enrollment_lookup_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import '../../widgets/admin/enrolled_badge.dart';

class WorkersScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const WorkersScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  bool _isLoading = true;
  List<Worker> _workers = [];
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
        FirebaseService.getWorkers(),
        FirebaseService.getRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _workers = results[0] as List<Worker>;
        _roles = results[1] as List<Role>;
        _isLoading = false;
      });
      unawaited(_loadEnrollments());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
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

  /// Roles applicable to workers in [schoolId] (active and `appliesTo`
  /// includes `worker`).
  List<Role> _rolesForSchool(String? schoolId) {
    return _roles
        .where(
          (role) =>
              role.isActive &&
              role.appliesTo.contains(AuthRoles.kindWorker) &&
              (schoolId == null || role.schoolId == schoolId),
        )
        .toList();
  }

  /// Display label for [w]'s role: prefers a lookup of `roleId → Role.name`
  /// in the loaded role list, falls back to the legacy free-form text for
  /// not-yet-migrated workers.
  String? _roleLabel(Worker w) {
    if (w.roleId != null && w.roleId!.isNotEmpty) {
      for (final role in _roles) {
        if (role.id == w.roleId) return role.name;
      }
    }
    return w.legacyRoleName;
  }

  List<Worker> get _filtered {
    return _workers.where((w) {
      if (_schoolFilter != 'all' && w.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final label = (_roleLabel(w) ?? '').toLowerCase();
        final match =
            w.name.toLowerCase().contains(q) ||
            label.contains(q) ||
            (w.employeeId ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  List<DropdownMenuItem<String?>> _roleDropdownItems(String? schoolId) {
    final roles = _rolesForSchool(schoolId);
    return [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('No role selected'),
      ),
      for (final role in roles)
        DropdownMenuItem<String?>(value: role.id, child: Text(role.name)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    return AdminListScaffold(
      title: 'Workers',
      subtitle:
          widget.showSchoolFilter
              ? 'Non-student staff attendance (kitchen, cleaners, security)'
              : 'Non-student staff attendance',
      searchHint: 'Search by name, role, or employee ID...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'Add Worker',
      onAddPressed: () => _showFormDialog(),
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.engineering_outlined,
                message: 'No workers found',
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

  Widget _buildRow(Worker w) {
    final schoolName =
        widget.schools
            .firstWhere(
              (s) => s.id == w.schoolId,
              orElse: () => const School(name: 'Unknown school'),
            )
            .name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal.withOpacity(0.15),
            radius: 20,
            child: Text(
              w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.teal,
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
                  w.name,
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
                    if ((_roleLabel(w) ?? '').isNotEmpty) _roleLabel(w)!,
                    if (w.employeeId != null) 'ID: ${w.employeeId}',
                    if (w.fingerprintData != null) 'Fingerprint on file',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (_) {
              final hits = _enrollments.findEnrollments([w.employeeId, w.id]);
              if (hits.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: EnrolledBadge(enrollments: hits),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.edit,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showFormDialog(worker: w),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(w),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({Worker? worker}) {
    final nameController = TextEditingController(text: worker?.name ?? '');
    final employeeIdController = TextEditingController(
      text: worker?.employeeId ?? '',
    );
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final emailController = TextEditingController(text: worker?.email ?? '');
    String? schoolId = worker?.schoolId;
    String? selectedRoleId = worker?.roleId;
    bool isActive = worker?.isActive ?? true;
    bool isSaving = false;
    final isEdit = worker != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }
    if (selectedRoleId != null &&
        !_rolesForSchool(schoolId).any((r) => r.id == selectedRoleId)) {
      selectedRoleId = null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (dialogCtx, setStateDialog) => AlertDialog(
                  backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                  title: Text(
                    isEdit ? 'Edit Worker' : 'Add Worker',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  content: SizedBox(
                    width: 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration(
                              'Full Name',
                              required: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (widget.schools.length > 1) ...[
                            DropdownButtonFormField<String?>(
                              initialValue: schoolId,
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
                                    if (selectedRoleId != null &&
                                        !_rolesForSchool(schoolId).any(
                                          (r) => r.id == selectedRoleId,
                                        )) {
                                      selectedRoleId = null;
                                    }
                                  }),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: employeeIdController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration('Employee ID'),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String?>(
                            key: ValueKey(
                              'worker-role-$schoolId-$selectedRoleId',
                            ),
                            initialValue: selectedRoleId,
                            decoration: adminInputDecoration('Role'),
                            dropdownColor:
                                Theme.of(dialogCtx).colorScheme.surface,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            items: _roleDropdownItems(schoolId),
                            onChanged: (v) =>
                                setStateDialog(() => selectedRoleId = v),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration('Phone'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration('Email'),
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
                            onChanged:
                                (v) => setStateDialog(() => isActive = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSaving ? null : () => Navigator.pop(dialogCtx),
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
                                if (nameController.text.trim().isEmpty ||
                                    schoolId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Name and school are required',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setStateDialog(() => isSaving = true);
                                try {
                                  final updated = Worker(
                                    id: worker?.id,
                                    name: nameController.text.trim(),
                                    schoolId: schoolId!,
                                    roleId: selectedRoleId,
                                    employeeId:
                                        employeeIdController.text.trim().isEmpty
                                            ? null
                                            : employeeIdController.text.trim(),
                                    phone:
                                        phoneController.text.trim().isEmpty
                                            ? null
                                            : phoneController.text.trim(),
                                    email:
                                        emailController.text.trim().isEmpty
                                            ? null
                                            : emailController.text.trim(),
                                    fingerprintData: worker?.fingerprintData,
                                    fingerprintTimestamp:
                                        worker?.fingerprintTimestamp,
                                    isActive: isActive,
                                    createdAt: worker?.createdAt,
                                  );
                                  if (isEdit) {
                                    await FirebaseService.updateWorker(updated);
                                  } else {
                                    await FirebaseService.addWorker(updated);
                                  }
                                  if (!mounted) return;
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Worker updated'
                                            : 'Worker added',
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
                        isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add'),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _confirmDelete(Worker w) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete Worker',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete "${w.name}"? This action cannot be undone.',
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
                    await FirebaseService.deleteWorker(w.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Worker deleted')),
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
