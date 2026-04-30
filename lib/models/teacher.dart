import 'package:cloud_firestore/cloud_firestore.dart';

class Teacher {
  final String? id;
  final String name;
  final String schoolId;
  final String? email;
  final String? phone;
  final String? subject;
  final String? classId;
  final String? employeeId;

  /// Foreign key into `roles/{id}` (custom role assignment). May be null
  /// for teachers without a custom-role label.
  final String? roleId;

  final bool isActive;
  final DateTime? createdAt;

  const Teacher({
    this.id,
    required this.name,
    required this.schoolId,
    this.email,
    this.phone,
    this.subject,
    this.classId,
    this.employeeId,
    this.roleId,
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

  factory Teacher.fromFirestore(Map<String, dynamic> data, String id) {
    return Teacher(
      id: id,
      name: data['name'] ?? '',
      schoolId: data['schoolId'] ?? '',
      email: data['email'],
      phone: data['phone'],
      subject: data['subject'],
      classId: data['classId'],
      employeeId: data['employeeId'],
      roleId: data['roleId'] as String?,
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'schoolId': schoolId,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (subject != null) 'subject': subject,
      if (classId != null) 'classId': classId,
      if (employeeId != null) 'employeeId': employeeId,
      if (roleId != null) 'roleId': roleId,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  Teacher copyWith({
    String? id,
    String? name,
    String? schoolId,
    String? email,
    String? phone,
    String? subject,
    String? classId,
    String? employeeId,
    String? roleId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      subject: subject ?? this.subject,
      classId: classId ?? this.classId,
      employeeId: employeeId ?? this.employeeId,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
