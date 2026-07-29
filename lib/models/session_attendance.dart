import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance.dart';

/// Where an attendance record originated. Manual marks (made by an admin or
/// teacher in the app) are authoritative and are never overwritten by device
/// ingestion; device records are written from fingerprint scans.
class AttendanceSource {
  AttendanceSource._();

  static const String manual = 'manual';
  static const String device = 'device';
}

/// A single attendance record tied to one [sessionId] occurrence
/// ([dateKey] = `YYYY-MM-DD`) for one person ([personId] + [personKind]).
///
/// Lives in the top-level `attendance` collection, scoped by [schoolId]
/// (stored as `orgId` to match the rest of the schema). The document id is
/// deterministic — `${sessionId}__${dateKey}__${personKind}__${personId}` —
/// so manual and device writes upsert idempotently instead of creating
/// duplicate rows when the same occurrence is recorded twice.
class SessionAttendanceRecord {
  final String? id;
  final String schoolId;
  final String sessionId;

  /// `YYYY-MM-DD` of the occurrence this record belongs to.
  final String dateKey;

  final String personId;

  /// `student` | `teacher` | `admin` | `staff` | `worker`.
  final String personKind;
  final String personName;

  /// Role grouping key (built-in role key or a custom role name), mirrored
  /// from the resolved roster so reports can group without re-resolving.
  final String? roleKey;

  final AttendanceStatus status;

  /// `manual` | `device` (see [AttendanceSource]).
  final String source;

  /// Recorded check-in time as `HH:mm`, when known (device scans, or a
  /// manual entry that captured a time).
  final String? checkInTime;

  /// Identifier (uid/email/name) of the user who recorded a manual mark.
  final String? markedBy;
  final DateTime? markedAt;

  const SessionAttendanceRecord({
    this.id,
    required this.schoolId,
    required this.sessionId,
    required this.dateKey,
    required this.personId,
    required this.personKind,
    required this.personName,
    this.roleKey,
    required this.status,
    this.source = AttendanceSource.manual,
    this.checkInTime,
    this.markedBy,
    this.markedAt,
  });

  /// Deterministic Firestore doc id so (session, day, person) upserts
  /// idempotently regardless of which side authored the write.
  static String makeDocId({
    required String sessionId,
    required String dateKey,
    required String personKind,
    required String personId,
  }) => '${sessionId}__${dateKey}__${personKind}__$personId';

  /// Stable in-memory key matching `SessionAttendee.compoundKey` so the
  /// take-attendance UI can join records to roster rows.
  String get personKey => '$personKind:$personId';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static AttendanceStatus _parseStatus(dynamic v) {
    final s = (v ?? '').toString();
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AttendanceStatus.unknown,
    );
  }

  factory SessionAttendanceRecord.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return SessionAttendanceRecord(
      id: id,
      schoolId: (data['orgId'] ?? data['schoolId'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
      dateKey: (data['dateKey'] ?? '').toString(),
      personId: (data['personId'] ?? '').toString(),
      personKind: (data['personKind'] ?? 'student').toString(),
      personName: (data['personName'] ?? '').toString(),
      roleKey: data['roleKey']?.toString(),
      status: _parseStatus(data['status']),
      source: (data['source'] ?? AttendanceSource.manual).toString(),
      checkInTime: data['checkInTime']?.toString(),
      markedBy: data['markedBy']?.toString(),
      markedAt: _parseDate(data['markedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orgId': schoolId,
      'sessionId': sessionId,
      'dateKey': dateKey,
      'personId': personId,
      'personKind': personKind,
      'personName': personName,
      if (roleKey != null && roleKey!.isNotEmpty) 'roleKey': roleKey,
      'status': status.name,
      'source': source,
      if (checkInTime != null && checkInTime!.isNotEmpty)
        'checkInTime': checkInTime,
      if (markedBy != null && markedBy!.isNotEmpty) 'markedBy': markedBy,
      'markedAt': FieldValue.serverTimestamp(),
    };
  }

  SessionAttendanceRecord copyWith({
    String? id,
    String? schoolId,
    String? sessionId,
    String? dateKey,
    String? personId,
    String? personKind,
    String? personName,
    String? roleKey,
    AttendanceStatus? status,
    String? source,
    String? checkInTime,
    String? markedBy,
    DateTime? markedAt,
  }) {
    return SessionAttendanceRecord(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      sessionId: sessionId ?? this.sessionId,
      dateKey: dateKey ?? this.dateKey,
      personId: personId ?? this.personId,
      personKind: personKind ?? this.personKind,
      personName: personName ?? this.personName,
      roleKey: roleKey ?? this.roleKey,
      status: status ?? this.status,
      source: source ?? this.source,
      checkInTime: checkInTime ?? this.checkInTime,
      markedBy: markedBy ?? this.markedBy,
      markedAt: markedAt ?? this.markedAt,
    );
  }
}
