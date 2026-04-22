import 'package:cloud_firestore/cloud_firestore.dart';

class ClassGroup {
  final String? id;
  final String name;
  final String schoolId;
  final String? grade;
  final String? level;
  final String? teacherId;
  final String? teacherName;
  final List<String> studentIds;
  final bool isActive;
  final DateTime? createdAt;

  const ClassGroup({
    this.id,
    required this.name,
    required this.schoolId,
    this.grade,
    this.level,
    this.teacherId,
    this.teacherName,
    this.studentIds = const [],
    this.isActive = true,
    this.createdAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    if (v is DateTime) return v;
    return null;
  }

  factory ClassGroup.fromFirestore(Map<String, dynamic> data, String id) {
    return ClassGroup(
      id: id,
      name: data['name'] ?? '',
      schoolId: data['schoolId'] ?? '',
      grade: data['grade'],
      level: data['level'],
      teacherId: data['teacherId'],
      teacherName: data['teacherName'],
      studentIds: (data['studentIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'schoolId': schoolId,
      if (grade != null) 'grade': grade,
      if (level != null) 'level': level,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
      'studentIds': studentIds,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
