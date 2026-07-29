import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance.dart';
import '../../models/school.dart';
import '../../models/session.dart';
import '../../models/session_attendance.dart';
import '../../models/session_attendee.dart';
import '../../models/session_date_override.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_constants.dart';

/// Take-attendance screen for a single [Session] occurrence.
///
/// Resolves the session's roster (students + whole roles + individual
/// attendees) for the selected occurrence date, lets the user mark each
/// person present / late / absent / excused, and persists the result to the
/// `attendance` collection via [FirebaseService.bulkUpsertSessionAttendance].
/// Student marks are mirrored to the legacy `attendanceHistory` array so the
/// existing per-student views keep working during the transition.
class SessionAttendanceScreen extends StatefulWidget {
  final Session session;
  final School? school;

  /// Occurrence to open initially. Defaults to the most recent occurrence on
  /// or before today.
  final DateTime? initialDate;

  /// Invoked after a successful save so callers can refresh dashboards.
  final VoidCallback? onSaved;

  const SessionAttendanceScreen({
    super.key,
    required this.session,
    this.school,
    this.initialDate,
    this.onSaved,
  });

  @override
  State<SessionAttendanceScreen> createState() =>
      _SessionAttendanceScreenState();
}

class _SessionAttendanceScreenState extends State<SessionAttendanceScreen> {
  static final _dateFmt = DateFormat('EEE, MMM d, y');

  late DateTime _date;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _search = '';

  List<SessionAttendee> _roster = const [];

  /// Selected status per roster row (keyed by `SessionAttendee.compoundKey`).
  /// A missing key means the person is still unmarked.
  final Map<String, AttendanceStatus> _status = {};

  /// Existing persisted records by person key, used to surface device
  /// check-ins and preserve check-in times on manual save.
  final Map<String, SessionAttendanceRecord> _existing = {};

  @override
  void initState() {
    super.initState();
    _date = _dateOnly(
      widget.initialDate ??
          widget.session.defaultOccurrenceOnOrBefore(DateTime.now()),
    );
    _load();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _dateKey => SessionDateOverride.formatDateKey(_date);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final sessionId = widget.session.id;
    if (sessionId == null) {
      setState(() {
        _loading = false;
        _error = 'This session has not been saved yet.';
      });
      return;
    }
    try {
      final roster = await FirebaseService.resolveSessionRoster(
        widget.session,
        _date,
      );
      final records = await FirebaseService.getSessionAttendance(
        sessionId,
        _dateKey,
      );
      if (!mounted) return;
      _status.clear();
      _existing.clear();
      for (final r in records) {
        _existing[r.personKey] = r;
        if (r.status != AttendanceStatus.unknown) {
          _status[r.personKey] = r.status;
        }
      }
      setState(() {
        _roster = roster;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load roster: $e';
      });
    }
  }

  // --- Occurrence navigation -------------------------------------------------

  DateTime get _firstSelectable =>
      _dateOnly(widget.session.date).subtract(const Duration(days: 1));

  DateTime get _lastSelectable {
    if (widget.session.isRecurring) {
      return _dateOnly(DateTime.now()).add(const Duration(days: 365));
    }
    return _dateOnly(widget.session.endDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _dateOnly(widget.session.date),
      lastDate: _lastSelectable,
      selectableDayPredicate: widget.session.occursAndNotSkipped,
      helpText: 'Select occurrence',
    );
    if (picked != null && !_dateOnly(picked).isAtSameMomentAs(_date)) {
      setState(() => _date = _dateOnly(picked));
      await _load();
    }
  }

  void _stepOccurrence(int direction) {
    var d = _date.add(Duration(days: direction));
    final lower = _firstSelectable;
    final upper = _lastSelectable;
    while (!d.isBefore(lower) && !d.isAfter(upper)) {
      if (widget.session.occursAndNotSkipped(d)) {
        setState(() => _date = _dateOnly(d));
        _load();
        return;
      }
      d = d.add(Duration(days: direction));
    }
  }

  bool _hasEarlierOccurrence() {
    var d = _date.subtract(const Duration(days: 1));
    final lower = _firstSelectable;
    while (!d.isBefore(lower)) {
      if (widget.session.occursAndNotSkipped(d)) return true;
      d = d.subtract(const Duration(days: 1));
    }
    return false;
  }

