import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/class_group.dart';
import '../../models/teacher.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class ClassesScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const ClassesScreen({super.key, required this.schools, this.onDataChanged});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool _isLoading = true;
  List<ClassGroup> _classes = [];
  List<Teacher> _teachers = [];
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
      final results = await Future.wait([
        FirebaseService.getClasses(),
        FirebaseService.getTeachers(),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = results[0] as List<ClassGroup>;
        _teachers = results[1] as List<Teacher>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
    }
  }

  List<ClassGroup> get _filtered {
    return _classes.where((c) {
      if (_schoolFilter != 'all' && c.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = c.name.toLowerCase().contains(q) ||
            (c.grade ?? '').toLowerCase().contains(q) ||
            (c.level ?? '').toLowerCase().contains(q);
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
      title: 'Classes',
      subtitle: 'Manage class groups and student assignments',
      searchHint: 'Search by name, grade, or level...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      addButtonLabel: 'Add Class',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(icon: Icons.class_outlined, message: 'No classes found')
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

  Widget _buildRow(ClassGroup c) {
    final schoolName = widget.schools
        .firstWhere((s) => s.id == c.schoolId,
            orElse: () => const School(name: 'Unknown school'))
        .name;
    final teacherName = c.teacherName ??
        _teachers
            .firstWhere(
              (t) => t.id == c.teacherId,
              orElse: () => const Teacher(name: '', schoolId: ''),
            )
            .name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.class_, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
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
                    if (c.grade != null) c.grade!,
                    if (teacherName.isNotEmpty) 'Teacher: $teacherName',
                    '${c.studentIds.length} students',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF666666)),
            onPressed: () => _showFormDialog(group: c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(c),
          ),
        ],
      ),
    );
  }

  void _showFormDialog({ClassGroup? group}) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final gradeController = TextEditingController(text: group?.grade ?? '');
    final levelController = TextEditingController(text: group?.level ?? '');
    String? schoolId = group?.schoolId;
    String? teacherId = group?.teacherId;
    bool isActive = group?.isActive ?? true;
    bool isSaving = false;
    final isEdit = group != null;

    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          final teachersForSchool = _teachers.where((t) => t.schoolId == schoolId).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              isEdit ? 'Edit Class' : 'Add Class',
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
                      decoration: adminInputDecoration('Class Name', required: true),
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
                      onChanged: (v) => setStateDialog(() {
                        schoolId = v;
                        teacherId = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: gradeController,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      decoration: adminInputDecoration('Grade (e.g. "P4")'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: levelController,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      decoration: adminInputDecoration('Level (e.g. "Primary")'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: teachersForSchool.any((t) => t.id == teacherId)
                          ? teacherId
                          : null,
                      decoration: adminInputDecoration('Class Teacher'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('Unassigned')),
                        ...teachersForSchool.map((t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name),
                            )),
                      ],
                      onChanged: (v) => setStateDialog(() => teacherId = v),
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
                          final teacher = teacherId == null
                              ? null
                              : _teachers.firstWhere(
                                  (t) => t.id == teacherId,
                                  orElse: () => const Teacher(name: '', schoolId: ''),
                                );
                          final updated = ClassGroup(
                            id: group?.id,
                            name: nameController.text.trim(),
                            schoolId: schoolId!,
                            grade: gradeController.text.trim().isEmpty
                                ? null
                                : gradeController.text.trim(),
                            level: levelController.text.trim().isEmpty
                                ? null
                                : levelController.text.trim(),
                            teacherId: teacherId,
                            teacherName:
                                (teacher != null && teacher.name.isNotEmpty) ? teacher.name : null,
                            studentIds: group?.studentIds ?? const [],
                            isActive: isActive,
                            createdAt: group?.createdAt,
                          );
                          if (isEdit) {
                            await FirebaseService.updateClass(updated);
                          } else {
                            await FirebaseService.addClass(updated);
                          }
                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Class updated' : 'Class added'),
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
          );
        },
      ),
    );
  }

  void _confirmDelete(ClassGroup c) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Class', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: Text(
          'Delete class "${c.name}"? This action cannot be undone.',
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
                await FirebaseService.deleteClass(c.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Class deleted')),
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
