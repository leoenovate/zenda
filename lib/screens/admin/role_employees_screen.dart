import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

const List<String> _kRoleColorPalette = [
  '#FF7043',
  '#26A69A',
  '#5C6BC0',
  '#AB47BC',
  '#EC407A',
  '#66BB6A',
  '#FFA726',
  '#42A5F5',
];

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var v = hex.replaceFirst('#', '');
  if (v.length == 6) v = 'FF$v';
  final parsed = int.tryParse(v, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

/// Lists every worker assigned to a single custom [role] (via the
/// `workers/{id}.role` string field), and provides actions to add new
/// employees to this role, move them to another role, or remove them
/// from the role.
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
  List<Worker> _workers = [];
  String _searchQuery = '';

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
      final workers = await FirebaseService.getWorkers();
      if (!mounted) return;
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
    }
  }

  /// Workers whose `role` field matches the focused role's name (case-
  /// insensitive). We match on the name string since `Worker.role` is a
  /// free-form label that's been used historically; rename/delete cascade
  /// keeps it in sync when the role definition changes.
  bool _isInThisRole(Worker w) {
    final r = (w.role ?? '').trim().toLowerCase();
    return r == widget.role.name.trim().toLowerCase();
  }

  List<Worker> get _assigned {
    final roleSchoolId = widget.role.schoolId;
    return _workers.where((w) {
      if (w.schoolId != roleSchoolId) return false;
      if (!_isInThisRole(w)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            w.name.toLowerCase().contains(q) ||
            (w.employeeId ?? '').toLowerCase().contains(q) ||
            (w.email ?? '').toLowerCase().contains(q) ||
            (w.phone ?? '').toLowerCase().contains(q);
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

    final filtered = _assigned;
    final desc = widget.role.description;
    return AdminListScaffold(
      title: widget.role.name,
      subtitle:
          (desc != null && desc.isNotEmpty)
              ? desc
              : 'Manage employees assigned to this role',
      searchHint: 'Search assigned employees...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: 'all',
      onSchoolFilterChanged: (_) {},
      showSchoolFilter: false,
      addButtonLabel: 'Add employee',
      onAddPressed: _openAddDialog,
      headerExtras: OutlinedButton.icon(
        onPressed: _openEditRoleDialog,
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Edit role'),
      ),
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.engineering_outlined,
                message: 'No employees assigned to this role yet',
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

  Widget _buildAssignedRow(Worker w) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.15),
            radius: 20,
            child: Text(
              w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
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
                  w.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (w.employeeId != null && w.employeeId!.isNotEmpty)
                      'ID: ${w.employeeId}',
                    if (w.phone != null && w.phone!.isNotEmpty) w.phone!,
                    if (w.email != null && w.email!.isNotEmpty) w.email!,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
                  _openMoveDialog(w);
                  break;
                case _RowAction.remove:
                  _confirmRemove(w);
                  break;
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem<_RowAction>(
                    value: _RowAction.move,
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('Move to another role'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_RowAction>(
                    value: _RowAction.remove,
                    child: Row(
                      children: [
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

  /// Picker dialog used by the "Add employee" button. Lists every worker
  /// in the same school that isn't already in this role; tapping a worker
  /// assigns them. If the worker already belongs to a different role, the
  /// caller is asked to confirm the move.
  Future<void> _openAddDialog() async {
    final available =
        _workers
            .where(
              (w) => w.schoolId == widget.role.schoolId && !_isInThisRole(w),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every worker in this school is already assigned'),
        ),
      );
      return;
    }

    String query = '';
    final selected = <String>{};
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              final filtered =
                  available.where((w) {
                    if (query.isEmpty) return true;
                    final q = query.toLowerCase();
                    return w.name.toLowerCase().contains(q) ||
                        (w.employeeId ?? '').toLowerCase().contains(q) ||
                        (w.email ?? '').toLowerCase().contains(q) ||
                        (w.phone ?? '').toLowerCase().contains(q);
                  }).toList();

              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  'Add employees to ${widget.role.name}',
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
                            filtered.isEmpty
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
                                    final w = filtered[i];
                                    final id = w.id ?? '';
                                    final hasOtherRole =
                                        (w.role ?? '').trim().isNotEmpty;
                                    final isSelected = selected.contains(id);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (v) {
                                        if (id.isEmpty) return;
                                        setStateDialog(() {
                                          if (v == true) {
                                            selected.add(id);
                                          } else {
                                            selected.remove(id);
                                          }
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        w.name,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (w.employeeId != null &&
                                              w.employeeId!.isNotEmpty)
                                            'ID: ${w.employeeId}',
                                          if (hasOtherRole)
                                            'Currently: ${w.role}'
                                          else
                                            'Unassigned',
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
                                                    'Will be moved from ${w.role}',
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
                                await FirebaseService.setWorkersRole(
                                  workerIds: selected.toList(),
                                  roleName: widget.role.name,
                                );
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Assigned ${selected.length} '
                                      '${selected.length == 1 ? 'employee' : 'employees'} '
                                      'to ${widget.role.name}',
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

  Future<void> _openMoveDialog(Worker worker) async {
    final otherRoles =
        widget.allRoles
            .where(
              (r) =>
                  r.id != widget.role.id &&
                  r.schoolId == widget.role.schoolId &&
                  r.isActive,
            )
            .toList();

    String? targetRoleName;
    bool clearInstead = false;
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
                  'Move ${worker.name}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Currently in ${widget.role.name}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (otherRoles.isEmpty)
                        Text(
                          'No other roles defined yet.',
                          style: TextStyle(color: colorScheme.onSurface),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          initialValue: targetRoleName,
                          decoration: const InputDecoration(
                            labelText: 'Move to role',
                          ),
                          items: [
                            for (final r in otherRoles)
                              DropdownMenuItem<String?>(
                                value: r.name,
                                child: Text(r.name),
                              ),
                          ],
                          onChanged:
                              (v) => setStateDialog(() {
                                targetRoleName = v;
                                clearInstead = false;
                              }),
                        ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: clearInstead,
                        onChanged:
                            (v) => setStateDialog(() {
                              clearInstead = v ?? false;
                              if (clearInstead) targetRoleName = null;
                            }),
                        title: Text(
                          'Remove role assignment instead',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
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
                                worker.id == null ||
                                (targetRoleName == null && !clearInstead))
                            ? null
                            : () async {
                              setStateDialog(() => isSaving = true);
                              try {
                                await FirebaseService.setWorkersRole(
                                  workerIds: [worker.id!],
                                  roleName:
                                      clearInstead ? null : targetRoleName,
                                );
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      clearInstead
                                          ? '${worker.name} removed from role'
                                          : '${worker.name} moved to $targetRoleName',
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
    String color = role.color ?? _kRoleColorPalette.first;
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
                title: Text(
                  'Edit role',
                  style: TextStyle(color: colorScheme.onSurface),
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
                        const SizedBox(height: 16),
                        Text(
                          'Color',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final hex in _kRoleColorPalette)
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setStateDialog(() => color = hex),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _parseHexColor(hex) ?? Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          color == hex
                                              ? colorScheme.onSurface
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      color == hex
                                          ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          )
                                          : null,
                                ),
                              ),
                          ],
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
                  const Spacer(),
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
                                  color: color,
                                  isActive: isActive,
                                );
                                await FirebaseService.updateRole(updated);
                                int renamed = 0;
                                if (role.name != name) {
                                  renamed =
                                      await FirebaseService.renameWorkersRole(
                                        oldName: role.name,
                                        newName: name,
                                        schoolId: role.schoolId,
                                      );
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                final msg =
                                    renamed > 0
                                        ? 'Role updated · '
                                            '$renamed ${renamed == 1 ? 'employee' : 'employees'} '
                                            'reassigned'
                                        : 'Role updated';
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
                    final cleared = await FirebaseService.clearWorkersRole(
                      roleName: role.name,
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

  Future<void> _confirmRemove(Worker worker) async {
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
              'Remove ${worker.name} from "${widget.role.name}"? '
              'The worker record stays — only the role assignment is cleared.',
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
                  if (worker.id == null) {
                    Navigator.pop(dialogCtx);
                    return;
                  }
                  try {
                    await FirebaseService.setWorkersRole(
                      workerIds: [worker.id!],
                      roleName: null,
                    );
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${worker.name} removed from ${widget.role.name}',
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
