import 'package:cloud_firestore/cloud_firestore.dart';

/// A daily attendance window. Sessions can target either:
///
/// * a class of **students** (`audienceType == 'students'`,
///   `audienceMode == 'class'`) — uses [classId] / [className] and an
///   optional responsible [teacherId] / [teacherName], or
/// * everyone in a **role** (`audienceType == 'role'`,
///   `audienceMode == 'all'`) — uses [audienceRole] (e.g. `teacher`,
///   `admin`, `staff`, `worker`, or any custom role name) plus
///   [assigneeKind] which classifies which collection the role draws
///   people from, or
/// * a **single person** in a role (`audienceType == 'role'`,
///   `audienceMode == 'single'`) — adds [assigneeId] / [assigneeName].
///
/// Legacy documents that used `audienceType: 'teachers'` with
/// `audienceMode: 'all_teachers' | 'single_teacher'` are migrated on read
/// to the new shape so the rest of the app sees a single, role-based
/// representation.
class Session {
  final String? id;
  final String schoolId;
  final DateTime date;
  final bool isActive;
  final String? startTime;
  final String? endTime;
  final String? lateTime;
  final String? className;
  final String? classId;

  /// Responsible teacher for a student-class session. Kept populated when
  /// [audienceRole] is `teacher` so existing teacher-facing screens keep
  /// working unchanged.
  final String? teacherId;
  final String? teacherName;

  /// `students` (class-based) or `role` (role-based).
  final String audienceType;

  /// For students: `class`. For role audiences: `all` (everyone in the
  /// role) or `single` (one specific person).
  final String? audienceMode;

  /// Role identifier used when [audienceType] is `role`. Built-in values:
  /// `teacher`, `admin`, `staff`, `worker`. May also be a custom role
  /// name as defined in the `roles/{id}` collection.
  final String? audienceRole;

  /// Which collection the role draws its people from when
  /// [audienceMode] is `single`. One of: `teacher`, `admin`, `staff`,
  /// `worker`. Custom roles map to `worker` (since custom roles are
  /// attached to worker records via `workers/{id}.role`).
  final String? assigneeKind;

  /// Single-person assignment (id + display name) when
  /// [audienceMode] is `single`.
  final String? assigneeId;
  final String? assigneeName;

  /// Human-readable label cached for list rows (e.g. "Class: 3A",
  /// "All teachers", "Cleaning Staff: Jane Doe").
  final String? audienceLabel;

  const Session({
    this.id,
    required this.schoolId,
    required this.date,
    this.isActive = false,
    this.startTime,
    this.endTime,
    this.lateTime,
    this.className,
    this.classId,
    this.teacherId,
    this.teacherName,
    this.audienceType = 'students',
    this.audienceMode,
    this.audienceRole,
    this.assigneeKind,
    this.assigneeId,
    this.assigneeName,
    this.audienceLabel,
  });

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

  factory Session.fromFirestore(Map<String, dynamic> data, String id) {
    final dateValue = _parseDate(data['date']);
    if (dateValue == null) {
      throw Exception('Session date is required');
    }

    var audienceType = _optionalString(data['audienceType']) ?? 'students';
    var audienceMode = _optionalString(data['audienceMode']);
    var audienceRole = _optionalString(data['audienceRole']);
    var assigneeKind = _optionalString(data['assigneeKind']);
    var assigneeId = _optionalString(data['assigneeId']);
    var assigneeName = _optionalString(data['assigneeName']);

    final teacherId = _optionalString(data['teacherId']);
    final teacherName = _optionalString(data['teacherName']);

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

    return Session(
      id: id,
      schoolId:
          data['schoolId'] is String
              ? (data['schoolId'] as String)
              : (data['schoolId']?.toString() ?? ''),
      date: dateValue,
      isActive: data['isActive'] ?? false,
      startTime: _optionalString(data['startTime'], timeOfDay: true),
      endTime: _optionalString(data['endTime'], timeOfDay: true),
      lateTime: _optionalString(data['lateTime'], timeOfDay: true),
      className: _optionalString(data['className']),
      classId: _optionalString(data['classId']),
      teacherId: teacherId,
      teacherName: teacherName,
      audienceType: audienceType,
      audienceMode: audienceMode,
      audienceRole: audienceRole,
      assigneeKind: assigneeKind,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      audienceLabel: _optionalString(data['audienceLabel']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'date': Timestamp.fromDate(date),
      'isActive': isActive,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (lateTime != null) 'lateTime': lateTime,
      if (className != null) 'className': className,
      if (classId != null) 'classId': classId,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
      'audienceType': audienceType,
      if (audienceMode != null) 'audienceMode': audienceMode,
      if (audienceRole != null) 'audienceRole': audienceRole,
      if (assigneeKind != null) 'assigneeKind': assigneeKind,
      if (assigneeId != null) 'assigneeId': assigneeId,
      if (assigneeName != null) 'assigneeName': assigneeName,
      if (audienceLabel != null) 'audienceLabel': audienceLabel,
    };
  }
}
