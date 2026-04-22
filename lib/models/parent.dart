import 'package:cloud_firestore/cloud_firestore.dart';

class Parent {
  final String? id;
  final String phone;
  final String? name;
  final String? email;
  final String? relationship; // "father" | "mother" | "guardian"
  final List<String> studentIds;
  final String? schoolId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const Parent({
    this.id,
    required this.phone,
    this.name,
    this.email,
    this.relationship,
    this.studentIds = const [],
    this.schoolId,
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
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

  factory Parent.fromFirestore(Map<String, dynamic> data, String id) {
    return Parent(
      id: id,
      phone: data['phone'] ?? '',
      name: data['name'],
      email: data['email'],
      relationship: data['relationship'],
      studentIds: (data['studentIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      schoolId: data['schoolId'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      lastLogin: _parseDate(data['lastLogin']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (relationship != null) 'relationship': relationship,
      'studentIds': studentIds,
      if (schoolId != null) 'schoolId': schoolId,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastLogin != null) 'lastLogin': lastLogin,
    };
  }
}
