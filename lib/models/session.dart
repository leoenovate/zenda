import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String? id;
  final String schoolId;
  final DateTime date;
  final bool isActive;
  final String? period; // "Morning" | "Afternoon"
  final String? startTime;
  final String? endTime;
  final String? className;
  final String? classId;
  final String? teacherId;
  final String? teacherName;

  const Session({
    this.id,
    required this.schoolId,
    required this.date,
    this.isActive = false,
    this.period,
    this.startTime,
    this.endTime,
    this.className,
    this.classId,
    this.teacherId,
    this.teacherName,
  });

  // Helper function to parse date from Firestore
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
      period: data['period'],
      startTime: data['startTime'],
      endTime: data['endTime'],
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
      if (period != null) 'period': period,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (className != null) 'className': className,
      if (classId != null) 'classId': classId,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
    };
  }
}

