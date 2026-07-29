import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../models/session.dart';
import '../../models/session_date_override.dart';
import '../../services/firebase_service.dart';
import '../../utils/responsive_builder.dart';
import 'package:intl/intl.dart';

class AttendanceDashboard extends StatefulWidget {
  final List<Student> students;

  const AttendanceDashboard({
    Key? key,
    required this.students,
  }) : super(key: key);

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  DateTime _selectedDate = DateTime.now();
  ViewMode _viewMode = ViewMode.day;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Session filter: null means "all sessions".
  String? _sessionFilterId;
  List<Session> _sessions = [];
  bool _loadingSessions = true;

  // Per-occurrence counts pulled from the `attendance` collection when a
  // specific session is selected (covers all roles, not just students).
  int _sPresent = 0;
  int _sLate = 0;
  int _sAbsent = 0;
  int _sExcused = 0;
  int _sTotal = 0;
  bool _loadingSessionData = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _bestEffortIngest();
  }

  /// Best-effort pull of recent fingerprint scans into per-session attendance
  /// so the dashboard reflects device activity without a manual sync. Fully
  /// guarded: any failure (permissions, offline) is silently ignored.
  void _bestEffortIngest() {
    unawaited(
      FirebaseService.ingestDeviceScans(
        since: DateTime.now().subtract(const Duration(days: 2)),
      ).then((_) {
        if (mounted && _sessionFilterId != null) _loadSessionData();
      }).catchError((_) {}),
    );
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await FirebaseService.getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSessions = false);
    }
  }

  Session? get _selectedSession {
    if (_sessionFilterId == null) return null;
    for (final s in _sessions) {
      if (s.id == _sessionFilterId) return s;
    }
    return null;
  }

  /// Loads attendance + roster size for the selected session occurrence and
  /// caches the per-status counts. No-op when no session is selected.
  Future<void> _loadSessionData() async {
    final session = _selectedSession;
    if (session == null || session.id == null) {
      setState(() {
        _sPresent = 0;
        _sLate = 0;
        _sAbsent = 0;
        _sExcused = 0;
        _sTotal = 0;
        _loadingSessionData = false;
      });
      return;
    }
    setState(() => _loadingSessionData = true);
    try {
      final dateKey = SessionDateOverride.formatDateKey(_selectedDate);
      final records = await FirebaseService.getSessionAttendance(
        session.id!,
        dateKey,
      );
      final roster = await FirebaseService.resolveSessionRoster(
        session,
        _selectedDate,
      );
      if (!mounted) return;
      var present = 0, late = 0, absent = 0, excused = 0;
      for (final r in records) {
        switch (r.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.late:
            late++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
          case AttendanceStatus.excused:
            excused++;
            break;
          case AttendanceStatus.unknown:
            break;
        }
      }
      setState(() {
        _sPresent = present;
        _sLate = late;
        _sAbsent = absent;
        _sExcused = excused;
        _sTotal = roster.length;
        _loadingSessionData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSessionData = false);
    }
  }

  void _selectPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadSessionData();
  }

  void _selectNextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = tomorrow;
      });
      _loadSessionData();
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadSessionData();
    }
  }

  void _toggleViewMode() {
    setState(() {
      if (_viewMode == ViewMode.day) {
        _viewMode = ViewMode.range;
      } else {
        _viewMode = ViewMode.day;
      }
    });
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<Student> get _filteredStudents {
    if (_sessionFilterId == null) return widget.students;
    return widget.students
        .where((s) => s.sessionIds.contains(_sessionFilterId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final String selectedDateFormatted = _viewMode == ViewMode.day
        ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)
        : '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}';

    final students = _filteredStudents;

    // When a specific session is selected in day view, show that occurrence's
    // attendance straight from the `attendance` collection (covers every
    // audience kind). Otherwise fall back to the legacy per-student history.
    final bool sessionDayMode =
        _viewMode == ViewMode.day && _sessionFilterId != null;

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;
    int totalStudents;

    if (sessionDayMode) {
      present = _sPresent;
      late = _sLate;
      absent = _sAbsent;
      excused = _sExcused;
      totalStudents = _sTotal;
    } else {
      totalStudents = students.length;
      for (final student in students) {
        final filteredAttendance = student.attendanceHistory.where((a) {
          if (_viewMode == ViewMode.day) {
            return a.date.day == _selectedDate.day &&
                a.date.month == _selectedDate.month &&
                a.date.year == _selectedDate.year;
          } else {
            return a.date
                    .isAfter(_startDate.subtract(const Duration(days: 1))) &&
                a.date.isBefore(_endDate.add(const Duration(days: 1)));
          }
        });

        for (final attendance in filteredAttendance) {
          switch (attendance.status) {
            case AttendanceStatus.present:
              present++;
              break;
            case AttendanceStatus.absent:
              absent++;
              break;
            case AttendanceStatus.late:
              late++;
              break;
            case AttendanceStatus.excused:
              excused++;
              break;
            case AttendanceStatus.unknown:
              break;
          }
        }
      }
    }

    final int totalRecorded = present + absent + late + excused;
    final int missingRecords =
        _viewMode == ViewMode.day ? (totalStudents - totalRecorded) : 0;

    final bool isToday = _viewMode == ViewMode.day &&
        _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _toggleViewMode,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        Text(
                          _viewMode == ViewMode.day ? 'Daily Attendance' : 'Date Range',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: context.isMobile ? 16 : 18,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: context.isMobile ? 18 : 20,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _viewMode == ViewMode.day ? Icons.calendar_today : Icons.date_range,
                        size: context.isMobile ? 18 : 20,
                      ),
                      onPressed: _viewMode == ViewMode.day ? _selectDate : _selectDateRange,
                      tooltip: _viewMode == ViewMode.day ? 'Select date' : 'Select date range',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: context.isMobile ? 32 : 40,
                        minHeight: context.isMobile ? 32 : 40,
                      ),
                    ),
                    if (_viewMode == ViewMode.day) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _selectPreviousDay,
                        tooltip: 'Previous day',
                        visualDensity: VisualDensity.compact,
                        iconSize: context.isMobile ? 20 : 24,
                        padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: context.isMobile ? 32 : 40,
                          minHeight: context.isMobile ? 32 : 40,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _selectedDate.isBefore(DateTime.now()) ? _selectNextDay : null,
                        tooltip: 'Next day',
                        visualDensity: VisualDensity.compact,
                        iconSize: context.isMobile ? 20 : 24,
                        padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: context.isMobile ? 32 : 40,
                          minHeight: context.isMobile ? 32 : 40,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingXs),
              child: Row(
                children: [
                  Text(
                    selectedDateFormatted,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: context.isMobile ? 12 : 14,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: context.isMobile ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: context.spacingSm),

            _buildSessionFilter(),

            SizedBox(height: context.spacingSm),

            if (sessionDayMode && _loadingSessionData)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),

            if (sessionDayMode && excused > 0)
              Padding(
                padding: EdgeInsets.only(bottom: context.spacingSm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Excused: $excused',
                    style: TextStyle(
                      fontSize: context.isMobile ? 12 : 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            if (_viewMode == ViewMode.day && missingRecords > 0)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: context.spacingSm),
                padding: EdgeInsets.all(context.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: context.isMobile ? 18 : 20,
                    ),
                    SizedBox(width: context.spacingSm),
                    Expanded(
                      child: Text(
                        sessionDayMode
                            ? 'Not yet marked: $missingRecords ${missingRecords == 1 ? 'person' : 'people'}'
                            : 'Missing attendance records for $missingRecords student${missingRecords == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: context.isMobile ? 12 : 14,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            LayoutBuilder(
              builder: (context, constraints) {
                final bool useVerticalLayout = constraints.maxWidth < 600;

                if (constraints.maxWidth < 380) {
                  return Column(
                    children: [
                      _buildAttendanceIndicator('Present', present, totalStudents, Colors.green, context),
                      SizedBox(height: context.spacingXs),
                      _buildAttendanceIndicator('Absent', absent, totalStudents, Colors.red, context),
                      SizedBox(height: context.spacingXs),
                      _buildAttendanceIndicator('Late', late, totalStudents, Colors.orange, context),
                    ],
                  );
                }

                if (useVerticalLayout) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceIndicator('Present', present, totalStudents, Colors.green, context),
                          ),
                          SizedBox(width: context.spacingSm),
                          Expanded(
                            child: _buildAttendanceIndicator('Absent', absent, totalStudents, Colors.red, context),
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacingSm),
                      _buildAttendanceIndicator('Late', late, totalStudents, Colors.orange, context),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildAttendanceIndicator('Present', present, totalStudents, Colors.green, context),
                      ),
                      SizedBox(width: context.spacingSm),
                      Expanded(
                        child: _buildAttendanceIndicator('Absent', absent, totalStudents, Colors.red, context),
                      ),
                      SizedBox(width: context.spacingSm),
                      Expanded(
                        child: _buildAttendanceIndicator('Late', late, totalStudents, Colors.orange, context),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionFilter() {
    if (_loadingSessions) {
      return const SizedBox(height: 4, child: LinearProgressIndicator());
    }
    if (_sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<String?>(
      value: _sessions.any((s) => s.id == _sessionFilterId) ? _sessionFilterId : null,
      decoration: const InputDecoration(
        labelText: 'Session',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All sessions')),
        ..._sessions.where((s) => s.id != null).map(
              (s) => DropdownMenuItem<String?>(
                value: s.id,
                child: Text(_sessionLabel(s)),
              ),
            ),
      ],
      onChanged: (v) {
        setState(() => _sessionFilterId = v);
        _loadSessionData();
      },
    );
  }

  String _sessionLabel(Session s) {
    if (s.className != null && s.className!.isNotEmpty) return s.className!;
    if (s.teacherName != null && s.teacherName!.isNotEmpty) return s.teacherName!;
    return 'Session ${s.id}';
  }

  Widget _buildAttendanceIndicator(
    String label,
    int count,
    int total,
    Color color,
    BuildContext context,
  ) {
    final double percentage = total > 0 ? count / total * 100 : 0;

    return Container(
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: context.isMobile ? 12 : 14),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: context.isMobile ? 6 : 8,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            '$count students',
            style: TextStyle(
              fontSize: context.isMobile ? 10 : 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

enum ViewMode {
  day,
  range,
}

class AttendanceData {
  final String status;
  final int count;
  final int total;
  final Color color;

  AttendanceData(this.status, this.count, this.total, this.color);
}
