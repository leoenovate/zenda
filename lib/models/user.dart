import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String? id;
  final String email;
  final String? name;
  final String? role; // "admin" | "teacher" | "system_owner" | "staff" | "guardian"

  /// Persisted as Firestore `orgId` (legacy docs used `schoolId`). The Dart
  /// property name is kept as `schoolId` to avoid churn across the UI.
  final String? schoolId;
  final String? phone;

  /// Foreign key into `roles/{id}` (custom role label, e.g. "I.T Officer").
  /// Only meaningful for `staff` / `admin` users; null otherwise. Guardian
  /// users carry `guardian-<orgId>`.
  final String? roleId;

  /// Guardian accounts: the student `members/{id}` this user is a guardian of.
  final List<String> linkedStudentIds;

  /// Optional link from a login account to its `members/{id}` record.
  final String? memberId;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  /// True when this user is a parent/guardian account (migrated from the old
  /// `parents` collection).
  bool get isGuardian =>
      (roleId != null && roleId!.startsWith('guardian-')) ||
      linkedStudentIds.isNotEmpty ||
      role == 'guardian' ||
      role == 'parent';

  const AppUser({
    this.id,
    required this.email,
    this.name,
    this.role,
    this.schoolId,
    this.phone,
    this.roleId,
    this.linkedStudentIds = const [],
    this.memberId,
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
  });

  // Helper function to parse date from Firestore (handles both Timestamp and ISO string)
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

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      name: data['name'],
      role: data['role'],
      schoolId: data['orgId'] ?? data['schoolId'],
      phone: data['phone'],
      roleId: data['roleId'] as String?,
      linkedStudentIds: (data['linkedStudentIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      memberId: data['memberId'] as String?,
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      lastLogin: _parseDate(data['lastLogin']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (schoolId != null) 'orgId': schoolId,
      if (phone != null) 'phone': phone,
      if (roleId != null) 'roleId': roleId,
      if (linkedStudentIds.isNotEmpty) 'linkedStudentIds': linkedStudentIds,
      if (memberId != null) 'memberId': memberId,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastLogin != null) 'lastLogin': lastLogin,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? schoolId,
    String? phone,
    String? roleId,
    List<String>? linkedStudentIds,
    String? memberId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      phone: phone ?? this.phone,
      roleId: roleId ?? this.roleId,
      linkedStudentIds: linkedStudentIds ?? this.linkedStudentIds,
      memberId: memberId ?? this.memberId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
