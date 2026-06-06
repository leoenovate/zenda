import 'package:cloud_firestore/cloud_firestore.dart';

/// A custom role definition for a school. Distinct from the built-in
/// system roles (admin/teacher/parent/worker/student). Schools can use
/// these to label additional staff categories.
class Role {
  final String? id;
  final String name;
  final String? description;
  final String schoolId;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Role({
    this.id,
    required this.name,
    this.description,
    required this.schoolId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
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

  factory Role.fromFirestore(Map<String, dynamic> data, String id) {
    return Role(
      id: id,
      name: (data['name'] ?? '') as String,
      description: data['description'] as String?,
      schoolId: (data['schoolId'] ?? '') as String,
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'schoolId': schoolId,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Role copyWith({
    String? id,
    String? name,
    String? description,
    String? schoolId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      schoolId: schoolId ?? this.schoolId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
