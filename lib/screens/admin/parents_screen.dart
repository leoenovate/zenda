import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/parent.dart' as app_parent;
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class ParentsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const ParentsScreen({super.key, required this.schools, this.onDataChanged});

  @override
  State<ParentsScreen> createState() => _ParentsScreenState();
}

class _ParentsScreenState extends State<ParentsScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  List<app_parent.Parent> _parents = [];
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
      final parents = await FirebaseService.getParents();
      if (!mounted) return;
      setState(() {
        _parents = parents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading parents: $e')),
      );
    }
  }

  Future<void> _syncFromStudents() async {
    setState(() => _isSyncing = true);
    try {
      final created = await FirebaseService.syncParentsFromStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $created parent records from students')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<app_parent.Parent> get _filtered {
    return _parents.where((p) {
      if (_schoolFilter != 'all' && p.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = (p.name ?? '').toLowerCase().contains(q) ||
            p.phone.toLowerCase().contains(q) ||
            (p.email ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A5F5F)),
        ),
      );
    }

    final filtered = _filtered;
    return AdminListScaffold(
      title: 'Parents',
      subtitle: 'Parent contacts derived from student records',
      searchHint: 'Search by name, phone, or email...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      addButtonLabel: 'Add Parent',
      onAddPressed: () => _showFormDialog(),
      headerExtras: OutlinedButton.icon(
        onPressed: _isSyncing ? null : _syncFromStudents,
        icon: _isSyncing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync, size: 18),
        label: Text(_isSyncing ? 'Syncing...' : 'Sync from students'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A5F5F),
          side: const BorderSide(color: Color(0xFF1A5F5F)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.family_restroom_outlined,
              message: 'No parents found',
            )
          : AdminListCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                itemBuilder: (_, i) => _buildRow(filtered[i]),
              ),
            ),
    );
  }

  Widget _buildRow(app_parent.Parent p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.withOpacity(0.15),
            radius: 20,
            child: Text(
              (p.name?.isNotEmpty ?? false) ? p.name![0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.orange,
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
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    p.phone,
                    if (p.relationship != null) p.relationship!,
                    if (p.email != null) p.email!,
                    '${p.studentIds.length} children',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          ),
          if (!p.isActive)
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
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF666666)),
            onPressed: () => _showFormDialog(parent: p),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(p),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({app_parent.Parent? parent}) {
    final nameController = TextEditingController(text: parent?.name ?? '');
    final phoneController = TextEditingController(text: parent?.phone ?? '');
    final emailController = TextEditingController(text: parent?.email ?? '');
    String relationship = parent?.relationship ?? 'father';
    String? schoolId = parent?.schoolId;
    bool isActive = parent?.isActive ?? true;
    bool isSaving = false;
    final isEdit = parent != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            isEdit ? 'Edit Parent' : 'Add Parent',
            style: const TextStyle(color: Color(0xFF2C2C2C)),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Full Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Phone', required: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Email'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: relationship,
                    decoration: adminInputDecoration('Relationship'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    items: const [
                      DropdownMenuItem(value: 'father', child: Text('Father')),
                      DropdownMenuItem(value: 'mother', child: Text('Mother')),
                      DropdownMenuItem(value: 'guardian', child: Text('Guardian')),
                    ],
                    onChanged: (v) => setStateDialog(() => relationship = v ?? 'father'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: schoolId,
                    decoration: adminInputDecoration('School'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Unassigned')),
                      ...widget.schools.map((s) =>
                          DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setStateDialog(() => schoolId = v),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    activeColor: const Color(0xFF1A5F5F),
                    title: const Text('Active', style: TextStyle(color: Color(0xFF2C2C2C))),
                    onChanged: (v) => setStateDialog(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
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
                        final updated = app_parent.Parent(
                          id: parent?.id,
                          phone: phoneController.text.trim(),
                          name: nameController.text.trim().isEmpty
                              ? null
                              : nameController.text.trim(),
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          relationship: relationship,
                          studentIds: parent?.studentIds ?? const [],
                          schoolId: schoolId,
                          isActive: isActive,
                          createdAt: parent?.createdAt,
                          lastLogin: parent?.lastLogin,
                        );
                        if (isEdit) {
                          await FirebaseService.updateParent(updated);
                        } else {
                          await FirebaseService.addParent(updated);
                        }
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Parent updated' : 'Parent added'),
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
                backgroundColor: const Color(0xFF1A5F5F),
                foregroundColor: Colors.white,
              ),
              child: Text(isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(app_parent.Parent p) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Parent', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: Text(
          'Delete parent record for ${p.name ?? p.phone}?',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.deleteParent(p.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Parent deleted')),
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
