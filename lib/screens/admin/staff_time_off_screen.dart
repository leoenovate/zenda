import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/staff_time_off.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';
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

  /// Custom-role display name (looked up from `roles/{id}` via the
  /// person's `roleId`). Empty if unassigned.
  final String roleLabel;

  const _TimeOffPerson({
    required this.assigneeKind,
    required this.id,
    required this.name,
    required this.schoolId,
    this.roleLabel = '',
  });

  String get compoundKey => '$assigneeKind:$id';

  String get menuLabel {
    final parts = <String>[
      AuthRoles.kindLabel(assigneeKind),
      if (roleLabel.isNotEmpty) roleLabel,
      name,
    ];
    return parts.join(' · ');
  }
}

class _StaffTimeOffScreenState extends State<StaffTimeOffScreen> {
  static final _dateFmt = DateFormat.yMMMd();
  static const int _maxAttachmentRawBytes = 450 * 1024;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  List<Worker> _workers = [];
  List<Teacher> _teachers = [];
  List<app_user.AppUser> _users = [];
  List<Role> _roles = [];
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

  bool _isSchoolAdminUser(app_user.AppUser u) =>
      AuthRoles.isAdminLike(u.role);

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getWorkers(),
        FirebaseService.getTeachers(),
        FirebaseService.getUsers(),
        FirebaseService.getStaffTimeOffs(),
        FirebaseService.getRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _workers = results[0] as List<Worker>;
        _teachers = results[1] as List<Teacher>;
        _users = results[2] as List<app_user.AppUser>;
        _entries = results[3] as List<StaffTimeOff>;
        _roles = results[4] as List<Role>;
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

  /// Resolves a `roleId` to its custom role name. Returns an empty string
  /// when the id is null/unknown.
  String _roleLabelForId(String? roleId) {
    if (roleId == null || roleId.isEmpty) return '';
    for (final r in _roles) {
      if (r.id == roleId) return r.name;
    }
    return '';
  }

