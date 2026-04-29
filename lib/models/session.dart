import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? teacherId;
  final String? teacherName;
  final String audienceType;
  final String? audienceMode;
  final String? audienceRole;
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
      teacherId: _optionalString(data['teacherId']),
      teacherName: _optionalString(data['teacherName']),
      audienceType: _optionalString(data['audienceType']) ?? 'students',
      audienceMode: _optionalString(data['audienceMode']),
      audienceRole: _optionalString(data['audienceRole']),
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
      if (audienceLabel != null) 'audienceLabel': audienceLabel,
    };
  }
}
