import 'package:cloud_firestore/cloud_firestore.dart';

/// Staff/employee record. Distinct from `Student`; used for non-student
/// attendance (e.g. kitchen staff, cleaners, security).
class Worker {
  final String? id;
  final String name;
  final String schoolId;
  final String? employeeId;

  /// Legacy free-form role label (e.g. `'Cleaner'`, `'Nurse'`). Preserved
  /// for read-side backward compatibility with documents written before
  /// the `roleId` migration; new writes should always set [roleId] and
  /// leave this field cleared. The migration helper
  /// `FirebaseService.migrateRoleStringsToRoleIds` rewrites legacy values
  /// into proper `roles/{id}` references.
  final String? legacyRoleName;

  /// Foreign key into `roles/{id}` (custom role assignment). May be null
  /// for unassigned workers.
  final String? roleId;

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
    this.legacyRoleName,
    this.roleId,
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
      schoolId: (data['orgId'] ?? data['schoolId'] ?? '') as String,
      employeeId: data['employeeId'],
      legacyRoleName: (data['legacyRoleLabel'] ?? data['role']) as String?,
      roleId: data['roleId'] as String?,
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
      'kind': 'worker',
      'name': name,
      'orgId': schoolId,
      if (employeeId != null) 'employeeId': employeeId,
      if (roleId != null) 'roleId': roleId,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (fingerprintData != null) 'fingerprintData': fingerprintData,
      if (fingerprintTimestamp != null)
        'fingerprintTimestamp': fingerprintTimestamp,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  /// Backward-compatible alias for [legacyRoleName]. Existing screens that
  /// still display the legacy free-form role text use this; they should be
  /// migrated to look up `roleId → Role.name` instead.
  String? get role => legacyRoleName;

  Worker copyWith({
    String? id,
    String? name,
    String? schoolId,
    String? employeeId,
    String? legacyRoleName,
    String? roleId,
    String? phone,
    String? email,
    String? fingerprintData,
    String? fingerprintTimestamp,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      employeeId: employeeId ?? this.employeeId,
      legacyRoleName: legacyRoleName ?? this.legacyRoleName,
      roleId: roleId ?? this.roleId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fingerprintData: fingerprintData ?? this.fingerprintData,
      fingerprintTimestamp: fingerprintTimestamp ?? this.fingerprintTimestamp,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
