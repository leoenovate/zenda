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
  });

  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Error parsing date string: $dateValue - $e');
        return null;
      }
    } else if (dateValue is DateTime) {
      return dateValue;
    }

    return null;
  }

  factory Session.fromFirestore(Map<String, dynamic> data, String id) {
    final dateValue = _parseDate(data['date']);
    if (dateValue == null) {
      throw Exception('Session date is required');
    }

    return Session(
      id: id,
      schoolId: data['schoolId'] ?? '',
      date: dateValue,
      isActive: data['isActive'] ?? false,
      startTime: data['startTime'],
      endTime: data['endTime'],
      lateTime: data['lateTime'],
      className: data['className'],
      classId: data['classId'],
      teacherId: data['teacherId'],
      teacherName: data['teacherName'],
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
    };
  }
}
