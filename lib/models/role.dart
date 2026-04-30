import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/role_constants.dart';

/// A custom role definition for a school. Distinct from the built-in
/// system roles (admin/teacher/parent/worker/student). Schools can use
/// these to label additional staff categories.
class Role {
  final String? id;
  final String name;
  final String? description;
  final String schoolId;

  /// Hex string like `#FF7043`. Optional UI hint.
  final String? color;

  /// Which person collections this role can be attached to. Stored as a
  /// Firestore array of `AuthRoles.kind*` values (`worker`, `teacher`,
  /// `admin`, `staff`). Defaults to `['worker']` for backward compat with
  /// roles created before the multi-kind extension.
  final List<String> appliesTo;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Role({
    this.id,
    required this.name,
    this.description,
    required this.schoolId,
    this.color,
    this.appliesTo = const [AuthRoles.kindWorker],
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

  static List<String> _parseAppliesTo(dynamic v) {
    if (v is List) {
      final out = <String>[];
      for (final item in v) {
        if (item is String && item.trim().isNotEmpty) {
          final lower = item.trim().toLowerCase();
          if (AuthRoles.allKinds.contains(lower) && !out.contains(lower)) {
            out.add(lower);
          }
        }
      }
      if (out.isNotEmpty) return out;
    }
    return const [AuthRoles.kindWorker];
  }

  factory Role.fromFirestore(Map<String, dynamic> data, String id) {
    return Role(
      id: id,
      name: (data['name'] ?? '') as String,
      description: data['description'] as String?,
      schoolId: (data['schoolId'] ?? '') as String,
      color: data['color'] as String?,
      appliesTo: _parseAppliesTo(data['appliesTo']),
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
      if (color != null) 'color': color,
      'appliesTo': appliesTo,
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
    String? color,
    List<String>? appliesTo,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      schoolId: schoolId ?? this.schoolId,
      color: color ?? this.color,
      appliesTo: appliesTo ?? this.appliesTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
