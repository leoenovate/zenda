import 'package:cloud_firestore/cloud_firestore.dart';

/// Planned absence for school staff: [assigneeKind] identifies whether the
/// person is a `worker`, `teacher`, or `admin` (school admin account).
///
/// Stored in `worker_time_off` for historical reasons; documents include
/// `assigneeKind` / `assigneeId` / `assigneeName`, with legacy `workerId` /
/// `workerName` mirrored when [assigneeKind] is `worker`.
///
/// Supporting **images** may be stored as Base64 in [attachmentBase64]
/// (Firestore document size limit 1 MiB — keep images small).
/// Older rows may still use [attachmentStoragePath] + [attachmentUrl].
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

  /// Inline image (Base64). Prefer this for new records.
  final String? attachmentBase64;
  final String? attachmentContentType;

  /// Legacy: Firebase Storage (read-only for old data).
  final String? attachmentStoragePath;
  final String? attachmentUrl;
  final String? attachmentFileName;

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
    this.attachmentBase64,
    this.attachmentContentType,
    this.attachmentStoragePath,
    this.attachmentUrl,
    this.attachmentFileName,
  });

  bool get hasBase64Attachment =>
      attachmentBase64 != null && attachmentBase64!.trim().isNotEmpty;

  bool get hasLegacyStorageAttachment =>
      attachmentStoragePath != null &&
      attachmentStoragePath!.isNotEmpty &&
      attachmentUrl != null &&
      attachmentUrl!.isNotEmpty;

  bool get hasAttachment => hasBase64Attachment || hasLegacyStorageAttachment;

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
    final aid = (data['memberId'] as String?)?.trim().isNotEmpty == true
        ? data['memberId'] as String
        : (data['assigneeId'] as String?)?.trim().isNotEmpty == true
            ? data['assigneeId'] as String
            : (data['workerId'] as String? ?? '');
    final aname = (data['memberName'] as String?)?.trim().isNotEmpty == true
        ? data['memberName'] as String
        : (data['assigneeName'] as String?)?.trim().isNotEmpty == true
            ? data['assigneeName'] as String
            : (data['workerName'] as String? ?? '');

    return StaffTimeOff(
      id: id,
      schoolId: (data['orgId'] ?? data['schoolId'] ?? '') as String,
      assigneeKind: kind,
      assigneeId: aid,
      assigneeName: aname,
      startDate: _dateOnlyFrom(data['startDate']),
      endDate: _dateOnlyFrom(data['endDate']),
      type: data['type'] ?? 'other',
      notes: data['notes'] as String?,
      status: data['status'] ?? 'approved',
      createdAt: _parseDate(data['createdAt']),
      attachmentBase64: data['attachmentBase64'] as String?,
      attachmentContentType: data['attachmentContentType'] as String?,
      attachmentStoragePath: data['attachmentStoragePath'] as String?,
      attachmentUrl: data['attachmentUrl'] as String?,
      attachmentFileName: data['attachmentFileName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'orgId': schoolId,
      'assigneeKind': assigneeKind,
      'memberId': assigneeId,
      'memberName': assigneeName,
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
    if (hasBase64Attachment) {
      m['attachmentBase64'] = attachmentBase64;
      m['attachmentContentType'] =
          (attachmentContentType != null &&
                  attachmentContentType!.trim().isNotEmpty)
              ? attachmentContentType!.trim()
              : 'image/jpeg';
      if (attachmentFileName != null &&
          attachmentFileName!.trim().isNotEmpty) {
        m['attachmentFileName'] = attachmentFileName!.trim();
      }
    } else if (hasLegacyStorageAttachment) {
      m['attachmentStoragePath'] = attachmentStoragePath;
      m['attachmentUrl'] = attachmentUrl;
      if (attachmentFileName != null &&
          attachmentFileName!.trim().isNotEmpty) {
        m['attachmentFileName'] = attachmentFileName!.trim();
      }
    }
    return m;
  }
}
