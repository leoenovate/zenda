import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/school.dart';
import '../../models/staff_time_off.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';

class StaffTimeOffScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const StaffTimeOffScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<StaffTimeOffScreen> createState() => _StaffTimeOffScreenState();
}

class _TimeOffPerson {
  final String assigneeKind;
  final String id;
  final String name;
  final String schoolId;

  const _TimeOffPerson({
    required this.assigneeKind,
    required this.id,
    required this.name,
    required this.schoolId,
  });

  String get compoundKey => '$assigneeKind:$id';

  String get menuLabel {
    final role = switch (assigneeKind) {
      'teacher' => 'Teacher',
      'admin' => 'Administrator',
      'staff' => 'Staff',
      _ => 'Worker',
    };
    return '$role · $name';
  }
}

class _StaffTimeOffScreenState extends State<StaffTimeOffScreen> {
  static final _dateFmt = DateFormat.yMMMd();

  bool _isLoading = true;
  List<Worker> _workers = [];
  List<Teacher> _teachers = [];
  List<app_user.AppUser> _users = [];
  List<StaffTimeOff> _entries = [];
  String _searchQuery = '';
  String _schoolFilter = 'all';
  String _personFilter = 'all';
  String _roleKindFilter = 'all';
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isSchoolAdminUser(app_user.AppUser u) {
    final r = (u.role ?? '').toLowerCase();
    return r == 'admin' || r == 'school_admin' || r == 'staff';
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getWorkers(),
        FirebaseService.getTeachers(),
        FirebaseService.getUsers(),
        FirebaseService.getStaffTimeOffs(),
      ]);
      if (!mounted) return;
      setState(() {
        _workers = results[0] as List<Worker>;
        _teachers = results[1] as List<Teacher>;
        _users = results[2] as List<app_user.AppUser>;
        _entries = results[3] as List<StaffTimeOff>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading time off: $e')),
      );
    }
  }

  List<_TimeOffPerson> get _peopleForSchoolFilter {
    final kindOrder = ['teacher', 'admin', 'staff', 'worker'];
    final out = <_TimeOffPerson>[];

    for (final t in _teachers) {
      if (!t.isActive || t.id == null) continue;
      if (_schoolFilter != 'all' && t.schoolId != _schoolFilter) continue;
      out.add(
        _TimeOffPerson(
          assigneeKind: 'teacher',
          id: t.id!,
          name: t.name,
          schoolId: t.schoolId,
        ),
      );
    }

    for (final u in _users) {
      if (!u.isActive || u.id == null) continue;
      if (!_isSchoolAdminUser(u)) continue;
      final sid = u.schoolId;
      if (sid == null || sid.isEmpty) continue;
      if (_schoolFilter != 'all' && sid != _schoolFilter) continue;
      final displayName = (u.name != null && u.name!.trim().isNotEmpty)
          ? u.name!.trim()
          : u.email;
      final r = (u.role ?? '').toLowerCase();
      final assigneeKind = r == 'staff' ? 'staff' : 'admin';
      out.add(
        _TimeOffPerson(
          assigneeKind: assigneeKind,
          id: u.id!,
          name: displayName,
          schoolId: sid,
        ),
      );
    }

    for (final w in _workers) {
      if (!w.isActive || w.id == null) continue;
      if (_schoolFilter != 'all' && w.schoolId != _schoolFilter) continue;
      out.add(
        _TimeOffPerson(
          assigneeKind: 'worker',
          id: w.id!,
          name: w.name,
          schoolId: w.schoolId,
        ),
      );
    }

    out.sort((a, b) {
      final k = kindOrder
          .indexOf(a.assigneeKind)
          .compareTo(kindOrder.indexOf(b.assigneeKind));
      if (k != 0) return k;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  List<StaffTimeOff> get _filtered {
    return _entries.where((e) {
      if (_schoolFilter != 'all' && e.schoolId != _schoolFilter) return false;
      if (_personFilter != 'all' &&
          '${e.assigneeKind}:${e.assigneeId}' != _personFilter) {
        return false;
      }
      if (_roleKindFilter != 'all' && e.assigneeKind != _roleKindFilter) {
        return false;
      }
      if (_typeFilter != 'all' && e.type != _typeFilter) return false;
      if (_statusFilter != 'all' && e.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inName = e.assigneeName.toLowerCase().contains(q);
        final inNotes = (e.notes ?? '').toLowerCase().contains(q);
        if (!inName && !inNotes) return false;
      }
      return true;
    }).toList();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'vacation':
        return 'Vacation';
      case 'sick':
        return 'Sick leave';
      case 'personal':
        return 'Personal';
      case 'other':
        return 'Other';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    final people = _peopleForSchoolFilter;

    return AdminListScaffold(
      title: 'Time off',
      subtitle: widget.showSchoolFilter
          ? 'Planned absences for teachers, administrators, and staff'
          : 'Planned absences for people at your school',
      searchHint: 'Search by name or notes…',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) {
        setState(() {
          _schoolFilter = v;
          _personFilter = 'all';
        });
      },
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      extraFilters: [
        FilterOption(
          value: _roleKindFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All roles')),
            DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
            DropdownMenuItem(value: 'admin', child: Text('Administrators')),
            DropdownMenuItem(value: 'staff', child: Text('Staff accounts')),
            DropdownMenuItem(value: 'worker', child: Text('Workers')),
          ],
          onChanged: (v) => setState(() => _roleKindFilter = v ?? 'all'),
        ),
        FilterOption(
          value: _personFilter,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('Everyone')),
            ...people.map(
              (p) => DropdownMenuItem(
                value: p.compoundKey,
                child: Text(
                  p.menuLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _personFilter = v ?? 'all'),
        ),
        FilterOption(
          value: _typeFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All types')),
            DropdownMenuItem(value: 'vacation', child: Text('Vacation')),
            DropdownMenuItem(value: 'sick', child: Text('Sick leave')),
            DropdownMenuItem(value: 'personal', child: Text('Personal')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
        ),
        FilterOption(
          value: _statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All statuses')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
          ],
          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
        ),
      ],
      addButtonLabel: 'Add time off',
      onAddPressed: people.isEmpty ? null : () => _showFormDialog(),
      listContent: filtered.isEmpty
          ? AdminEmptyState(
              icon: Icons.event_busy_outlined,
              message: people.isEmpty
                  ? 'Add teachers, administrators, or workers before recording time off'
                  : 'No time off entries match your filters',
            )
          : AdminListCard(
              child: ListView.separated(
                key: const PageStorageKey('staff_time_off_list'),
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

  Widget _buildRow(StaffTimeOff e) {
    final colorScheme = Theme.of(context).colorScheme;
    final schoolName = widget.schools
        .firstWhere(
          (s) => s.id == e.schoolId,
          orElse: () => const School(name: 'Unknown school'),
        )
        .name;

    final kindLabel = switch (e.assigneeKind) {
      'teacher' => 'Teacher',
      'admin' => 'Administrator',
      'staff' => 'Staff',
      _ => 'Worker',
    };

    final range = e.startDate == e.endDate
        ? _dateFmt.format(e.startDate)
        : '${_dateFmt.format(e.startDate)} – ${_dateFmt.format(e.endDate)}';

    final statusColor = e.status == 'pending'
        ? colorScheme.tertiary
        : colorScheme.primary;

    return Padding(
      key: ValueKey(e.id),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            radius: 20,
            child: Text(
              e.assigneeName.isNotEmpty
                  ? e.assigneeName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
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
                  e.assigneeName,
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
                    kindLabel,
                    range,
                    _typeLabel(e.type),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if ((e.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    e.notes!.trim(),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.status == 'pending' ? 'Pending' : 'Approved',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit,
                size: 18, color: colorScheme.onSurfaceVariant),
            onPressed: () => _showFormDialog(existing: e),
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(e),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate({
    required BuildContext context,
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  List<_TimeOffPerson> _peopleWithExistingFallback(StaffTimeOff? existing) {
    final base = List<_TimeOffPerson>.from(_peopleForSchoolFilter);
    if (existing == null) return base;
    final key = '${existing.assigneeKind}:${existing.assigneeId}';
    if (!base.any((p) => p.compoundKey == key)) {
      base.insert(
        0,
        _TimeOffPerson(
          assigneeKind: existing.assigneeKind,
          id: existing.assigneeId,
          name: existing.assigneeName,
          schoolId: existing.schoolId,
        ),
      );
    }
    return base;
  }

  void _showFormDialog({StaffTimeOff? existing}) {
    var people = _peopleWithExistingFallback(existing);
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No teachers, administrators, or workers available'),
        ),
      );
      return;
    }

    late _TimeOffPerson selected;
    if (existing != null) {
      final key = '${existing.assigneeKind}:${existing.assigneeId}';
      final match = people.where((p) => p.compoundKey == key).toList();
      selected = match.isNotEmpty ? match.first : people.first;
    } else {
      selected = people.first;
    }

    DateTime start = existing?.startDate ?? DateTime.now();
    DateTime end = existing?.endDate ?? start;
    String type = existing?.type ?? 'vacation';
    String status = existing?.status ?? 'approved';
    final notesController = TextEditingController(text: existing?.notes ?? '');
    bool isSaving = false;
    final isEdit = existing != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              isEdit ? 'Edit time off' : 'Add time off',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<_TimeOffPerson>(
                      value: selected,
                      decoration:
                          adminInputDecoration('Person', required: true),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      items: people
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.menuLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p != null) setStateDialog(() => selected = p);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: adminInputDecoration('Type', required: true),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      items: const [
                        DropdownMenuItem(
                            value: 'vacation', child: Text('Vacation')),
                        DropdownMenuItem(
                            value: 'sick', child: Text('Sick leave')),
                        DropdownMenuItem(
                            value: 'personal', child: Text('Personal')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => type = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Start: ${_dateFmt.format(start)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () async {
                        final d = await _pickDate(
                          context: dialogCtx,
                          initial: start,
                          firstDate: DateTime(DateTime.now().year - 1),
                          lastDate: DateTime(DateTime.now().year + 2),
                        );
                        if (d == null) return;
                        setStateDialog(() {
                          start = DateTime(d.year, d.month, d.day);
                          if (end.isBefore(start)) {
                            end = start;
                          }
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'End: ${_dateFmt.format(end)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      trailing: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () async {
                        final d = await _pickDate(
                          context: dialogCtx,
                          initial: end,
                          firstDate: start,
                          lastDate: DateTime(DateTime.now().year + 2),
                        );
                        if (d == null) return;
                        setStateDialog(() {
                          end = DateTime(d.year, d.month, d.day);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration:
                          adminInputDecoration('Status', required: true),
                      dropdownColor: Theme.of(dialogCtx).colorScheme.surface,
                      items: const [
                        DropdownMenuItem(
                            value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => status = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: adminInputDecoration('Notes'),
                    ),
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
                        if (end.isBefore(start)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'End date cannot be before start date'),
                            ),
                          );
                          return;
                        }
                        setStateDialog(() => isSaving = true);
                        try {
                          final entry = StaffTimeOff(
                            id: existing?.id,
                            schoolId: selected.schoolId,
                            assigneeKind: selected.assigneeKind,
                            assigneeId: selected.id,
                            assigneeName: selected.name,
                            startDate: start,
                            endDate: end,
                            type: type,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            status: status,
                            createdAt: existing?.createdAt,
                          );
                          if (isEdit) {
                            await FirebaseService.updateStaffTimeOff(entry);
                          } else {
                            await FirebaseService.addStaffTimeOff(entry);
                          }
                          if (!dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Time off updated' : 'Time off added',
                              ),
                            ),
                          );
                          await _load();
                          widget.onDataChanged?.call();
                        } catch (e) {
                          setStateDialog(() => isSaving = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child:
                    Text(isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(StaffTimeOff e) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
        title: Text(
          'Delete time off',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          "Remove ${e.assigneeName}'s entry (${_dateFmt.format(e.startDate)} – ${_dateFmt.format(e.endDate)})?",
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (e.id == null) return;
              try {
                await FirebaseService.deleteStaffTimeOff(e.id!);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Time off deleted')),
                );
                await _load();
                widget.onDataChanged?.call();
              } catch (err) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $err')),
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
