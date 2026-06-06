import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../models/school.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

/// Admin-list screen for managing custom role definitions for a school.
/// Distinct from built-in system roles (admin/teacher/parent/worker/student);
/// these are free-form labels schools can attach to staff.
class CustomRolesScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;
  final String? focusedRoleId;
  final String? titleOverride;
  final String? subtitleOverride;

  /// Optional callback fired with `(focusForm: true)` shortly after mount when
  /// the caller wants the create dialog to open immediately (e.g. when
  /// arriving from the sidebar's "Add new role" button).
  final bool autoOpenForm;

  const CustomRolesScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
    this.focusedRoleId,
    this.titleOverride,
    this.subtitleOverride,
    this.autoOpenForm = false,
  });

  @override
  State<CustomRolesScreen> createState() => _CustomRolesScreenState();
}

class _CustomRolesScreenState extends State<CustomRolesScreen> {
  bool _isLoading = true;
  List<Role> _roles = [];
  String _searchQuery = '';
  String _schoolFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.autoOpenForm && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showFormDialog();
        });
      }
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final roles = await FirebaseService.getRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading roles: $e')));
    }
  }

  List<Role> get _filtered {
    return _roles.where((r) {
      if (widget.focusedRoleId != null && r.id != widget.focusedRoleId) {
        return false;
      }
      if (_schoolFilter != 'all' && r.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            r.name.toLowerCase().contains(q) ||
            (r.description ?? '').toLowerCase().contains(q);
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
      title: widget.titleOverride ?? 'Roles',
      subtitle:
          widget.subtitleOverride ??
          (widget.showSchoolFilter
              ? 'Define additional staff role labels per school'
              : 'Define additional staff role labels for your school'),
      searchHint: 'Search by name or description...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'Add Role',
      onAddPressed: _showFormDialog,
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.badge_outlined,
                message: 'No roles yet',
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

  Widget _buildRow(Role role) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = role.name.isNotEmpty ? role.name[0].toUpperCase() : '?';
    final schoolName =
        widget.schools
            .firstWhere(
              (s) => s.id == role.schoolId,
              orElse: () => const School(name: 'Unassigned'),
            )
            .name;

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
                  role.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (widget.showSchoolFilter && widget.schools.length > 1)
                      schoolName,
                    if (role.description != null &&
                        role.description!.isNotEmpty)
                      role.description!,
                    if (!role.isActive) 'Inactive',
                  ].where((s) => s.isNotEmpty).join(' · '),
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
              Icons.edit,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Edit',
            onPressed: () => _showFormDialog(role: role),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(role),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Dialogs
  // ----------------------------------------------------------------------

  String? _resolveSchoolId({Role? role}) {
    final fromRole = role?.schoolId;
    if (fromRole != null && fromRole.isNotEmpty) return fromRole;
    for (final s in widget.schools) {
      final id = s.id;
      if (id != null && id.isNotEmpty) return id;
    }
    final sessionId = AuthService.currentSchoolId;
    if (sessionId != null && sessionId.isNotEmpty) return sessionId;
    return null;
  }

  void _showFormDialog({Role? role}) {
    final nameController = TextEditingController(text: role?.name ?? '');
    final descriptionController = TextEditingController(
      text: role?.description ?? '',
    );
    String? schoolId = _resolveSchoolId(role: role);
    bool isActive = role?.isActive ?? true;
    bool isSaving = false;
    String? formError;
    final isEdit = role != null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder:
                (dialogCtx, setStateDialog) => AlertDialog(
                  backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                  title: Text(
                    isEdit ? 'Edit Role' : 'Add Role',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
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
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration(
                              'Role name',
                              required: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descriptionController,
                            maxLines: 2,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: adminInputDecoration('Description'),
                          ),
                          if (widget.schools.length > 1) ...[
                            const SizedBox(height: 16),
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
                                  (v) => setStateDialog(() => schoolId = v),
                            ),
                          ],
                          if (isEdit) ...[
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: isActive,
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              title: Text(
                                'Active',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              onChanged:
                                  (v) => setStateDialog(() => isActive = v),
                            ),
                          ],
                          if (formError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              formError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                                final name = nameController.text.trim();
                                final description =
                                    descriptionController.text.trim();
                                final effectiveSchoolId =
                                    schoolId ?? _resolveSchoolId(role: role);
                                if (name.isEmpty) {
                                  setStateDialog(
                                    () => formError = 'Role name is required',
                                  );
                                  return;
                                }
                                if (effectiveSchoolId == null ||
                                    effectiveSchoolId.isEmpty) {
                                  setStateDialog(
                                    () =>
                                        formError =
                                            'Could not determine your school. '
                                            'Sign out and sign in again.',
                                  );
                                  return;
                                }
                                setStateDialog(() {
                                  formError = null;
                                  isSaving = true;
                                });
                                try {
                                  if (isEdit) {
                                    final updated = role.copyWith(
                                      name: name,
                                      description:
                                          description.isEmpty
                                              ? null
                                              : description,
                                      schoolId: effectiveSchoolId,
                                      isActive: isActive,
                                    );
                                    await FirebaseService.updateRole(updated);
                                  } else {
                                    await FirebaseService.addRole(
                                      Role(
                                        name: name,
                                        description:
                                            description.isEmpty
                                                ? null
                                                : description,
                                        schoolId: effectiveSchoolId,
                                      ),
                                    );
                                  }
                                  if (!context.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  final msg =
                                      isEdit ? 'Role updated' : 'Role created';
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(msg)));
                                  await _load();
                                  widget.onDataChanged?.call();
                                } catch (e) {
                                  if (!dialogCtx.mounted) return;
                                  setStateDialog(() {
                                    isSaving = false;
                                    formError = e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    );
                                  });
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
                ),
          ),
    );
  }

  void _confirmDelete(Role role) {
    showDialog<void>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete role',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete "${role.name}"? This cannot be undone.',
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