  List<_TimeOffPerson> get _peopleForSchoolFilter {
    final out = <_TimeOffPerson>[];

    for (final t in _teachers) {
      if (!t.isActive || t.id == null) continue;
      if (_schoolFilter != 'all' && t.schoolId != _schoolFilter) continue;
      out.add(
        _TimeOffPerson(
          assigneeKind: AuthRoles.kindTeacher,
          id: t.id!,
          name: t.name,
          schoolId: t.schoolId,
          roleLabel: _roleLabelForId(t.roleId),
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
      final assigneeKind =
          AuthRoles.kindForUserRole(u.role) ?? AuthRoles.kindAdmin;
      out.add(
        _TimeOffPerson(
          assigneeKind: assigneeKind,
          id: u.id!,
          name: displayName,
          schoolId: sid,
          roleLabel: _roleLabelForId(u.roleId),
        ),
      );
    }

    for (final w in _workers) {
      if (!w.isActive || w.id == null) continue;
      if (_schoolFilter != 'all' && w.schoolId != _schoolFilter) continue;
      out.add(
        _TimeOffPerson(
          assigneeKind: AuthRoles.kindWorker,
          id: w.id!,
          name: w.name,
          schoolId: w.schoolId,
          roleLabel: _roleLabelForId(w.roleId),
        ),
      );
    }

    out.sort((a, b) {
      final k = AuthRoles.allKinds
          .indexOf(a.assigneeKind)
          .compareTo(AuthRoles.allKinds.indexOf(b.assigneeKind));
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
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All roles')),
            for (final kind in AuthRoles.allKinds)
              DropdownMenuItem(
                value: kind,
                child: Text(AuthRoles.kindLabelPlural(kind)),
              ),
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

    final kindLabel = AuthRoles.kindLabel(e.assigneeKind);

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
                if (e.hasAttachment) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openStaffAttachment(e),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          e.hasBase64Attachment
                              ? Icons.image_outlined
                              : Icons.attach_file,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            e.attachmentFileName ??
                                (e.hasBase64Attachment
                                    ? 'Supporting image'
                                    : 'Supporting document'),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  void _openStaffAttachment(StaffTimeOff e) {
    if (e.hasBase64Attachment && e.attachmentBase64 != null) {
      _showBase64ImagePreview(e.attachmentBase64!, title: e.attachmentFileName);
    } else if (e.attachmentUrl != null && e.attachmentUrl!.isNotEmpty) {
      _openAttachmentUrl(e.attachmentUrl!);
    }
  }

  void _showBase64ImagePreview(String base64, {String? title}) {
    Uint8List bytes;
    try {
      bytes = base64Decode(base64);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not display image')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? 'Supporting image'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachmentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open attachment')),
      );
    }
  }

  String _imageMimeFromFileName(String name) {
    final ext =
        name.contains('.')
            ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
            : '';
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _pickSupportingImage({
    required void Function(void Function()) setStateDialog,
    required void Function(Uint8List bytes, String name) onPicked,
  }) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      if (bytes.length > _maxAttachmentRawBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image is too large for Firestore (max '
              '${(_maxAttachmentRawBytes / 1024).round()} KB). '
              'Choose a smaller photo.',
            ),
          ),
        );
        return;
      }
      final encLen = base64Encode(bytes).length;
      if (encLen > 950000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encoded image exceeds safe Firestore document size'),
          ),
        );
        return;
      }
      var name = xFile.name.trim();
      if (name.isEmpty) name = 'photo.jpg';
      onPicked(bytes, name);
      setStateDialog(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
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
    var attachmentRemoved = false;
    Uint8List? pendingAttachmentBytes;
    String? pendingAttachmentName;

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
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Supporting image',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (pendingAttachmentBytes != null &&
                        pendingAttachmentName != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          pendingAttachmentName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Will be saved in Firestore (Base64)',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isSaving
                              ? null
                              : () {
                                  pendingAttachmentBytes = null;
                                  pendingAttachmentName = null;
                                  setStateDialog(() {});
                                },
                        ),
                      )
                    else if (!attachmentRemoved &&
                        (existing?.hasAttachment ?? false))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          existing!.hasBase64Attachment
                              ? Icons.image_outlined
                              : Icons.attach_file,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          existing.attachmentFileName ??
                              (existing.hasBase64Attachment
                                  ? 'Supporting image'
                                  : 'Supporting document'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      if (existing.hasBase64Attachment) {
                                        _showBase64ImagePreview(
                                          existing.attachmentBase64!,
                                          title: existing.attachmentFileName,
                                        );
                                      } else if (existing.attachmentUrl !=
                                          null) {
                                        _openAttachmentUrl(
                                          existing.attachmentUrl!,
                                        );
                                      }
                                    },
                              child: Text(
                                existing.hasBase64Attachment ? 'View' : 'Open',
                              ),
                            ),
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => _pickSupportingImage(
                                        setStateDialog: setStateDialog,
                                        onPicked: (bytes, name) {
                                          pendingAttachmentBytes = bytes;
                                          pendingAttachmentName = name;
                                          attachmentRemoved = false;
                                        },
                                      ),
                              child: const Text('Replace'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      attachmentRemoved = true;
                                      pendingAttachmentBytes = null;
                                      pendingAttachmentName = null;
                                      setStateDialog(() {});
                                    },
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => _pickSupportingImage(
                                  setStateDialog: setStateDialog,
                                  onPicked: (bytes, name) {
                                    pendingAttachmentBytes = bytes;
                                    pendingAttachmentName = name;
                                    attachmentRemoved = false;
                                  },
                                ),
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('Choose image'),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'JPEG, PNG, GIF, WebP · stored in Firestore · max '
                        '${(_maxAttachmentRawBytes / 1024).round()} KB',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
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
                          String? b64Out;
                          String? mimeOut;
                          String? nameOut;
                          String? pathOut;
                          String? urlOut;

                          if (pendingAttachmentBytes != null &&
                              pendingAttachmentName != null) {
                            if (existing?.hasLegacyStorageAttachment == true) {
                              await FirebaseService
                                  .deleteLegacyStaffTimeOffStorage(
                                existing!.attachmentStoragePath,
                              );
                            }
                            b64Out = base64Encode(pendingAttachmentBytes!);
                            mimeOut = _imageMimeFromFileName(
                              pendingAttachmentName!,
                            );
                            nameOut = pendingAttachmentName;
                            pathOut = null;
                            urlOut = null;
                          } else if (attachmentRemoved) {
                            if (existing?.hasLegacyStorageAttachment == true) {
                              await FirebaseService
                                  .deleteLegacyStaffTimeOffStorage(
                                existing!.attachmentStoragePath,
                              );
                            }
                            b64Out = null;
                            mimeOut = null;
                            nameOut = null;
                            pathOut = null;
                            urlOut = null;
                          } else {
                            b64Out = existing?.attachmentBase64;
                            mimeOut = existing?.attachmentContentType;
                            nameOut = existing?.attachmentFileName;
                            pathOut = existing?.attachmentStoragePath;
                            urlOut = existing?.attachmentUrl;
                          }

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
                            attachmentBase64: b64Out,
                            attachmentContentType: mimeOut,
                            attachmentFileName: nameOut,
                            attachmentStoragePath: pathOut,
                            attachmentUrl: urlOut,
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
                await FirebaseService.deleteStaffTimeOff(e);
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
