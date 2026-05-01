import 'package:cloud_firestore/cloud_firestore.dart';

import 'session_attendee.dart';
import 'session_date_override.dart';

/// A configurable attendance window. The audience can mix:
///
/// * **Classes** of students via [classIds] / [classNames] (multi-select).
/// * **Whole roles** via [audienceRoles] — built-in (`teacher`, `admin`,
///   `staff`, `worker`) or any custom role name. Targets every active
///   member of that role at attendance-time.
/// * **Individuals** via [attendees] — explicit picks across any role.
///
/// Sessions can also span multiple days ([date] -> [endDate]) and recur
/// according to [recurrence] (`none` | `daily` | `weekly` | `monthly` |
/// `yearly`).
///
/// Legacy single-target documents are migrated transparently in
/// [Session.fromFirestore]. To keep older callers working, the legacy
/// scalar fields ([classId], [className], [teacherId], [teacherName],
/// [audienceType], [audienceMode], [audienceRole], [assigneeKind/Id/Name])
/// are mirrored on write whenever the new model maps cleanly to a single
/// target.
class Session {
  final String? id;
  final String schoolId;

  /// Optional human-friendly title (e.g. "Weekly staff meeting"). Falls
  /// back to a derived label in list rows when null/empty.
  final String? name;

  /// Start date of the window. For single-day sessions this is the
  /// attendance day; for multi-day windows it is the first day.
  final DateTime date;

  /// Last day of the window. Equal to [date] for single-day sessions.
  final DateTime endDate;

  /// `none` | `daily` | `weekly` | `monthly` | `yearly`. Pure metadata in
  /// this pass — runtime expansion can be added later without changing
  /// the schema.
  final String recurrence;

  final bool isActive;
  final String? startTime;
  final String? endTime;
  final String? lateTime;

  /// Optional cached display name of the *first* class in [classNames].
  /// Maintained for legacy callers that read [Session.className] directly.
  final String? className;

  /// Optional id of the first class in [classIds]. Same legacy concern as
  /// [className].
  final String? classId;

  /// All classes targeted by this session. Empty when no class is in the
  /// audience.
  final List<String> classIds;
  final List<String> classNames;

  /// Responsible teacher of the (single) class, or the picked teacher
  /// when this session targets exactly one teacher individually. Kept for
  /// teacher-dashboard back-compat.
  final String? teacherId;
  final String? teacherName;

  /// Legacy audience descriptors. Derived on write when the session has
  /// exactly one audience source (one class, or one role-bundle, or one
  /// attendee) so older clients can still render a meaningful label.
  final String audienceType;
  final String? audienceMode;
  final String? audienceRole;
  final String? assigneeKind;
  final String? assigneeId;
  final String? assigneeName;

  /// Cached human-readable label.
  final String? audienceLabel;

  /// Role keys whose entire roster is included. Built-in keys are
  /// `teacher`, `admin`, `staff`, `worker`; custom roles use the role
  /// name as the key.
  final List<String> audienceRoles;

  /// Individually picked people, in addition to [audienceRoles] and
  /// [classIds].
  final List<SessionAttendee> attendees;

  /// Per-day customizations: skip a specific day or replace its
  /// start/end/late times. Indexed by `YYYY-MM-DD` in the UI.
  final List<SessionDateOverride> dateOverrides;

  const Session({
    this.id,
    required this.schoolId,
    this.name,
    required this.date,
    DateTime? endDate,
    this.recurrence = 'none',
    this.isActive = false,
    this.startTime,
    this.endTime,
    this.lateTime,
    this.className,
    this.classId,
    this.classIds = const [],
    this.classNames = const [],
    this.teacherId,
    this.teacherName,
    this.audienceType = 'students',
    this.audienceMode,
    this.audienceRole,
    this.assigneeKind,
    this.assigneeId,
    this.assigneeName,
    this.audienceLabel,
    this.audienceRoles = const [],
    this.attendees = const [],
    this.dateOverrides = const [],
  }) : endDate = endDate ?? date;

  bool get isMultiDay =>
      endDate.year != date.year ||
      endDate.month != date.month ||
      endDate.day != date.day;

  bool get isRecurring => recurrence != 'none' && recurrence.isNotEmpty;

  /// Lookup an override for [day] (date-only). Returns null when there
  /// is no per-day customization.
  SessionDateOverride? overrideFor(DateTime day) {
    final key = SessionDateOverride.formatDateKey(day);
    for (final o in dateOverrides) {
      if (o.dateKey == key) return o;
    }
    return null;
  }

  /// True when [day] has been explicitly skipped by the admin.
  bool isSkipped(DateTime day) => overrideFor(day)?.excluded ?? false;

