import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/user.dart' as app_user;
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

/// Manages guardian (parent) login accounts. Guardians live in the `users`
/// collection (migrated from the old `parents` collection) and sign in with
/// phone + password.
class ParentsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const ParentsScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<ParentsScreen> createState() => _ParentsScreenState();
}

class _ParentsScreenState extends State<ParentsScreen> {
  bool _isLoading = true;
  List<app_user.AppUser> _guardians = [];
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
      final guardians = await FirebaseService.getGuardians();
      if (!mounted) return;
      setState(() {
        _guardians = guardians;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading guardians: $e')),
      );
    }
  }

  List<app_user.AppUser> get _filtered {
    return _guardians.where((p) {
      if (_schoolFilter != 'all' && p.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = (p.name ?? '').toLowerCase().contains(q) ||
            (p.phone ?? '').toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q);
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
      title: 'Guardians',
      subtitle: widget.showSchoolFilter
          ? 'Parent/guardian login accounts (phone + password)'
          : 'Guardian login accounts for your school',
      searchHint: 'Search by name, phone, or email...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'Add Guardian',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.family_restroom_outlined,
              message: 'No guardians found',
            )
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

  Widget _buildRow(app_user.AppUser p) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            radius: 20,
            child: Text(
              (p.name?.isNotEmpty ?? false) ? p.name![0].toUpperCase() : '?',
              style: TextStyle(
                color: scheme.primary,
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
                  p.name ?? '(no name)',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((p.phone ?? '').isNotEmpty) p.phone!,
                    if (p.email.isNotEmpty) p.email,
                    '${p.linkedStudentIds.length} children',
                  ].join(' \u00b7 '),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!p.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'INACTIVE',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Set / reset password',
            icon: Icon(Icons.key_outlined, size: 18, color: scheme.onSurfaceVariant),
            onPressed: () => _showPasswordDialog(p),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 18, color: scheme.onSurfaceVariant),
            onPressed: () => _showFormDialog(guardian: p),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            onPressed: () => _confirmDelete(p),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({app_user.AppUser? guardian}) {
    final nameController = TextEditingController(text: guardian?.name ?? '');
    final phoneController = TextEditingController(text: guardian?.phone ?? '');
    final passwordController = TextEditingController();
    String? schoolId = guardian?.schoolId;
    if (schoolId == null && widget.schools.length == 1) {
      schoolId = widget.schools.first.id;
    }
    bool isActive = guardian?.isActive ?? true;
    bool isSaving = false;
    final isEdit = guardian != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          title: Text(
            isEdit ? 'Edit Guardian' : 'Add Guardian',
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
                    decoration: adminInputDecoration('Full Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration('Phone', required: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: adminInputDecoration(
                      isEdit ? 'New password (optional)' : 'Login password',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.schools.length > 1) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: schoolId,
                      decoration: adminInputDecoration('School'),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Unassigned')),
                        ...widget.schools.map((s) =>
                            DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (v) => setStateDialog(() => schoolId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
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
                      if (phoneController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone is required')),
                        );
                        return;
                      }
                      setStateDialog(() => isSaving = true);
                      try {
                        final name = nameController.text.trim();
                        final password = passwordController.text.trim();
                        if (isEdit) {
                          final updated = guardian.copyWith(
                            name: name.isEmpty ? null : name,
                            phone: phoneController.text.trim(),
                            schoolId: schoolId,
                            isActive: isActive,
                          );
                          await FirebaseService.updateGuardian(updated);
                          if (password.isNotEmpty) {
                            await FirebaseService.setGuardianPassword(
                              guardian.id!,
                              password,
                            );
                          }
                        } else {
                          await FirebaseService.addGuardian(
                            name: name,
                            phone: phoneController.text.trim(),
                            schoolId: schoolId,
                            password: password.isEmpty ? null : password,
                          );
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Guardian updated' : 'Guardian added'),
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

  void _showPasswordDialog(app_user.AppUser p) {
    final passwordController = TextEditingController();
    bool isSaving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
          title: Text(
            'Set password',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set a login password for ${p.name ?? p.phone ?? 'this guardian'}.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: adminInputDecoration('New password', required: true),
                ),
              ],
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
                      final password = passwordController.text.trim();
                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password must be at least 6 characters'),
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => isSaving = true);
                      try {
                        await FirebaseService.setGuardianPassword(p.id!, password);
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password updated')),
                        );
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
              child: Text(isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(app_user.AppUser p) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
        title: Text('Delete Guardian', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Delete guardian account for ${p.name ?? p.phone ?? p.id}?',
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
                await FirebaseService.deleteGuardian(p.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guardian deleted')),
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
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
