import 'package:cloud_firestore/cloud_firestore.dart';

/// Staff/employee record. Distinct from `Student`; used for non-student
/// attendance (e.g. kitchen staff, cleaners, security).
class Worker {
  final String? id;
  final String name;
  final String schoolId;
  final String? employeeId;
  final String? role;
  final String? phone;
  final String? email;
  final String? fingerprintData;
  final String? fingerprintTimestamp;
  final bool isActive;
  final DateTime? createdAt;

  const Worker({
    this.id,
    required this.name,
    required this.schoolId,
    this.employeeId,
    this.role,
    this.phone,
    this.email,
    this.fingerprintData,
    this.fingerprintTimestamp,
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

  factory Worker.fromFirestore(Map<String, dynamic> data, String id) {
    return Worker(
      id: id,
      name: data['name'] ?? '',
      schoolId: data['schoolId'] ?? '',
      employeeId: data['employeeId'],
      role: data['role'],
      phone: data['phone'],
      email: data['email'],
      fingerprintData: data['fingerprintData'],
      fingerprintTimestamp: data['fingerprintTimestamp'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'schoolId': schoolId,
      if (employeeId != null) 'employeeId': employeeId,
      if (role != null) 'role': role,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (fingerprintData != null) 'fingerprintData': fingerprintData,
      if (fingerprintTimestamp != null) 'fingerprintTimestamp': fingerprintTimestamp,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