  /// Effective `(startTime, endTime, lateTime)` for [day], applying any
  /// per-day overrides on top of the session-level defaults. Returns
  /// nulls for any field that is unset.
  ({String? startTime, String? endTime, String? lateTime})
      effectiveTimesFor(DateTime day) {
    final ov = overrideFor(day);
    return (
      startTime: ov?.startTime ?? startTime,
      endTime: ov?.endTime ?? endTime,
      lateTime: ov?.lateTime ?? lateTime,
    );
  }

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (_) {
        return null;
      }
    } else if (dateValue is DateTime) {
      return dateValue;
    }

    return null;
  }

  /// Maps optional string fields from Firestore; some legacy or migrated docs
  /// store [Timestamp] for time fields instead of "HH:mm" strings.
  static String? _optionalString(dynamic value, {bool timeOfDay = false}) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Timestamp) {
      final d = value.toDate();
      if (timeOfDay) {
        final h = d.hour.toString().padLeft(2, '0');
        final m = d.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<SessionAttendee> _attendeeList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (m) => SessionAttendee.fromMap(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((a) => a.id.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<SessionDateOverride> _overrideList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (m) => SessionDateOverride.fromMap(
              m.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((o) =>
              o.date.millisecondsSinceEpoch > 0 && o.hasCustomization)
          .toList();
    }
    return const [];
  }

  factory Session.fromFirestore(Map<String, dynamic> data, String id) {
    final dateValue = _parseDate(data['date']);
    if (dateValue == null) {
      throw Exception('Session date is required');
    }
    final endDateValue = _parseDate(data['endDate']) ?? dateValue;

    var audienceType = _optionalString(data['audienceType']) ?? 'students';
    var audienceMode = _optionalString(data['audienceMode']);
    var audienceRole = _optionalString(data['audienceRole']);
    var assigneeKind = _optionalString(data['assigneeKind']);
    var assigneeId = _optionalString(data['assigneeId']);
    var assigneeName = _optionalString(data['assigneeName']);

    final teacherId = _optionalString(data['teacherId']);
    final teacherName = _optionalString(data['teacherName']);
    final className = _optionalString(data['className']);
    final classId = _optionalString(data['classId']);

    // Migrate legacy shape: audienceType='teachers' +
    // audienceMode='all_teachers'|'single_teacher'.
    if (audienceType == 'teachers') {
      audienceType = 'role';
      audienceRole ??= 'teacher';
      assigneeKind ??= 'teacher';
      if (audienceMode == 'all_teachers') {
        audienceMode = 'all';
      } else if (audienceMode == 'single_teacher') {
        audienceMode = 'single';
        assigneeId ??= teacherId;
        assigneeName ??= teacherName;
      }
    }

    if (audienceType == 'students') {
      audienceMode ??= 'class';
    } else if (audienceType == 'role') {
      audienceMode ??= 'all';
      assigneeKind ??= 'worker';
    }

    var classIds = _stringList(data['classIds']);
    var classNames = _stringList(data['classNames']);
    if (classIds.isEmpty && classId != null && classId.isNotEmpty) {
      classIds = [classId];
    }
    if (classNames.isEmpty && className != null && className.isNotEmpty) {
      classNames = [className];
    }

    var audienceRoles = _stringList(data['audienceRoles']);
    if (audienceRoles.isEmpty &&
        audienceType == 'role' &&
        audienceMode == 'all' &&
        audienceRole != null &&
        audienceRole.isNotEmpty) {
      audienceRoles = [audienceRole];
    }

    var attendees = _attendeeList(data['attendees']);
    if (attendees.isEmpty &&
        audienceType == 'role' &&
        audienceMode == 'single' &&
        assigneeId != null &&
        assigneeId.isNotEmpty) {
      attendees = [
        SessionAttendee(
          kind: assigneeKind ?? 'worker',
          id: assigneeId,
          name: assigneeName ?? '',
          roleKey: audienceRole,
        ),
      ];
    }

    final recurrence = (_optionalString(data['recurrence']) ?? 'none')
        .toLowerCase();

    return Session(
      id: id,
      schoolId: data['schoolId'] is String
          ? (data['schoolId'] as String)
          : (data['schoolId']?.toString() ?? ''),
      name: _optionalString(data['name']),
      date: dateValue,
      endDate: endDateValue,
      recurrence: recurrence.isEmpty ? 'none' : recurrence,
      isActive: data['isActive'] ?? false,
      startTime: _optionalString(data['startTime'], timeOfDay: true),
      endTime: _optionalString(data['endTime'], timeOfDay: true),
      lateTime: _optionalString(data['lateTime'], timeOfDay: true),
      className: classNames.isNotEmpty ? classNames.first : className,
      classId: classIds.isNotEmpty ? classIds.first : classId,
      classIds: classIds,
      classNames: classNames,
      teacherId: teacherId,
      teacherName: teacherName,
      audienceType: audienceType,
      audienceMode: audienceMode,
      audienceRole: audienceRole,
      assigneeKind: assigneeKind,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      audienceLabel: _optionalString(data['audienceLabel']),
      audienceRoles: audienceRoles,
      attendees: attendees,
      dateOverrides: _overrideList(data['dateOverrides']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'schoolId': schoolId,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      'date': Timestamp.fromDate(date),
      'endDate': Timestamp.fromDate(endDate),
      'recurrence': recurrence,
      'isActive': isActive,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (lateTime != null) 'lateTime': lateTime,
      if (className != null) 'className': className,
      if (classId != null) 'classId': classId,
      if (classIds.isNotEmpty) 'classIds': classIds,
      if (classNames.isNotEmpty) 'classNames': classNames,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
      'audienceType': audienceType,
      if (audienceMode != null) 'audienceMode': audienceMode,
      if (audienceRole != null) 'audienceRole': audienceRole,
      if (assigneeKind != null) 'assigneeKind': assigneeKind,
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (assigneeName != null) 'assigneeName': assigneeName,
      if (audienceLabel != null) 'audienceLabel': audienceLabel,
      if (audienceRoles.isNotEmpty) 'audienceRoles': audienceRoles,
      if (attendees.isNotEmpty)
        'attendees': attendees.map((a) => a.toMap()).toList(),
      if (dateOverrides.isNotEmpty)
        'dateOverrides':
            dateOverrides.where((o) => o.hasCustomization).map((o) => o.toMap()).toList(),
    };
    return m;
  }
}
