import 'package:cloud_firestore/cloud_firestore.dart';

/// One row in the `device_enrollments` Firestore collection.
///
/// This collection is the system of record for "which employee is
/// programmed at which slot on which device". The Flutter app writes
/// here as soon as the device firmware confirms a successful enroll,
/// so the list survives api-v2 server restarts and doesn't depend on
/// the device firmware ever publishing `/status` again.
///
/// Document id is deterministic — `${deviceId}_${slotId}` — so writes
/// are idempotent upserts and there's no risk of duplicates if the
/// app and the api-v2 backup-write race.
class DeviceEnrollment {
  /// Firestore doc id (matches `${deviceId}_${slotId}` for new writes).
  final String? id;
  final String deviceId;
  final String schoolId;

  /// Slot index on the fingerprint device, 1..200. Stored as both
  /// `slotId` (Flutter-friendly) and `userId` (legacy api-v2 name) so a
  /// document round-trips cleanly regardless of which side authored it.
  final int slotId;

  final String name;
  final String cardId;
  final String? phone;
  final DateTime? enrolledAt;
  final DateTime? updatedAt;

  const DeviceEnrollment({
    this.id,
    required this.deviceId,
    required this.schoolId,
    required this.slotId,
    required this.name,
    required this.cardId,
    this.phone,
    this.enrolledAt,
    this.updatedAt,
  });

  /// Deterministic Firestore doc id used by Flutter writes so the
  /// (deviceId, slot) pair upserts idempotently.
  static String makeDocId(String deviceId, int slotId) =>
      '${deviceId}_$slotId';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory DeviceEnrollment.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return DeviceEnrollment(
      id: id,
      deviceId: (data['deviceId'] ?? '').toString(),
      schoolId: (data['schoolId'] ?? '').toString(),
      slotId: _parseInt(data['slotId'] ?? data['userId']),
      name: (data['name'] ?? data['userName'] ?? '').toString(),
      cardId: (data['cardId'] ?? '').toString(),
      phone: (data['phone'] ?? data['userPhone'])?.toString(),
      enrolledAt: _parseDate(data['enrolledAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  /// Mirror both the Flutter-friendly field names and the legacy ones
  /// the api-v2 server writes (`userId`, `userName`, `userPhone`) so a
  /// document round-trips cleanly regardless of which side authored it.
  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'schoolId': schoolId,
      'slotId': slotId,
      'userId': slotId,
      'name': name,
      'userName': name,
      'cardId': cardId,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (phone != null && phone!.isNotEmpty) 'userPhone': phone,
      if (enrolledAt != null) 'enrolledAt': enrolledAt,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DeviceEnrollment copyWith({
    String? id,
    String? deviceId,
    String? schoolId,
    int? slotId,
    String? name,
    String? cardId,
    String? phone,
    DateTime? enrolledAt,
    DateTime? updatedAt,
  }) {
    return DeviceEnrollment(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      schoolId: schoolId ?? this.schoolId,
      slotId: slotId ?? this.slotId,
      name: name ?? this.name,
      cardId: cardId ?? this.cardId,
      phone: phone ?? this.phone,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
