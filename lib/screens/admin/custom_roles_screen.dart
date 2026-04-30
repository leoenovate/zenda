import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../models/school.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
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
    final accent = _parseColor(role.color) ?? colorScheme.primary;
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
            backgroundColor: accent.withOpacity(0.15),
            radius: 20,
            child: Text(
              initial,
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
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

  static const List<String> _palette = [
    '#FF7043',
    '#26A69A',
    '#5C6BC0',
    '#AB47BC',
    '#EC407A',
    '#66BB6A',
    '#FFA726',
    '#42A5F5',
  ];

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var v = hex.replaceFirst('#', '');
    if (v.length == 6) v = 'FF$v';
    final parsed = int.tryParse(v, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  void _showFormDialog({Role? role}) {
    final nameController = TextEditingController(text: role?.name ?? '');
    final descriptionController = TextEditingController(
      text: role?.description ?? '',
    );
    String? schoolId = role?.schoolId;
    String? color = role?.color ?? _palette.first;
    final Set<String> appliesTo = {
      ...(role?.appliesTo ?? const [AuthRoles.kindWorker]),
    };
    bool isActive = role?.isActive ?? true;
    bool isSaving = false;
    final isEdit = role != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

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
                          const SizedBox(height: 16),
                          Text(
                            'Color',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final hex in _palette)
                                _ColorSwatch(
                                  hex: hex,
                                  selected: color == hex,
                                  onTap:
                                      () => setStateDialog(() => color = hex),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Applies to',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final kind in AuthRoles.allKinds)
                                FilterChip(
                                  label: Text(
                                    AuthRoles.kindLabelPlural(kind),
                                  ),
                                  selected: appliesTo.contains(kind),
                                  onSelected: (v) => setStateDialog(() {
                                    if (v) {
                                      appliesTo.add(kind);
                                    } else if (appliesTo.length > 1) {
                                      appliesTo.remove(kind);
                                    }
                                  }),
                                ),
                            ],
                          ),
                          if (isEdit) ...[
                            const SizedBox(height: 8),
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
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Role name is required'),
                                    ),
                                  );
                                  return;
                                }
                                if (schoolId == null || schoolId!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('A school is required'),
                                    ),
                                  );
                                  return;
                                }
                                if (appliesTo.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Pick at least one role kind',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setStateDialog(() => isSaving = true);
                                try {
                                  final orderedAppliesTo = [
                                    for (final k in AuthRoles.allKinds)
                                      if (appliesTo.contains(k)) k,
                                  ];
                                  if (isEdit) {
                                    final updated = role.copyWith(
                                      name: name,
                                      description:
                                          description.isEmpty
                                              ? null
                                              : description,
                                      schoolId: schoolId,
                                      color: color,
                                      appliesTo: orderedAppliesTo,
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
                                        schoolId: schoolId!,
                                        color: color,
                                        appliesTo: orderedAppliesTo,
                                      ),
                                    );
                                  }
                                  if (!mounted) return;
                                  Navigator.pop(dialogCtx);
                                  final msg =
                                      isEdit ? 'Role updated' : 'Role created';
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
                    final cleared =
                        await FirebaseService.clearRoleAssignments(
                          roleId: role.id!,
                          appliesTo: role.appliesTo,
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

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _CustomRolesScreenState._parseColor(hex) ?? Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child:
            selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
      ),
    );
  }
}