  bool _hasLaterOccurrence() {
    var d = _date.add(const Duration(days: 1));
    final upper = _lastSelectable;
    while (!d.isAfter(upper)) {
      if (widget.session.occursAndNotSkipped(d)) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  // --- Marking ---------------------------------------------------------------

  void _setStatus(SessionAttendee a, AttendanceStatus status) {
    setState(() => _status[a.compoundKey] = status);
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final a in _roster) {
        _status[a.compoundKey] = status;
      }
    });
  }

  void _clearSelections() {
    setState(_status.clear);
  }

  Future<void> _save() async {
    final sessionId = widget.session.id;
    if (sessionId == null) return;
    if (_status.isEmpty) {
      _toast('Mark at least one person before saving.');
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = AuthService.currentSession;
    final markedBy = auth?.name?.trim().isNotEmpty == true
        ? auth!.name!.trim()
        : (auth?.email ?? auth?.uid);

    final records = <SessionAttendanceRecord>[];
    for (final a in _roster) {
      final status = _status[a.compoundKey];
      if (status == null) continue;
      final prior = _existing[a.compoundKey];
      records.add(
        SessionAttendanceRecord(
          schoolId: widget.session.schoolId,
          sessionId: sessionId,
          dateKey: _dateKey,
          personId: a.id,
          personKind: a.kind,
          personName: a.name,
          roleKey: a.roleKey,
          status: status,
          source: AttendanceSource.manual,
          checkInTime: prior?.checkInTime,
          markedBy: markedBy,
        ),
      );
    }

    try {
      await FirebaseService.bulkUpsertSessionAttendance(records);
      // Mirror student marks to the legacy attendanceHistory array so the
      // existing per-student attendance views stay in sync.
      for (final r in records) {
        if (r.personKind == 'student') {
          try {
            await FirebaseService.recordAttendance(
              studentId: r.personId,
              date: _date,
              status: r.status,
            );
          } catch (_) {
            // Non-fatal: the canonical record already landed in `attendance`.
          }
        }
      }
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved?.call();
      messenger.showSnackBar(
        SnackBar(content: Text('Saved attendance for ${_dateFmt.format(_date)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Future<void> _clearSaved() async {
    final sessionId = widget.session.id;
    if (sessionId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear saved attendance'),
        content: Text(
          'Delete all saved attendance for ${_dateFmt.format(_date)}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseService.clearSessionAttendance(sessionId, _dateKey);
      if (!mounted) return;
      widget.onSaved?.call();
      messenger.showSnackBar(const SnackBar(content: Text('Cleared attendance')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to clear: $e')));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- Grouping --------------------------------------------------------------

  static const _builtinRoleKeys = {'teacher', 'admin', 'staff', 'worker'};

  String _groupLabel(SessionAttendee a) {
    if (a.kind == 'student') return 'Students';
    final rk = a.roleKey;
    if (rk != null && rk.isNotEmpty && !_builtinRoleKeys.contains(rk.toLowerCase())) {
      return rk;
    }
    return AuthRoles.kindLabelPlural(a.kind);
  }

  int _groupPriority(String label) {
    switch (label) {
      case 'Students':
        return 0;
      case 'Teachers':
        return 1;
      case 'Administrators':
        return 2;
      case 'Staff accounts':
        return 3;
      case 'Workers':
        return 4;
      default:
        return 5; // custom roles, alphabetical after the built-ins
    }
  }

  List<SessionAttendee> get _visibleRoster {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _roster;
    return _roster.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = (widget.session.name?.trim().isNotEmpty ?? false)
        ? widget.session.name!.trim()
        : 'Attendance';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take attendance'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (v) {
              if (v == 'clear') _clearSaved();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Clear saved attendance'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(colorScheme, title),
          const Divider(height: 1),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(colorScheme),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, String title) {
    final times = widget.session.effectiveTimesFor(_date);
    final timeLabel = [
      if ((times.startTime ?? '').isNotEmpty && (times.endTime ?? '').isNotEmpty)
        '${times.startTime}-${times.endTime}'
      else if ((times.startTime ?? '').isNotEmpty)
        times.startTime!,
      if ((times.lateTime ?? '').isNotEmpty) 'late ${times.lateTime}',
    ].join(' · ');

    final counts = _statusCounts();

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.school != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.school!.name,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous occurrence',
                onPressed: _hasEarlierOccurrence() ? () => _stepOccurrence(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_dateFmt.format(_date)),
                ),
              ),
              IconButton(
                tooltip: 'Next occurrence',
                onPressed: _hasLaterOccurrence() ? () => _stepOccurrence(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (timeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                timeLabel,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _countChip('Present', counts[AttendanceStatus.present] ?? 0, Colors.green),
              _countChip('Late', counts[AttendanceStatus.late] ?? 0, Colors.orange),
              _countChip('Absent', counts[AttendanceStatus.absent] ?? 0, Colors.red),
              _countChip('Excused', counts[AttendanceStatus.excused] ?? 0, Colors.blue),
              _countChip('Unmarked', _unmarkedCount(), colorScheme.outline),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search roster...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Bulk mark',
                icon: const Icon(Icons.checklist),
                onSelected: (v) {
                  switch (v) {
                    case 'present':
                      _markAll(AttendanceStatus.present);
                      break;
                    case 'absent':
                      _markAll(AttendanceStatus.absent);
                      break;
                    case 'clear':
                      _clearSelections();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'present', child: Text('Mark all present')),
                  PopupMenuItem(value: 'absent', child: Text('Mark all absent')),
                  PopupMenuItem(value: 'clear', child: Text('Clear selections')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      );
    }
    final visible = _visibleRoster;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _roster.isEmpty
                ? 'No one is assigned to this session.'
                : 'No roster members match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Group, then flatten into a list of header + member rows.
    final groups = <String, List<SessionAttendee>>{};
    for (final a in visible) {
      groups.putIfAbsent(_groupLabel(a), () => []).add(a);
    }
    final orderedLabels = groups.keys.toList()
      ..sort((a, b) {
        final p = _groupPriority(a).compareTo(_groupPriority(b));
        return p != 0 ? p : a.toLowerCase().compareTo(b.toLowerCase());
      });

    final items = <Widget>[];
    for (final label in orderedLabels) {
      final members = groups[label]!;
      items.add(_groupHeader(colorScheme, label, members.length));
      for (final a in members) {
        items.add(_memberRow(colorScheme, a));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _groupHeader(ColorScheme colorScheme, String label, int count) {
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '$label · $count',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _memberRow(ColorScheme colorScheme, SessionAttendee a) {
    final key = a.compoundKey;
    final selected = _status[key];
    final prior = _existing[key];
    final isDevice = prior?.source == AttendanceSource.device;

    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name.isEmpty ? '(unnamed)' : a.name,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (isDevice && (prior?.checkInTime ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.fingerprint, size: 12, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Scanned ${prior!.checkInTime}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _statusSelector(selected, (s) => _setStatus(a, s)),
        ],
      ),
    );
  }

  Widget _statusSelector(
    AttendanceStatus? selected,
    ValueChanged<AttendanceStatus> onSelect,
  ) {
    Widget chip(String label, AttendanceStatus status, Color color) {
      final isSelected = selected == status;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        selectedColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        backgroundColor: color.withValues(alpha: 0.08),
        onSelected: (_) => onSelect(status),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip('Present', AttendanceStatus.present, Colors.green),
        chip('Late', AttendanceStatus.late, Colors.orange),
        chip('Absent', AttendanceStatus.absent, Colors.red),
        chip('Excused', AttendanceStatus.excused, Colors.blue),
      ],
    );
  }

  Widget _buildSaveBar(ColorScheme colorScheme) {
    final markedCount = _status.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$markedCount of ${_roster.length} marked',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ),
            FilledButton.icon(
              onPressed: (_saving || _loading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save attendance'),
            ),
          ],
        ),
      ),
    );
  }

  Map<AttendanceStatus, int> _statusCounts() {
    final counts = <AttendanceStatus, int>{};
    for (final s in _status.values) {
      counts.update(s, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  int _unmarkedCount() {
    var marked = 0;
    for (final a in _roster) {
      if (_status.containsKey(a.compoundKey)) marked++;
    }
    return _roster.length - marked;
  }
}
