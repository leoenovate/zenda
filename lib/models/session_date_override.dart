import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-day customization for a multi-day or recurring [Session]:
///
/// * [excluded] - if true, the session does NOT happen on [date]
///   (e.g. holiday, day off). When excluded, the time fields are
///   ignored.
/// * [startTime] / [endTime] / [lateTime] - optional `HH:mm` overrides
///   that replace the session-level defaults for [date] only. A null
///   field means "use the session default".
///
/// Stored as an array on the session document keyed by [dateKey]
/// (`YYYY-MM-DD`) so legacy clients ignore the field gracefully.
class SessionDateOverride {
  final DateTime date;
  final bool excluded;
  final String? startTime;
  final String? endTime;
  final String? lateTime;

  const SessionDateOverride({
    required this.date,
    this.excluded = false,
    this.startTime,
    this.endTime,
    this.lateTime,
  });

  /// `YYYY-MM-DD` cache key used for fast lookups in the form dialog
  /// and as the de-duplication key when serializing.
  String get dateKey => formatDateKey(date);

  static String formatDateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// True when this override actually changes anything; an "empty"
  /// override (no skip, no time overrides) is treated as "use defaults"
  /// and dropped on save.
  bool get hasCustomization =>
      excluded ||
      (startTime != null && startTime!.isNotEmpty) ||
      (endTime != null && endTime!.isNotEmpty) ||
      (lateTime != null && lateTime!.isNotEmpty);

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _optionalString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return v.toString();
  }

  factory SessionDateOverride.fromMap(Map<String, dynamic> data) {
    final parsed = _parseDate(data['date']);
    final fallback = DateTime.fromMillisecondsSinceEpoch(0);
    final d = parsed ?? fallback;
    return SessionDateOverride(
      date: DateTime(d.year, d.month, d.day),
      excluded: data['excluded'] == true,
      startTime: _optionalString(data['startTime']),
      endTime: _optionalString(data['endTime']),
      lateTime: _optionalString(data['lateTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'dateKey': dateKey,
      if (excluded) 'excluded': true,
      if (startTime != null && startTime!.isNotEmpty) 'startTime': startTime,
      if (endTime != null && endTime!.isNotEmpty) 'endTime': endTime,
      if (lateTime != null && lateTime!.isNotEmpty) 'lateTime': lateTime,
    };
  }

  SessionDateOverride copyWith({
    DateTime? date,
    bool? excluded,
    String? startTime,
    String? endTime,
    String? lateTime,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearLateTime = false,
  }) {
    return SessionDateOverride(
      date: date ?? this.date,
      excluded: excluded ?? this.excluded,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      lateTime: clearLateTime ? null : (lateTime ?? this.lateTime),
    );
  }
}
