import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../models/session.dart';
import '../../models/teacher.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class SessionsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;

  const SessionsScreen({super.key, required this.schools, this.onDataChanged});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _isLoading = true;
  List<Session> _sessions = [];
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
      final snap = await FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: true)
          .get();
      final teachers = await FirebaseService.getTeachers();
      if (!mounted) return;
      setState(() {
        _sessions = snap.docs.map((d) => Session.fromFirestore(d.data(), d.id)).toList();
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback without ordering if index is missing
      try {
        final snap = await FirebaseFirestore.instance.collection('sessions').get();
        final teachers = await FirebaseService.getTeachers();
        if (!mounted) return;
        final sessions = snap.docs
            .map((d) => Session.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _sessions = sessions;
          _teachers = teachers;
          _isLoading = false;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sessions: $e2')),
        );
      }
    }
  }

  List<Session> get _filtered {
    return _sessions.where((s) {
      if (_schoolFilter != 'all' && s.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = (s.className ?? '').toLowerCase().contains(q) ||
            (s.teacherName ?? '').toLowerCase().contains(q) ||
            (s.period ?? '').toLowerCase().contains(q);
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
      title: 'Sessions',
      subtitle: 'Daily class sessions and attendance windows',
      searchHint: 'Search by class, teacher, or period...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      addButtonLabel: 'New Session',
      onAddPressed: () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? const AdminEmptyState(
              icon: Icons.event_note_outlined,
              message: 'No sessions found',
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

  Widget _buildRow(Session s) {
    final schoolName = widget.schools
        .firstWhere((sc) => sc.id == s.schoolId,
            orElse: () => const School(name: 'Unknown school'))
        .name;

    final statusColor = s.isActive ? Colors.green : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.event_note, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(s.date)}${s.period != null ? ' · ${s.period}' : ''}',
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
                    if (s.className != null) 'Class: ${s.className}',
                    if (s.teacherName != null) 'Teacher: ${s.teacherName}',
                    if (s.startTime != null && s.endTime != null)
                      '${s.startTime} - ${s.endTime}',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.isActive ? 'ACTIVE' : 'ENDED',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          if (s.isActive)
            IconButton(
              icon: const Icon(Icons.stop_circle, size: 20, color: Colors.orange),
              tooltip: 'End session',
              onPressed: () => _endSession(s),
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF666666)),
            onPressed: () => _showFormDialog(session: s),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(s),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showFormDialog({Session? session}) {
    final dateController = TextEditingController(
      text: session != null ? _formatDate(session.date) : _formatDate(DateTime.now()),
    );
    final startController = TextEditingController(text: session?.startTime ?? '');
    final endController = TextEditingController(text: session?.endTime ?? '');
    final classNameController = TextEditingController(text: session?.className ?? '');
    String period = session?.period ?? 'Morning';
    String? schoolId = session?.schoolId;
    String? teacherId = session?.teacherId;
    bool isActive = session?.isActive ?? true;
    bool isSaving = false;
    final isEdit = session != null;
    DateTime pickedDate = session?.date ?? DateTime.now();

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
              isEdit ? 'Edit Session' : 'New Session',
              style: const TextStyle(color: Color(0xFF2C2C2C)),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      controller: dateController,
                      readOnly: true,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      decoration: adminInputDecoration('Date', required: true).copyWith(
                        suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF666666)),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          pickedDate = picked;
                          dateController.text = _formatDate(picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: period,
                      decoration: adminInputDecoration('Period'),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      items: const [
                        DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                      ],
                      onChanged: (v) => setStateDialog(() => period = v ?? 'Morning'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            style: const TextStyle(color: Color(0xFF2C2C2C)),
                            decoration: adminInputDecoration('Start (HH:mm)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            style: const TextStyle(color: Color(0xFF2C2C2C)),
                            decoration: adminInputDecoration('End (HH:mm)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: classNameController,
                      style: const TextStyle(color: Color(0xFF2C2C2C)),
                      decoration: adminInputDecoration('Class name'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: teachersForSchool.any((t) => t.id == teacherId)
                          ? teacherId
                          : null,
                      decoration: adminInputDecoration('Teacher'),
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
                        if (schoolId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('School is required')),
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
                          final updated = Session(
                            id: session?.id,
                            schoolId: schoolId!,
                            date: pickedDate,
                            isActive: isActive,
                            period: period,
                            startTime: startController.text.trim().isEmpty
                                ? null
                                : startController.text.trim(),
                            endTime: endController.text.trim().isEmpty
                                ? null
                                : endController.text.trim(),
                            className: classNameController.text.trim().isEmpty
                                ? null
                                : classNameController.text.trim(),
                            teacherId: teacherId,
                            teacherName: (teacher != null && teacher.name.isNotEmpty)
                                ? teacher.name
                                : null,
                          );
                          if (isEdit) {
                            await FirebaseService.updateSession(updated);
                          } else {
                            await FirebaseService.createSession(updated);
                          }
                          if (!mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Session updated' : 'Session created'),
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
                child: Text(isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Create')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _endSession(Session s) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('End Session', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: const Text(
          'Mark this session as ended? Attendance recording will stop.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.endSession(s.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session ended')),
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Session s) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Session', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: const Text(
          'Delete this session? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.deleteSession(s.id!);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session deleted')),
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
