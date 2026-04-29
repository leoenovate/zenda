import 'package:flutter/material.dart';

import '../../models/school.dart';
import '../../models/user.dart' as app_user;
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

/// Admin-list screen showing every user with `role == 'admin'` for the
/// current scope (the school admin's `schoolId`, courtesy of
/// `FirebaseService._scoped`).
class AdminsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const AdminsScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  bool _isLoading = true;
  List<app_user.AppUser> _admins = [];
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
      final users = await FirebaseService.getUsers();
      if (!mounted) return;
      setState(() {
        _admins = users
            .where((u) =>
                (u.role ?? '').toLowerCase() == 'admin' ||
                (u.role ?? '').toLowerCase() == 'school_admin')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading admins: $e')),
      );
    }
  }

  List<app_user.AppUser> get _filtered {
    return _admins.where((a) {
      if (_schoolFilter != 'all' && a.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = (a.name ?? '').toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            (a.phone ?? '').toLowerCase().contains(q);
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
      title: 'Administrators',
      subtitle: 'School administrators with full management access',
      searchHint: 'Search by name, email, or phone...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'Add Administrator',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.admin_panel_settings_outlined,
              message: 'No administrators found',
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

  Widget _buildRow(app_user.AppUser admin) {
    final colorScheme = Theme.of(context).colorScheme;
    final schoolName = widget.schools
        .firstWhere(
          (s) => s.id == admin.schoolId,
          orElse: () => const School(name: 'Unassigned'),
        )
        .name;
    final initial = (admin.name ?? admin.email).isNotEmpty
        ? (admin.name ?? admin.email)[0].toUpperCase()
        : '?';

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
                  admin.name?.isNotEmpty == true ? admin.name! : admin.email,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    admin.email,
                    schoolName,
                    if (admin.phone != null && admin.phone!.isNotEmpty)
                      admin.phone!,
                    if (!admin.isActive) 'Inactive',
                  ].join(' · '),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (admin.isActive ? Colors.green : Colors.grey)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              admin.isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                color: admin.isActive ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Edit',
            onPressed: () => _showFormDialog(admin: admin),
          ),
          IconButton(
            icon: Icon(
              Icons.lock_reset,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Send password reset',
            onPressed: () => _showResetPasswordDialog(admin),
          ),
          IconButton(
            icon: Icon(
              admin.isActive ? Icons.block : Icons.check_circle,
              size: 18,
              color: admin.isActive
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
            ),
            tooltip: admin.isActive ? 'Deactivate' : 'Reactivate',
            onPressed: () => _toggleActive(admin),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({app_user.AppUser? admin}) {
    final nameController = TextEditingController(text: admin?.name ?? '');
    final emailController = TextEditingController(text: admin?.email ?? '');
    final phoneController = TextEditingController(text: admin?.phone ?? '');
    final passwordController = TextEditingController();
    String? schoolId = admin?.schoolId;
    bool isActive = admin?.isActive ?? true;
    bool isSaving = false;
    final isEdit = admin != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          title: Text(
            isEdit ? 'Edit Administrator' : 'Add Administrator',
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
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration:
                        adminInputDecoration('Full Name', required: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    enabled: !isEdit,
                    keyboardType: TextInputType.emailAddress,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Email', required: true),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: adminInputDecoration(
                        'Temporary Password',
                        required: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Phone'),
                  ),
                  if (widget.schools.length > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: schoolId,
                      decoration:
                          adminInputDecoration('School', required: true),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      items: widget.schools
                          .map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => schoolId = v),
                    ),
                  ],
                  if (isEdit) ...[
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
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final phone = phoneController.text.trim();
                      final password = passwordController.text;

                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name and email are required'),
                          ),
                        );
                        return;
                      }
                      if (!isEdit && password.length < 6) {
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
                        if (isEdit) {
                          final updated = app_user.AppUser(
                            id: admin.id,
                            email: admin.email,
                            name: name,
                            role: admin.role ?? 'admin',
                            schoolId: schoolId ?? admin.schoolId,
                            phone: phone.isEmpty ? null : phone,
                            isActive: isActive,
                            createdAt: admin.createdAt,
                            lastLogin: admin.lastLogin,
                          );
                          await FirebaseService.updateAdmin(updated);
                        } else {
                          await FirebaseService.addAdmin(
                            email: email,
                            password: password,
                            role: 'admin',
                            name: name,
                            schoolId: schoolId,
                            phone: phone.isEmpty ? null : phone,
                          );
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? 'Administrator updated'
                                  : 'Administrator created',
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
        ),
      ),
    );
  }

  void _showResetPasswordDialog(app_user.AppUser admin) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
        title: Text(
          'Reset Password',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Send a password reset email to ${admin.email}?',
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
                await FirebaseService.resetAdminPassword(admin.email);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reset email sent to ${admin.email}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _toggleActive(app_user.AppUser admin) {
    final willDeactivate = admin.isActive;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
        title: Text(
          willDeactivate
              ? 'Deactivate Administrator'
              : 'Reactivate Administrator',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate ${admin.name ?? admin.email}?'
              : 'Reactivate ${admin.name ?? admin.email}?',
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
                await FirebaseService.setAdminActive(
                  admin.id!,
                  !willDeactivate,
                );
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      willDeactivate
                          ? 'Administrator deactivated'
                          : 'Administrator reactivated',
                    ),
                  ),
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
              backgroundColor: willDeactivate
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(willDeactivate ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
  }
}
