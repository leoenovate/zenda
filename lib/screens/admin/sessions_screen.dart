import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/class_group.dart';
import '../../models/role.dart';
import '../../models/school.dart';
import '../../models/session.dart';
import '../../models/session_attendee.dart';
import '../../models/session_date_override.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../widgets/admin/admin_list_scaffold.dart';
import 'session_attendance_screen.dart';

class SessionsScreen extends StatefulWidget {
  final List<School> schools;
  final VoidCallback? onDataChanged;
  final bool showSchoolFilter;

  const SessionsScreen({
    super.key,
    required this.schools,
    this.onDataChanged,
    this.showSchoolFilter = true,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

/// Selectable role bundle in the "Add by role" picker. Wraps either a
/// built-in role (teacher / admin / staff / worker) or a custom [Role]
/// definition from the `roles/` collection.
class _RoleOption {
  final String key;
  final String label;
  final String assigneeKind;
  final String schoolId;

  /// Set for built-in roles so the same option works across schools.
  final bool isBuiltIn;

  const _RoleOption({
    required this.key,
    required this.label,
    required this.assigneeKind,
    required this.schoolId,
    this.isBuiltIn = false,
  });
}

class _SessionsScreenState extends State<SessionsScreen> {
  static final _dateFmt = DateFormat.yMMMd();
  static final _dateLongFmt = DateFormat('EEE, MMM d, y');
  static final _dateShortFmt = DateFormat('MMM d');

  bool _isLoading = true;
  List<Session> _sessions = [];
  List<Teacher> _teachers = [];
  List<ClassGroup> _classes = [];
  List<Worker> _workers = [];
  List<Role> _roles = [];
  List<app_user.AppUser> _users = [];
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
        FirebaseService.getSessions(),
        FirebaseService.getTeachers(),
        FirebaseService.getClasses(),
        FirebaseService.getWorkers(),
        FirebaseService.getRoles(),
        FirebaseService.getUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<Session>;
        _teachers = results[1] as List<Teacher>;
        _classes = results[2] as List<ClassGroup>;
        _workers = results[3] as List<Worker>;
        _roles = results[4] as List<Role>;
        _users = results[5] as List<app_user.AppUser>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sessions: $e')));
    }
  }

  List<Session> get _filtered {
    return _sessions.where((s) {
      if (_schoolFilter != 'all' && s.schoolId != _schoolFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            (s.name ?? '').toLowerCase().contains(q) ||
            s.classNames.any((c) => c.toLowerCase().contains(q)) ||
            s.audienceRoles.any((r) => r.toLowerCase().contains(q)) ||
            s.attendees.any((a) => a.name.toLowerCase().contains(q)) ||
            (s.teacherName ?? '').toLowerCase().contains(q) ||
            _audienceSummary(s).toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Role / person catalog used by the form dialog.
  // ---------------------------------------------------------------------------

  /// Returns every selectable role for [schoolId], built-in roles first
  /// and then custom roles defined for the school.
  List<_RoleOption> _rolesForSchool(String schoolId) {
    return [
      _RoleOption(
        key: 'teacher',
        label: 'Teachers',
        assigneeKind: 'teacher',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'admin',
        label: 'Administrators',
        assigneeKind: 'admin',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'staff',
        label: 'Staff',
        assigneeKind: 'staff',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      _RoleOption(
        key: 'worker',
        label: 'Workers',
        assigneeKind: 'worker',
        schoolId: schoolId,
        isBuiltIn: true,
      ),
      for (final r in _roles)
        if (r.isActive && r.schoolId == schoolId && r.id != null)
          _RoleOption(
            key: r.name,
            label: r.name,
            assigneeKind: 'worker',
            schoolId: schoolId,
          ),
    ];
  }

  bool _isSchoolAdminUser(app_user.AppUser u) {
    final r = (u.role ?? '').toLowerCase();
    return r == 'admin' || r == 'school_admin';
  }

  /// Returns every active person that belongs to [option] in the same
  /// school. Built-in `worker` returns every worker; custom roles
  /// filter by `worker.role` (case-insensitive).
  List<SessionAttendee> _peopleInRole(_RoleOption option) {
    final out = <SessionAttendee>[];
    final schoolId = option.schoolId;

    switch (option.key) {
      case 'teacher':
        for (final t in _teachers) {
          if (!t.isActive || t.id == null) continue;
          if (t.schoolId != schoolId) continue;
          out.add(
            SessionAttendee(
              kind: 'teacher',
              id: t.id!,
              name: t.name,
              roleKey: 'teacher',
            ),
          );
        }
        break;
      case 'admin':
        for (final u in _users) {
          if (!u.isActive || u.id == null) continue;
          if (!_isSchoolAdminUser(u)) continue;
          if (u.schoolId != schoolId) continue;
          out.add(
            SessionAttendee(
              kind: 'admin',
              id: u.id!,
              name: _displayName(u),
              roleKey: 'admin',
            ),
          );
        }
        break;
      case 'staff':
        for (final u in _users) {
          if (!u.isActive || u.id == null) continue;
          if ((u.role ?? '').toLowerCase() != 'staff') continue;
          if (u.schoolId != schoolId) continue;
          out.add(
            SessionAttendee(
              kind: 'staff',
              id: u.id!,
              name: _displayName(u),
              roleKey: 'staff',
            ),
          );
        }
        break;
      case 'worker':
        for (final w in _workers) {
          if (!w.isActive || w.id == null) continue;
          if (w.schoolId != schoolId) continue;
          out.add(
            SessionAttendee(
              kind: 'worker',
              id: w.id!,
              name: w.name,
              roleKey: (w.role ?? '').isEmpty ? 'worker' : w.role,
            ),
          );
        }
        break;
      default:
        final target = option.key.trim().toLowerCase();
        for (final w in _workers) {
          if (!w.isActive || w.id == null) continue;
          if (w.schoolId != schoolId) continue;
          if ((w.role ?? '').trim().toLowerCase() != target) continue;
          out.add(
            SessionAttendee(
              kind: 'worker',
              id: w.id!,
              name: w.name,
              roleKey: option.key,
            ),
          );
        }
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  String _displayName(app_user.AppUser u) {
    if (u.name != null && u.name!.trim().isNotEmpty) return u.name!.trim();
    return u.email;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    return AdminListScaffold(
      title: 'Sessions',
      subtitle:
          widget.showSchoolFilter
              ? 'Daily class sessions and attendance windows'
              : 'Class sessions and attendance windows for your school',
      searchHint: 'Search by name, class, role or person...',
      searchQuery: _searchQuery,
      onSearchChanged: (v) => setState(() => _searchQuery = v),
      schools: widget.schools,
      schoolFilter: _schoolFilter,
      onSchoolFilterChanged: (v) => setState(() => _schoolFilter = v),
      showSchoolFilter: widget.showSchoolFilter && widget.schools.length > 1,
      addButtonLabel: 'New Session',
      onAddPressed: () => _showFormDialog(),
      listContent:
          filtered.isEmpty
              ? const AdminEmptyState(
                icon: Icons.event_note_outlined,
                message: 'No sessions found',
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

  // ---------------------------------------------------------------------------
  // List row
  // ---------------------------------------------------------------------------

  IconData _iconForSession(Session s) {
    if (s.attendees.isEmpty &&
        s.audienceRoles.isEmpty &&
        s.classIds.isNotEmpty) {
      return Icons.school_outlined;
    }
    if (s.audienceRoles.length == 1 && s.attendees.isEmpty) {
      return switch (s.audienceRoles.first.toLowerCase()) {
        'teacher' => Icons.groups_2_outlined,
        'admin' => Icons.admin_panel_settings_outlined,
        'staff' => Icons.support_agent_outlined,
        'worker' => Icons.engineering_outlined,
        _ => Icons.badge_outlined,
      };
    }
    if (s.attendees.isNotEmpty || s.audienceRoles.isNotEmpty) {
      return Icons.groups_outlined;
    }
    return Icons.event_note_outlined;
  }

  String _scheduleLabel(Session s) {
    final dateLabel =
        s.isMultiDay
            ? '${_dateShortFmt.format(s.date)} – ${_dateFmt.format(s.endDate)}'
            : _dateFmt.format(s.date);
    final timeLabel =
        (s.startTime != null && s.endTime != null)
            ? '${s.startTime}–${s.endTime}'
            : (s.startTime ?? '');
    if (timeLabel.isEmpty) return dateLabel;
    return '$dateLabel · $timeLabel';
  }

  Widget _buildRow(Session s) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 650;
    final schoolName =
        widget.schools
            .firstWhere(
              (sc) => sc.id == s.schoolId,
              orElse: () => const School(name: 'Unknown school'),
            )
            .name;

    final statusColor = s.isActive ? Colors.green : Colors.grey;
    final hasOnlyClasses =
        s.classIds.isNotEmpty && s.audienceRoles.isEmpty && s.attendees.isEmpty;
    final audienceColor =
        hasOnlyClasses ? colorScheme.primary : colorScheme.tertiary;

    final title =
        (s.name != null && s.name!.trim().isNotEmpty)
            ? s.name!.trim()
            : _audienceSummary(s);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child:
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sessionIcon(audienceColor, s),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sessionText(
                          colorScheme,
                          title: title,
                          subtitle: [
                            if (widget.showSchoolFilter &&
                                widget.schools.length > 1)
                              schoolName,
                            _scheduleLabel(s),
                            if ((s.name != null && s.name!.trim().isNotEmpty))
                              _audienceSummary(s),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          subtitleMaxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (s.isRecurring) _recurrencePill(colorScheme, s),
                      _statusPill(statusColor, s.isActive),
                      IconButton(
                        icon: Icon(
                          Icons.fact_check_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        tooltip: 'Take attendance',
                        onPressed: () => _openAttendance(s),
                      ),
                      if (s.isActive)
                        IconButton(
                          icon: const Icon(
                            Icons.stop_circle,
                            size: 20,
                            color: Colors.orange,
                          ),
                          tooltip: 'End session',
                          onPressed: () => _endSession(s),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Edit session',
                        onPressed: () => _showFormDialog(session: s),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete session',
                        onPressed: () => _confirmDelete(s),
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  _sessionIcon(audienceColor, s),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sessionText(
                      colorScheme,
                      title: title,
                      subtitle: [
                        if (widget.showSchoolFilter &&
                            widget.schools.length > 1)
                          schoolName,
                        _scheduleLabel(s),
                        if ((s.name != null && s.name!.trim().isNotEmpty))
                          _audienceSummary(s),
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                  ),
                  if (s.isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _recurrencePill(colorScheme, s),
                    ),
                  _statusPill(statusColor, s.isActive),
                  IconButton(
                    icon: Icon(
                      Icons.fact_check_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    tooltip: 'Take attendance',
                    onPressed: () => _openAttendance(s),
                  ),
                  if (s.isActive)
                    IconButton(
                      icon: const Icon(
                        Icons.stop_circle,
                        size: 20,
                        color: Colors.orange,
                      ),
                      tooltip: 'End session',
                      onPressed: () => _endSession(s),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _showFormDialog(session: s),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmDelete(s),
                  ),
                ],
              ),
    );
  }

  Widget _sessionIcon(Color color, Session s) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_iconForSession(s), color: color),
    );
  }

  Widget _sessionText(
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
    int subtitleMaxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          maxLines: subtitleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _recurrencePill(ColorScheme colorScheme, Session s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            _recurrenceLabel(s.recurrence),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'ENDED',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  String _recurrenceLabel(String r) {
    switch (r.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return '';
    }
  }

  String _roleDisplayName(String key) {
    switch (key.toLowerCase()) {
      case 'teacher':
        return 'Teachers';
      case 'admin':
        return 'Administrators';
      case 'staff':
        return 'Staff';
      case 'worker':
        return 'Workers';
      default:
        return key;
    }
  }

  /// Multi-line summary used as fallback title and as the secondary-line
  /// detail text when a custom name is set.
  String _audienceSummary(Session s) {
    final parts = <String>[];

    if (s.classIds.isNotEmpty) {
      if (s.classNames.length == 1) {
        parts.add('Class: ${s.classNames.first}');
      } else if (s.classNames.length > 1) {
        parts.add('${s.classNames.length} classes');
      } else {
        parts.add('${s.classIds.length} classes');
      }
    }

    if (s.audienceRoles.isNotEmpty) {
      final names = s.audienceRoles.map(_roleDisplayName).toList();
      if (names.length <= 2) {
        parts.add('All ${names.join(', ')}');
      } else {
        parts.add('${names.length} role groups');
      }
    }

    if (s.attendees.isNotEmpty) {
      if (s.attendees.length == 1) {
        parts.add(s.attendees.first.name);
      } else {
        parts.add('${s.attendees.length} people');
      }
    }

    if (parts.isEmpty) {
      if (s.audienceLabel != null && s.audienceLabel!.trim().isNotEmpty) {
        return s.audienceLabel!;
      }
      return 'No audience';
    }
    return parts.join(' · ');
  }

  // ---------------------------------------------------------------------------
  // Form helpers
  // ---------------------------------------------------------------------------

  String _formatHHmm(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay? _parseHHmm(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<TimeOfDay?> _pickTime(
    BuildContext ctx, {
    required TimeOfDay initial,
    required String helpText,
  }) {
    return showTimePicker(
      context: ctx,
      initialTime: initial,
      helpText: helpText,
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext ctx, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  }) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
    if (d == null) return null;
    if (!ctx.mounted) return null;
    final t = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: helpText,
    );
    if (t == null) {
      return DateTime(d.year, d.month, d.day, initial.hour, initial.minute);
    }
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Widget _dialogSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.55),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form dialog
  // ---------------------------------------------------------------------------

  void _showFormDialog({Session? session}) {
    final nameController = TextEditingController(text: session?.name ?? '');

    String? schoolId = session?.schoolId;
    if (schoolId == null && widget.schools.isNotEmpty) {
      schoolId = widget.schools.first.id;
    }

    DateTime startDate = session?.date ?? DateTime.now();
    startDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      session?.date.hour ?? 0,
      session?.date.minute ?? 0,
    );
    DateTime endDate = session?.endDate ?? startDate;
    bool isMultiDay = session?.isMultiDay ?? false;

    TimeOfDay? startTimeOfDay = _parseHHmm(session?.startTime);
    TimeOfDay? endTimeOfDay = _parseHHmm(session?.endTime);
    TimeOfDay? lateTimeOfDay = _parseHHmm(session?.lateTime);

    String recurrence = (session?.recurrence ?? 'none').toLowerCase();

    final selectedClassIds = <String>{...?session?.classIds};
    final selectedRoles = <String>{...?session?.audienceRoles};
    final selectedAttendees = <String, SessionAttendee>{
      for (final a in session?.attendees ?? const <SessionAttendee>[])
        a.compoundKey: a,
    };

    final overrides = <String, SessionDateOverride>{
      for (final o in session?.dateOverrides ?? const <SessionDateOverride>[])
        o.dateKey: o,
    };

    bool isActive = session?.isActive ?? true;
    bool isSaving = false;
    bool showIndividualPicker = false;
    String individualSearch = '';
    bool showDayCustomization = overrides.isNotEmpty;
    DateTime calendarMonth = DateTime(
      (session?.date ?? DateTime.now()).year,
      (session?.date ?? DateTime.now()).month,
    );
    final isEdit = session != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              final colorScheme = Theme.of(dialogCtx).colorScheme;
              final classesForSchool =
                  _classes.where((c) => c.schoolId == schoolId).toList()..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
              final roleOptions =
                  schoolId == null
                      ? const <_RoleOption>[]
                      : _rolesForSchool(schoolId!);

              // Collect every selectable person, grouped by role option, for
              // the "Add individuals" panel.
              final groupedPeople = <_RoleOption, List<SessionAttendee>>{};
              for (final option in roleOptions) {
                groupedPeople[option] = _peopleInRole(option);
              }

              return AlertDialog(
                backgroundColor: colorScheme.surface,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                title: Text(
                  isEdit ? 'Edit Session' : 'New Session',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.schools.length > 1) ...[
                          DropdownButtonFormField<String?>(
                            value: schoolId,
                            decoration: adminInputDecoration(
                              'School',
                              required: true,
                            ),
                            dropdownColor: colorScheme.surface,
                            style: TextStyle(color: colorScheme.onSurface),
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
                                (v) => setStateDialog(() {
                                  schoolId = v;
                                  selectedClassIds.clear();
                                  selectedRoles.clear();
                                  selectedAttendees.clear();
                                }),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ----------------------------------------------------
                        // Name
                        // ----------------------------------------------------
                        _dialogSection(
                          context: dialogCtx,
                          icon: Icons.label_outline,
                          title: 'Name',
                          subtitle:
                              'Optional title shown in lists and reports.',
                          child: TextField(
                            controller: nameController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: adminInputDecoration(
                              'Session name (e.g. Weekly staff meeting)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ----------------------------------------------------
                        // Schedule
                        // ----------------------------------------------------
                        _dialogSection(
                          context: dialogCtx,
                          icon: Icons.schedule_outlined,
                          title: 'Schedule',
                          subtitle: 'Set when this attendance window is open.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: isMultiDay,
                                activeColor: colorScheme.primary,
                                title: Text(
                                  'Spans multiple days',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  isMultiDay
                                      ? 'Pick a start and end date+time.'
                                      : 'Single-day session.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                onChanged:
                                    (v) => setStateDialog(() {
                                      isMultiDay = v;
                                      if (!v) {
                                        endDate = DateTime(
                                          startDate.year,
                                          startDate.month,
                                          startDate.day,
                                        );
                                        startDate = DateTime(
                                          startDate.year,
                                          startDate.month,
                                          startDate.day,
                                        );
                                      } else if (!endDate.isAfter(startDate)) {
                                        endDate = startDate.add(
                                          const Duration(days: 1),
                                        );
                                      }
                                    }),
                              ),
                              const SizedBox(height: 8),
                              if (!isMultiDay) ...[
                                _scheduleTile(
                                  context: dialogCtx,
                                  icon: Icons.event_outlined,
                                  label: 'Date',
                                  value: _dateLongFmt.format(startDate),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: dialogCtx,
                                      initialDate: startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      helpText: 'Select session date',
                                    );
                                    if (d != null) {
                                      setStateDialog(() {
                                        startDate = DateTime(
                                          d.year,
                                          d.month,
                                          d.day,
                                        );
                                        endDate = startDate;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _responsivePair(
                                  first: _scheduleTile(
                                    context: dialogCtx,
                                    icon: Icons.play_arrow_outlined,
                                    label: 'Starts at',
                                    value:
                                        startTimeOfDay == null
                                            ? 'Pick a time'
                                            : startTimeOfDay!.format(dialogCtx),
                                    onTap: () async {
                                      final t = await _pickTime(
                                        dialogCtx,
                                        initial:
                                            startTimeOfDay ??
                                            const TimeOfDay(hour: 8, minute: 0),
                                        helpText: 'Session start time',
                                      );
                                      if (t != null) {
                                        setStateDialog(
                                          () => startTimeOfDay = t,
                                        );
                                      }
                                    },
                                    onClear:
                                        startTimeOfDay == null
                                            ? null
                                            : () => setStateDialog(
                                              () => startTimeOfDay = null,
                                            ),
                                  ),
                                  second: _scheduleTile(
                                    context: dialogCtx,
                                    icon: Icons.stop_outlined,
                                    label: 'Ends at',
                                    value:
                                        endTimeOfDay == null
                                            ? 'Pick a time'
                                            : endTimeOfDay!.format(dialogCtx),
                                    onTap: () async {
                                      final t = await _pickTime(
                                        dialogCtx,
                                        initial:
                                            endTimeOfDay ??
                                            const TimeOfDay(
                                              hour: 17,
                                              minute: 0,
                                            ),
                                        helpText: 'Session end time',
                                      );
                                      if (t != null) {
                                        setStateDialog(() => endTimeOfDay = t);
                                      }
                                    },
                                    onClear:
                                        endTimeOfDay == null
                                            ? null
                                            : () => setStateDialog(
                                              () => endTimeOfDay = null,
                                            ),
                                  ),
                                ),
                              ] else ...[
                                _scheduleTile(
                                  context: dialogCtx,
                                  icon: Icons.event_outlined,
                                  label: 'Starts',
                                  value: _dateLongFmt.format(startDate),
                                  onTap: () async {
                                    final d = await _pickDateTime(
                                      dialogCtx,
                                      initial: startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      helpText: 'Session start',
                                    );
                                    if (d != null) {
                                      setStateDialog(() {
                                        startDate = d;
                                        if (!endDate.isAfter(startDate)) {
                                          endDate = startDate.add(
                                            const Duration(hours: 1),
                                          );
                                        }
                                        startTimeOfDay ??= TimeOfDay(
                                          hour: d.hour,
                                          minute: d.minute,
                                        );
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _scheduleTile(
                                  context: dialogCtx,
                                  icon: Icons.event_available_outlined,
                                  label: 'Ends',
                                  value: _dateLongFmt.format(endDate),
                                  onTap: () async {
                                    final d = await _pickDateTime(
                                      dialogCtx,
                                      initial:
                                          endDate.isAfter(startDate)
                                              ? endDate
                                              : startDate.add(
                                                const Duration(hours: 1),
                                              ),
                                      firstDate: startDate,
                                      lastDate: DateTime(2100),
                                      helpText: 'Session end',
                                    );
                                    if (d != null) {
                                      setStateDialog(() {
                                        endDate = d;
                                        endTimeOfDay ??= TimeOfDay(
                                          hour: d.hour,
                                          minute: d.minute,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),
                              _scheduleTile(
                                context: dialogCtx,
                                icon: Icons.timer_outlined,
                                label: 'Late threshold',
                                value:
                                    lateTimeOfDay == null
                                        ? 'Optional'
                                        : lateTimeOfDay!.format(dialogCtx),
                                onTap: () async {
                                  final t = await _pickTime(
                                    dialogCtx,
                                    initial:
                                        lateTimeOfDay ??
                                        startTimeOfDay ??
                                        const TimeOfDay(hour: 9, minute: 0),
                                    helpText: 'Mark as late after this time',
                                  );
                                  if (t != null) {
                                    setStateDialog(() => lateTimeOfDay = t);
                                  }
                                },
                                onClear:
                                    lateTimeOfDay == null
                                        ? null
                                        : () => setStateDialog(
                                          () => lateTimeOfDay = null,
                                        ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: recurrence,
                                decoration: adminInputDecoration('Repeats'),
                                dropdownColor: colorScheme.surface,
                                style: TextStyle(color: colorScheme.onSurface),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'none',
                                    child: Text('Does not repeat'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('Daily'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('Weekly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Monthly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('Yearly'),
                                  ),
                                ],
                                onChanged:
                                    (v) => setStateDialog(
                                      () => recurrence = v ?? 'none',
                                    ),
                              ),
                              if (isMultiDay || recurrence != 'none') ...[
                                const SizedBox(height: 16),
                                _customizationPanel(
                                  dialogCtx: dialogCtx,
                                  startDate: startDate,
                                  endDate: isMultiDay ? endDate : startDate,
                                  recurrence: recurrence,
                                  baseStartTime: _formatHHmm(startTimeOfDay),
                                  baseEndTime: _formatHHmm(endTimeOfDay),
                                  baseLateTime: _formatHHmm(lateTimeOfDay),
                                  overrides: overrides,
                                  calendarMonth: calendarMonth,
                                  show: showDayCustomization,
                                  onToggleShow:
                                      (v) => setStateDialog(
                                        () => showDayCustomization = v,
                                      ),
                                  onMonthChanged:
                                      (m) => setStateDialog(
                                        () => calendarMonth = m,
                                      ),
                                  onOverrideChanged:
                                      (key, ov) => setStateDialog(() {
                                        if (ov == null ||
                                            !ov.hasCustomization) {
                                          overrides.remove(key);
                                        } else {
                                          overrides[key] = ov;
                                        }
                                      }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ----------------------------------------------------
                        // Attendees
                        // ----------------------------------------------------
                        _dialogSection(
                          context: dialogCtx,
                          icon: Icons.how_to_reg_outlined,
                          title: 'Attendees',
                          subtitle:
                              'Mix classes, whole roles, and individuals as needed.',
                          child: _attendeesSection(
                            dialogCtx: dialogCtx,
                            schoolId: schoolId,
                            classesForSchool: classesForSchool,
                            roleOptions: roleOptions,
                            groupedPeople: groupedPeople,
                            selectedClassIds: selectedClassIds,
                            selectedRoles: selectedRoles,
                            selectedAttendees: selectedAttendees,
                            showIndividualPicker: showIndividualPicker,
                            individualSearch: individualSearch,
                            onShowIndividualPickerChanged:
                                (v) => setStateDialog(
                                  () => showIndividualPicker = v,
                                ),
                            onIndividualSearchChanged:
                                (v) =>
                                    setStateDialog(() => individualSearch = v),
                            setStateDialog: setStateDialog,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                              if (schoolId == null) {
                                _snack('School is required');
                                return;
                              }
                              if (selectedClassIds.isEmpty &&
                                  selectedRoles.isEmpty &&
                                  selectedAttendees.isEmpty) {
                                _snack(
                                  'Add at least one class, role, or person to the audience',
                                );
                                return;
                              }
                              if (isMultiDay && !endDate.isAfter(startDate)) {
                                _snack('End must be after start');
                                return;
                              }
                              setStateDialog(() => isSaving = true);
                              try {
                                final updated = _buildSession(
                                  existing: session,
                                  schoolId: schoolId!,
                                  name: nameController.text.trim(),
                                  startDate: startDate,
                                  endDate: isMultiDay ? endDate : startDate,
                                  isMultiDay: isMultiDay,
                                  startTime: _formatHHmm(startTimeOfDay),
                                  endTime: _formatHHmm(endTimeOfDay),
                                  lateTime: _formatHHmm(lateTimeOfDay),
                                  recurrence: recurrence,
                                  isActive: isActive,
                                  classIds: selectedClassIds.toList(),
                                  classesForSchool: classesForSchool,
                                  audienceRoles: selectedRoles.toList(),
                                  attendees: selectedAttendees.values.toList(),
                                  dateOverrides:
                                      overrides.values
                                          .where((o) => o.hasCustomization)
                                          .toList(),
                                );
                                if (isEdit) {
                                  await FirebaseService.updateSession(updated);
                                } else {
                                  await FirebaseService.createSession(updated);
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                _snack(
                                  isEdit
                                      ? 'Session updated'
                                      : 'Session created',
                                );
                                await _load();
                                widget.onDataChanged?.call();
                              } catch (e) {
                                setStateDialog(() => isSaving = false);
                                _snack('Error: $e');
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Builds the [Session] to persist, mirroring legacy single-target
  /// fields whenever the new audience cleanly maps to one.
  Session _buildSession({
    required Session? existing,
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isMultiDay,
    required String startTime,
    required String endTime,
    required String lateTime,
    required String recurrence,
    required bool isActive,
    required List<String> classIds,
    required List<ClassGroup> classesForSchool,
    required List<String> audienceRoles,
    required List<SessionAttendee> attendees,
    List<SessionDateOverride> dateOverrides = const [],
  }) {
    // Resolve class display names from the loaded list.
    final classNames = <String>[];
    for (final id in classIds) {
      final c = classesForSchool.firstWhere(
        (c) => c.id == id,
        orElse: () => const ClassGroup(name: '', schoolId: ''),
      );
      classNames.add(c.name);
    }

    // Derive legacy single-target fields when possible.
    String? legacyClassId;
    String? legacyClassName;
    String? legacyTeacherId;
    String? legacyTeacherName;
    String legacyAudienceType = 'students';
    String? legacyAudienceMode;
    String? legacyAudienceRole;
    String? legacyAssigneeKind;
    String? legacyAssigneeId;
    String? legacyAssigneeName;

    final totalAudienceSources =
        (classIds.isNotEmpty ? 1 : 0) +
        (audienceRoles.isNotEmpty ? 1 : 0) +
        (attendees.isNotEmpty ? 1 : 0);

    if (classIds.length == 1 && audienceRoles.isEmpty && attendees.isEmpty) {
      // Single-class session.
      legacyClassId = classIds.first;
      legacyClassName = classNames.first;
      final cls = classesForSchool.firstWhere(
        (c) => c.id == legacyClassId,
        orElse: () => const ClassGroup(name: '', schoolId: ''),
      );
      legacyTeacherId = cls.teacherId;
      if (legacyTeacherId != null) {
        final t = _teachers.firstWhere(
          (t) => t.id == legacyTeacherId,
          orElse: () => const Teacher(name: '', schoolId: ''),
        );
        legacyTeacherName = t.name.isEmpty ? null : t.name;
      }
      legacyAudienceType = 'students';
      legacyAudienceMode = 'class';
    } else if (classIds.isEmpty &&
        audienceRoles.length == 1 &&
        attendees.isEmpty) {
      // All members of one role.
      legacyAudienceType = 'role';
      legacyAudienceMode = 'all';
      legacyAudienceRole = audienceRoles.first;
      legacyAssigneeKind = _assigneeKindForRole(audienceRoles.first);
    } else if (classIds.isEmpty &&
        audienceRoles.isEmpty &&
        attendees.length == 1) {
      final a = attendees.first;
      legacyAudienceType = 'role';
      legacyAudienceMode = 'single';
      legacyAudienceRole = a.roleKey ?? a.kind;
      legacyAssigneeKind = a.kind;
      legacyAssigneeId = a.id;
      legacyAssigneeName = a.name;
      if (a.kind == 'teacher') {
        legacyTeacherId = a.id;
        legacyTeacherName = a.name;
      }
    } else if (totalAudienceSources > 1 ||
        attendees.length > 1 ||
        classIds.length > 1 ||
        audienceRoles.length > 1) {
      // Mixed audience — no clean legacy mapping.
      legacyAudienceType = 'mixed';
      legacyAudienceMode = 'multi';
    }

    final summary = _summaryFor(
      classNames: classNames,
      audienceRoles: audienceRoles,
      attendees: attendees,
    );

    return Session(
      id: existing?.id,
      schoolId: schoolId,
      name: name.isEmpty ? null : name,
      date: startDate,
      endDate: endDate,
      recurrence: recurrence,
      isActive: isActive,
      startTime: startTime.isEmpty ? null : startTime,
      endTime: endTime.isEmpty ? null : endTime,
      lateTime: lateTime.isEmpty ? null : lateTime,
      className: legacyClassName,
      classId: legacyClassId,
      classIds: classIds,
      classNames: classNames,
      teacherId: legacyTeacherId,
      teacherName: legacyTeacherName,
      audienceType: legacyAudienceType,
      audienceMode: legacyAudienceMode,
      audienceRole: legacyAudienceRole,
      assigneeKind: legacyAssigneeKind,
      assigneeId: legacyAssigneeId,
      assigneeName: legacyAssigneeName,
      audienceLabel: summary.isEmpty ? null : summary,
      audienceRoles: audienceRoles,
      attendees: attendees,
      dateOverrides: dateOverrides,
    );
  }

  String _assigneeKindForRole(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'teacher':
      case 'admin':
      case 'staff':
      case 'worker':
        return roleKey.toLowerCase();
      default:
        return 'worker';
    }
  }

  String _summaryFor({
    required List<String> classNames,
    required List<String> audienceRoles,
    required List<SessionAttendee> attendees,
  }) {
    final parts = <String>[];
    if (classNames.length == 1) {
      parts.add('Class: ${classNames.first}');
    } else if (classNames.length > 1) {
      parts.add('${classNames.length} classes');
    }
    if (audienceRoles.isNotEmpty) {
      final names = audienceRoles.map(_roleDisplayName).toList();
      if (names.length <= 2) {
        parts.add('All ${names.join(', ')}');
      } else {
        parts.add('${names.length} role groups');
      }
    }
    if (attendees.length == 1) {
      parts.add(attendees.first.name);
    } else if (attendees.length > 1) {
      parts.add('${attendees.length} people');
    }
    return parts.join(' · ');
  }

  // ---------------------------------------------------------------------------
  // Schedule tile (clickable read-only field).
  // ---------------------------------------------------------------------------

  Widget _responsivePair({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _scheduleTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onClear != null)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: 'Clear',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attendees section (chips + role bundles + individuals)
  // ---------------------------------------------------------------------------

  Widget _attendeesSection({
    required BuildContext dialogCtx,
    required String? schoolId,
    required List<ClassGroup> classesForSchool,
    required List<_RoleOption> roleOptions,
    required Map<_RoleOption, List<SessionAttendee>> groupedPeople,
    required Set<String> selectedClassIds,
    required Set<String> selectedRoles,
    required Map<String, SessionAttendee> selectedAttendees,
    required bool showIndividualPicker,
    required String individualSearch,
    required ValueChanged<bool> onShowIndividualPickerChanged,
    required ValueChanged<String> onIndividualSearchChanged,
    required void Function(VoidCallback) setStateDialog,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;
    final hasSelection =
        selectedClassIds.isNotEmpty ||
        selectedRoles.isNotEmpty ||
        selectedAttendees.isNotEmpty;

    final classChips = <Widget>[];
    for (final id in selectedClassIds) {
      final cls = classesForSchool.firstWhere(
        (c) => c.id == id,
        orElse: () => const ClassGroup(name: '', schoolId: ''),
      );
      classChips.add(
        InputChip(
          avatar: Icon(
            Icons.school_outlined,
            size: 16,
            color: colorScheme.primary,
          ),
          label: Text(cls.name.isEmpty ? 'Class' : cls.name),
          onDeleted: () => setStateDialog(() => selectedClassIds.remove(id)),
        ),
      );
    }

    final roleChips = <Widget>[];
    for (final key in selectedRoles) {
      roleChips.add(
        InputChip(
          avatar: Icon(
            Icons.badge_outlined,
            size: 16,
            color: colorScheme.tertiary,
          ),
          label: Text('All ${_roleDisplayName(key)}'),
          onDeleted: () => setStateDialog(() => selectedRoles.remove(key)),
        ),
      );
    }

    final attendeeChips = <Widget>[];
    for (final entry in selectedAttendees.entries) {
      final a = entry.value;
      attendeeChips.add(
        InputChip(
          avatar: Icon(
            _iconForKind(a.kind),
            size: 16,
            color: colorScheme.secondary,
          ),
          label: Text(a.name),
          onDeleted:
              () => setStateDialog(() => selectedAttendees.remove(entry.key)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSelection) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [...classChips, ...roleChips, ...attendeeChips],
          ),
          const SizedBox(height: 12),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No audience selected yet.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),

        // Add classes
        Row(
          children: [
            Expanded(
              child: Text(
                'Classes',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  classesForSchool.isEmpty
                      ? null
                      : () => _openClassPicker(
                        dialogCtx,
                        classesForSchool: classesForSchool,
                        selectedClassIds: selectedClassIds,
                        onApply:
                            (next) => setStateDialog(() {
                              selectedClassIds
                                ..clear()
                                ..addAll(next);
                            }),
                      ),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                selectedClassIds.isEmpty
                    ? 'Add classes'
                    : 'Edit ${selectedClassIds.length} '
                        '${selectedClassIds.length == 1 ? 'class' : 'classes'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Add by role
        Text(
          'By role',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (roleOptions.isEmpty)
          Text(
            'Pick a school to see available roles.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in roleOptions)
                FilterChip(
                  label: Text(
                    '${role.label} '
                    '(${(groupedPeople[role] ?? const []).length})',
                  ),
                  avatar: Icon(
                    _iconForKind(role.assigneeKind),
                    size: 16,
                    color: colorScheme.tertiary,
                  ),
                  selected: selectedRoles.contains(role.key),
                  onSelected:
                      (v) => setStateDialog(() {
                        if (v) {
                          selectedRoles.add(role.key);
                        } else {
                          selectedRoles.remove(role.key);
                        }
                      }),
                ),
            ],
          ),
        const SizedBox(height: 12),

        // Add individuals (collapsible)
        Row(
          children: [
            Expanded(
              child: Text(
                'Individuals',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed:
                  () => onShowIndividualPickerChanged(!showIndividualPicker),
              icon: Icon(
                showIndividualPicker
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: Text(showIndividualPicker ? 'Hide picker' : 'Show picker'),
            ),
          ],
        ),
        if (showIndividualPicker)
          _individualPicker(
            dialogCtx: dialogCtx,
            roleOptions: roleOptions,
            groupedPeople: groupedPeople,
            selectedAttendees: selectedAttendees,
            individualSearch: individualSearch,
            onIndividualSearchChanged: onIndividualSearchChanged,
            setStateDialog: setStateDialog,
          ),
      ],
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'teacher':
        return Icons.groups_2_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'staff':
        return Icons.support_agent_outlined;
      case 'worker':
        return Icons.engineering_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  Widget _individualPicker({
    required BuildContext dialogCtx,
    required List<_RoleOption> roleOptions,
    required Map<_RoleOption, List<SessionAttendee>> groupedPeople,
    required Map<String, SessionAttendee> selectedAttendees,
    required String individualSearch,
    required ValueChanged<String> onIndividualSearchChanged,
    required void Function(VoidCallback) setStateDialog,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;

    final filteredGroups = <_RoleOption, List<SessionAttendee>>{};
    final q = individualSearch.trim().toLowerCase();
    for (final entry in groupedPeople.entries) {
      final filtered =
          q.isEmpty
              ? entry.value
              : entry.value
                  .where((p) => p.name.toLowerCase().contains(q))
                  .toList();
      if (filtered.isNotEmpty) filteredGroups[entry.key] = filtered;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search people by name…',
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onIndividualSearchChanged,
          ),
          const SizedBox(height: 12),
          if (filteredGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  q.isEmpty
                      ? 'No people available in this school.'
                      : 'No people match "$individualSearch".',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in filteredGroups.entries) ...[
                      _individualGroup(
                        dialogCtx: dialogCtx,
                        option: entry.key,
                        people: entry.value,
                        selectedAttendees: selectedAttendees,
                        setStateDialog: setStateDialog,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _individualGroup({
    required BuildContext dialogCtx,
    required _RoleOption option,
    required List<SessionAttendee> people,
    required Map<String, SessionAttendee> selectedAttendees,
    required void Function(VoidCallback) setStateDialog,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;
    final selectedCount =
        people
            .where((p) => selectedAttendees.containsKey(p.compoundKey))
            .length;
    final allSelected = selectedCount == people.length && people.isNotEmpty;
    final partialSelected = selectedCount > 0 && !allSelected;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _iconForKind(option.assigneeKind),
                  size: 16,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${option.label} (${people.length})',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Checkbox(
                  tristate: true,
                  value: allSelected ? true : (partialSelected ? null : false),
                  onChanged:
                      (v) => setStateDialog(() {
                        final shouldSelectAll = v ?? !allSelected;
                        for (final p in people) {
                          if (shouldSelectAll) {
                            selectedAttendees[p.compoundKey] = p;
                          } else {
                            selectedAttendees.remove(p.compoundKey);
                          }
                        }
                      }),
                ),
                Text(
                  'Select all',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          for (final p in people)
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              value: selectedAttendees.containsKey(p.compoundKey),
              onChanged:
                  (v) => setStateDialog(() {
                    if (v == true) {
                      selectedAttendees[p.compoundKey] = p;
                    } else {
                      selectedAttendees.remove(p.compoundKey);
                    }
                  }),
              title: Text(
                p.name,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openClassPicker(
    BuildContext dialogCtx, {
    required List<ClassGroup> classesForSchool,
    required Set<String> selectedClassIds,
    required ValueChanged<Set<String>> onApply,
  }) async {
    final localSelected = <String>{...selectedClassIds};
    String search = '';

    await showDialog<void>(
      context: dialogCtx,
      builder:
          (innerCtx) => StatefulBuilder(
            builder: (innerCtx, setInner) {
              final colorScheme = Theme.of(innerCtx).colorScheme;
              final filtered =
                  search.isEmpty
                      ? classesForSchool
                      : classesForSchool
                          .where(
                            (c) => c.name.toLowerCase().contains(
                              search.toLowerCase(),
                            ),
                          )
                          .toList();
              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  'Pick classes',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: SizedBox(
                  width: 420,
                  height: 480,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search classes…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setInner(() => search = v.trim()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child:
                            filtered.isEmpty
                                ? Center(
                                  child: Text(
                                    'No matching classes',
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
                                    final c = filtered[i];
                                    final id = c.id ?? '';
                                    return CheckboxListTile(
                                      value: localSelected.contains(id),
                                      onChanged: (v) {
                                        if (id.isEmpty) return;
                                        setInner(() {
                                          if (v == true) {
                                            localSelected.add(id);
                                          } else {
                                            localSelected.remove(id);
                                          }
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        c.name,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${c.studentIds.length} '
                                        '${c.studentIds.length == 1 ? 'student' : 'students'}',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${localSelected.length} selected',
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
                    onPressed: () => Navigator.pop(innerCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      onApply(localSelected);
                      Navigator.pop(innerCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // End / delete
  // ---------------------------------------------------------------------------

  void _endSession(Session s) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'End Session',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Mark this session as ended? Attendance recording will stop.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.endSession(s.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    _snack('Session ended');
                    await _load();
                    widget.onDataChanged?.call();
                  } catch (e) {
                    _snack('Error: $e');
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

  void _openAttendance(Session s) {
    if (s.id == null) {
      _snack('Save the session before taking attendance.');
      return;
    }
    School? school;
    for (final sc in widget.schools) {
      if (sc.id == s.schoolId) {
        school = sc;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionAttendanceScreen(
          session: s,
          school: school,
          onSaved: () {
            widget.onDataChanged?.call();
          },
        ),
      ),
    );
  }

  void _confirmDelete(Session s) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete Session',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete this session? This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.deleteSession(s.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    _snack('Session deleted');
                    await _load();
                    widget.onDataChanged?.call();
                  } catch (e) {
                    _snack('Error: $e');
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

  // ---------------------------------------------------------------------------
  // Per-day customization (calendar + override editor)
  // ---------------------------------------------------------------------------

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True when [day] is an occurrence of a session that starts at [startDate].
  ///
  /// Non-repeating sessions occur on every date inside `[startDate, endDate]`
  /// so multi-day sessions can skip/override any concrete date in the range.
  ///
  /// Repeating sessions are treated as an unbounded series beginning at
  /// [startDate]. The calendar computes occurrences for the visible month,
  /// which lets admins navigate forward and override future weekly/monthly/
  /// yearly dates without having to set an artificial end date.
  bool _isOccurrenceDay({
    required DateTime day,
    required DateTime startDate,
    required DateTime endDate,
    required String recurrence,
  }) {
    final normalizedRecurrence = recurrence.toLowerCase();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(start)) return false;

    if (normalizedRecurrence == 'none' || normalizedRecurrence.isEmpty) {
      return !d.isAfter(end);
    }

    switch (normalizedRecurrence) {
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == start.weekday;
      case 'monthly':
        return d.day == start.day;
      case 'yearly':
        return d.month == start.month && d.day == start.day;
      default:
        return _sameDate(d, start);
    }
  }

  /// Returns concrete occurrence dates for the currently visible calendar
  /// month only. This keeps the calendar fast while still supporting
  /// unbounded recurring schedules via month navigation.
  Set<String> _occurrenceKeysForMonth({
    required DateTime startDate,
    required DateTime endDate,
    required String recurrence,
    required DateTime calendarMonth,
  }) {
    final keys = <String>{};
    final daysInMonth =
        DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(calendarMonth.year, calendarMonth.month, day);
      if (_isOccurrenceDay(
        day: d,
        startDate: startDate,
        endDate: endDate,
        recurrence: recurrence,
      )) {
        keys.add(SessionDateOverride.formatDateKey(d));
      }
    }
    return keys;
  }

  /// Collapsible calendar that lets the admin skip individual occurrences
  /// or override their start/end/late times.
  Widget _customizationPanel({
    required BuildContext dialogCtx,
    required DateTime startDate,
    required DateTime endDate,
    required String recurrence,
    required String baseStartTime,
    required String baseEndTime,
    required String baseLateTime,
    required Map<String, SessionDateOverride> overrides,
    required DateTime calendarMonth,
    required bool show,
    required ValueChanged<bool> onToggleShow,
    required ValueChanged<DateTime> onMonthChanged,
    required void Function(String key, SessionDateOverride? ov)
    onOverrideChanged,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;
    final occurrenceKeys = _occurrenceKeysForMonth(
      startDate: startDate,
      endDate: endDate,
      recurrence: recurrence,
      calendarMonth: calendarMonth,
    );
    final skipped = overrides.values.where((o) => o.excluded).length;
    final tweaked =
        overrides.values.where((o) => !o.excluded && o.hasCustomization).length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onToggleShow(!show),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize specific days',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${occurrenceKeys.length} '
                                '${occurrenceKeys.length == 1 ? 'occurrence' : 'occurrences'} this month',
                            if (skipped > 0) '$skipped skipped' else null,
                            if (tweaked > 0)
                              '$tweaked with custom times'
                            else
                              null,
                          ].whereType<String>().join(' · '),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (show) ...[
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _calendarBody(
                dialogCtx: dialogCtx,
                startDate: startDate,
                endDate: endDate,
                recurrence: recurrence,
                occurrenceKeys: occurrenceKeys,
                overrides: overrides,
                calendarMonth: calendarMonth,
                baseStartTime: baseStartTime,
                baseEndTime: baseEndTime,
                baseLateTime: baseLateTime,
                onMonthChanged: onMonthChanged,
                onOverrideChanged: onOverrideChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _calendarBody({
    required BuildContext dialogCtx,
    required DateTime startDate,
    required DateTime endDate,
    required String recurrence,
    required Set<String> occurrenceKeys,
    required Map<String, SessionDateOverride> overrides,
    required DateTime calendarMonth,
    required String baseStartTime,
    required String baseEndTime,
    required String baseLateTime,
    required ValueChanged<DateTime> onMonthChanged,
    required void Function(String key, SessionDateOverride? ov)
    onOverrideChanged,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;
    final monthStart = DateTime(calendarMonth.year, calendarMonth.month, 1);
    // Sunday=0 ... Saturday=6 (weekday is 1..7 Mon..Sun in Dart, normalize
    // so the calendar grid starts on Monday).
    final firstWeekday = monthStart.weekday; // 1=Mon..7=Sun
    final daysInMonth =
        DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;

    final cells = <Widget>[];
    // Leading blanks so day-1 lines up under its weekday header.
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(calendarMonth.year, calendarMonth.month, d);
      cells.add(
        _calendarCell(
          dialogCtx: dialogCtx,
          day: day,
          occurrenceKeys: occurrenceKeys,
          overrides: overrides,
          baseStartTime: baseStartTime,
          baseEndTime: baseEndTime,
          baseLateTime: baseLateTime,
          onOverrideChanged: onOverrideChanged,
        ),
      );
    }

    final monthLabel = DateFormat.yMMMM().format(calendarMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed:
                  () => onMonthChanged(
                    DateTime(calendarMonth.year, calendarMonth.month - 1),
                  ),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed:
                  () => onMonthChanged(
                    DateTime(calendarMonth.year, calendarMonth.month + 1),
                  ),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        if (recurrence != 'none' && recurrence.isNotEmpty) ...[
          Text(
            'Navigate months to customize future ${_recurrenceLabel(recurrence).toLowerCase()} occurrences.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        if (calendarMonth.year != startDate.year ||
            calendarMonth.month != startDate.month)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  () =>
                      onMonthChanged(DateTime(startDate.year, startDate.month)),
              icon: const Icon(Icons.today, size: 16),
              label: const Text('Jump to start'),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          children: cells,
        ),
        const SizedBox(height: 12),
        _calendarLegend(dialogCtx),
      ],
    );
  }

  Widget _calendarCell({
    required BuildContext dialogCtx,
    required DateTime day,
    required Set<String> occurrenceKeys,
    required Map<String, SessionDateOverride> overrides,
    required String baseStartTime,
    required String baseEndTime,
    required String baseLateTime,
    required void Function(String key, SessionDateOverride? ov)
    onOverrideChanged,
  }) {
    final colorScheme = Theme.of(dialogCtx).colorScheme;
    final key = SessionDateOverride.formatDateKey(day);
    final isOccurrence = occurrenceKeys.contains(key);
    final ov = overrides[key];
    final excluded = ov?.excluded ?? false;
    final hasTimeOverride =
        ov != null &&
        !ov.excluded &&
        ((ov.startTime?.isNotEmpty ?? false) ||
            (ov.endTime?.isNotEmpty ?? false) ||
            (ov.lateTime?.isNotEmpty ?? false));

    Color bg;
    Color fg;
    if (!isOccurrence) {
      bg = Colors.transparent;
      fg = colorScheme.onSurface.withValues(alpha: 0.35);
    } else if (excluded) {
      bg = colorScheme.errorContainer.withValues(alpha: 0.6);
      fg = colorScheme.onErrorContainer;
    } else if (hasTimeOverride) {
      bg = colorScheme.tertiaryContainer.withValues(alpha: 0.7);
      fg = colorScheme.onTertiaryContainer;
    } else {
      bg = colorScheme.primaryContainer.withValues(alpha: 0.5);
      fg = colorScheme.onPrimaryContainer;
    }

    return Tooltip(
      message:
          isOccurrence
              ? (excluded
                  ? 'Skipped'
                  : (hasTimeOverride
                      ? 'Custom times for this day'
                      : 'Default session day'))
              : 'Not a session day',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap:
            !isOccurrence
                ? null
                : () => _editDayOverride(
                  dialogCtx,
                  day: day,
                  current: ov,
                  baseStartTime: baseStartTime,
                  baseEndTime: baseEndTime,
                  baseLateTime: baseLateTime,
                  onSave: (next) => onOverrideChanged(key, next),
                ),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  decoration: excluded ? TextDecoration.lineThrough : null,
                ),
              ),
              if (hasTimeOverride)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendarLegend(BuildContext ctx) {
    final colorScheme = Theme.of(ctx).colorScheme;
    Widget swatch(Color c, String label) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        swatch(
          colorScheme.primaryContainer.withValues(alpha: 0.5),
          'Session day',
        ),
        swatch(
          colorScheme.tertiaryContainer.withValues(alpha: 0.7),
          'Custom times',
        ),
        swatch(colorScheme.errorContainer.withValues(alpha: 0.6), 'Skipped'),
      ],
    );
  }

  /// Per-day editor: skip switch + start/end/late time pickers + reset.
  Future<void> _editDayOverride(
    BuildContext dialogCtx, {
    required DateTime day,
    required SessionDateOverride? current,
    required String baseStartTime,
    required String baseEndTime,
    required String baseLateTime,
    required ValueChanged<SessionDateOverride?> onSave,
  }) async {
    bool skip = current?.excluded ?? false;
    TimeOfDay? startOv = _parseHHmm(current?.startTime);
    TimeOfDay? endOv = _parseHHmm(current?.endTime);
    TimeOfDay? lateOv = _parseHHmm(current?.lateTime);
    final baseStart = _parseHHmm(baseStartTime);
    final baseEnd = _parseHHmm(baseEndTime);
    final baseLate = _parseHHmm(baseLateTime);

    await showDialog<void>(
      context: dialogCtx,
      builder:
          (innerCtx) => StatefulBuilder(
            builder: (innerCtx, setInner) {
              final colorScheme = Theme.of(innerCtx).colorScheme;

              String fmt(TimeOfDay? ov, TimeOfDay? base) {
                if (ov != null) return '${ov.format(innerCtx)} (custom)';
                if (base != null) return '${base.format(innerCtx)} (default)';
                return 'Pick a time';
              }

              return AlertDialog(
                backgroundColor: colorScheme.surface,
                title: Text(
                  DateFormat('EEE, MMM d, y').format(day),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: skip,
                          activeColor: colorScheme.error,
                          title: Text(
                            'Skip this day',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'No attendance window will be opened.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (v) => setInner(() => skip = v),
                        ),
                        if (!skip) ...[
                          const SizedBox(height: 8),
                          _scheduleTile(
                            context: innerCtx,
                            icon: Icons.play_arrow_outlined,
                            label: 'Starts at',
                            value: fmt(startOv, baseStart),
                            onTap: () async {
                              final t = await _pickTime(
                                innerCtx,
                                initial:
                                    startOv ??
                                    baseStart ??
                                    const TimeOfDay(hour: 8, minute: 0),
                                helpText: 'Start time for this day',
                              );
                              if (t != null) setInner(() => startOv = t);
                            },
                            onClear:
                                startOv == null
                                    ? null
                                    : () => setInner(() => startOv = null),
                          ),
                          const SizedBox(height: 8),
                          _scheduleTile(
                            context: innerCtx,
                            icon: Icons.stop_outlined,
                            label: 'Ends at',
                            value: fmt(endOv, baseEnd),
                            onTap: () async {
                              final t = await _pickTime(
                                innerCtx,
                                initial:
                                    endOv ??
                                    baseEnd ??
                                    const TimeOfDay(hour: 17, minute: 0),
                                helpText: 'End time for this day',
                              );
                              if (t != null) setInner(() => endOv = t);
                            },
                            onClear:
                                endOv == null
                                    ? null
                                    : () => setInner(() => endOv = null),
                          ),
                          const SizedBox(height: 8),
                          _scheduleTile(
                            context: innerCtx,
                            icon: Icons.timer_outlined,
                            label: 'Late threshold',
                            value: fmt(lateOv, baseLate),
                            onTap: () async {
                              final t = await _pickTime(
                                innerCtx,
                                initial:
                                    lateOv ??
                                    baseLate ??
                                    const TimeOfDay(hour: 9, minute: 0),
                                helpText: 'Late threshold for this day',
                              );
                              if (t != null) setInner(() => lateOv = t);
                            },
                            onClear:
                                lateOv == null
                                    ? null
                                    : () => setInner(() => lateOv = null),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.end,
                actions: [
                  TextButton(
                    onPressed: () {
                      onSave(null);
                      Navigator.pop(innerCtx);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Reset to default'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(innerCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final next = SessionDateOverride(
                        date: DateTime(day.year, day.month, day.day),
                        excluded: skip,
                        startTime: skip ? null : _formatHHmm(startOv),
                        endTime: skip ? null : _formatHHmm(endOv),
                        lateTime: skip ? null : _formatHHmm(lateOv),
                      );
                      onSave(next.hasCustomization ? next : null);
                      Navigator.pop(innerCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
