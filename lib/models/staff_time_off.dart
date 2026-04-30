import 'package:cloud_firestore/cloud_firestore.dart';

/// Planned absence for school staff: [assigneeKind] identifies whether the
/// person is a `worker`, `teacher`, or `admin` (school admin account).
///
/// Stored in `worker_time_off` for historical reasons; documents include
/// `assigneeKind` / `assigneeId` / `assigneeName`, with legacy `workerId` /
/// `workerName` mirrored when [assigneeKind] is `worker`.
class StaffTimeOff {
  final String? id;
  final String schoolId;
  final String assigneeKind;
  final String assigneeId;
  final String assigneeName;
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final String? notes;
  final String status;
  final DateTime? createdAt;

  const StaffTimeOff({
    this.id,
    required this.schoolId,
    required this.assigneeKind,
    required this.assigneeId,
    required this.assigneeName,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.notes,
    this.status = 'approved',
    this.createdAt,
  });

  static DateTime _dateOnlyFrom(dynamic v) {
    final d = _parseDate(v);
    if (d == null) return DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

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

  factory StaffTimeOff.fromFirestore(Map<String, dynamic> data, String id) {
    final kind = (data['assigneeKind'] as String?)?.trim().isNotEmpty == true
        ? data['assigneeKind'] as String
        : 'worker';
    final aid = (data['assigneeId'] as String?)?.trim().isNotEmpty == true
        ? data['assigneeId'] as String
        : (data['workerId'] as String? ?? '');
    final aname = (data['assigneeName'] as String?)?.trim().isNotEmpty == true
        ? data['assigneeName'] as String
        : (data['workerName'] as String? ?? '');

    return StaffTimeOff(
      id: id,
      schoolId: data['schoolId'] ?? '',
      assigneeKind: kind,
      assigneeId: aid,
      assigneeName: aname,
      startDate: _dateOnlyFrom(data['startDate']),
      endDate: _dateOnlyFrom(data['endDate']),
      type: data['type'] ?? 'other',
      notes: data['notes'] as String?,
      status: data['status'] ?? 'approved',
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'schoolId': schoolId,
      'assigneeKind': assigneeKind,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'startDate': Timestamp.fromDate(
        DateTime(startDate.year, startDate.month, startDate.day),
      ),
      'endDate': Timestamp.fromDate(
        DateTime(endDate.year, endDate.month, endDate.day),
      ),
      'type': type,
      'status': status,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
    if (assigneeKind == 'worker') {
      m['workerId'] = assigneeId;
      m['workerName'] = assigneeName;
    }
    return m;
  }
}
