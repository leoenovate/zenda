import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class WorkersScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const WorkersScreen({super.key, required this.schools, this.onDataChanged});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  bool _isLoading = true;
  List<Worker> _workers = [];
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
      final workers = await FirebaseService.getWorkers();
      if (!mounted) return;
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading workers: $e')),
      );
    }
  }

  List<Worker> get _filtered {
    return _workers.where((w) {
      if (_schoolFilter != 'all' && w.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = w.name.toLowerCase().contains(q) ||
            (w.role ?? '').toLowerCase().contains(q) ||
            (w.employeeId ?? '').toLowerCase().contains(q);
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
      title: 'Workers',
      subtitle: 'Non-student staff attendance (kitchen, cleaners, security)',
      searchHint: 'Search by name, role, or employee ID...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      addButtonLabel: 'Add Worker',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.engineering_outlined,
              message: 'No workers found',
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

  Widget _buildRow(Worker w) {
    final schoolName = widget.schools
        .firstWhere((s) => s.id == w.schoolId,
            orElse: () => const School(name: 'Unknown school'))
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
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    schoolName,
                    if (w.role != null) w.role!,
                    if (w.employeeId != null) 'ID: ${w.employeeId}',
                    if (w.fingerprintData != null) 'Fingerprint on file',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF666666)),
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
    final roleController = TextEditingController(text: worker?.role ?? '');
    final employeeIdController = TextEditingController(text: worker?.employeeId ?? '');
    final phoneController = TextEditingController(text: worker?.phone ?? '');
    final emailController = TextEditingController(text: worker?.email ?? '');
    String? schoolId = worker?.schoolId;
    bool isActive = worker?.isActive ?? true;
    bool isSaving = false;
    final isEdit = worker != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            isEdit ? 'Edit Worker' : 'Add Worker',
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
                    decoration: adminInputDecoration('Full Name', required: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: schoolId,
                    decoration: adminInputDecoration('School', required: true),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    items: widget.schools
                        .map((s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => schoolId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roleController,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Role (e.g. "Cook")'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: employeeIdController,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Employee ID'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Phone'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFF2C2C2C)),
                    decoration: adminInputDecoration('Email'),
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
                      if (nameController.text.trim().isEmpty || schoolId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name and school are required')),
                        );
                        return;
                      }
                      setStateDialog(() => isSaving = true);
                      try {
                        final updated = Worker(
                          id: worker?.id,
                          name: nameController.text.trim(),
                          schoolId: schoolId!,
                          role: roleController.text.trim().isEmpty
                              ? null
                              : roleController.text.trim(),
                          employeeId: employeeIdController.text.trim().isEmpty
                              ? null
                              : employeeIdController.text.trim(),
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          fingerprintData: worker?.fingerprintData,
                          fingerprintTimestamp: worker?.fingerprintTimestamp,
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
                            content: Text(isEdit ? 'Worker updated' : 'Worker added'),
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

  void _confirmDelete(Worker w) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Worker', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: Text(
          'Delete "${w.name}"? This action cannot be undone.',
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
                await FirebaseService.deleteWorker(w.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Worker deleted')),
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
