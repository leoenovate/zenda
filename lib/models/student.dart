import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenda/models/attendance.dart';

class Student {
  final String? id;
  final String name;
  final List<String> sessionIds;
  final String? registrationNumber;
  final String? gender;
  final String? birthdate;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final String? country;
  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final List<Attendance> attendanceHistory;
  final String? fingerprintData;
  final String? fingerprintTimestamp;

  const Student({
    this.id,
    required this.name,
    this.sessionIds = const [],
    this.registrationNumber,
    this.gender,
    this.birthdate,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.country,
    this.province,
    this.district,
    this.sector,
    this.cell,
    required this.attendanceHistory,
    this.fingerprintData,
    this.fingerprintTimestamp,
  });

  static List<String> _parseSessionIds(Map<String, dynamic> data) {
    final raw = data['legacySessionIds'] ?? data['sessionIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static List<Attendance> _parseAttendanceHistory(Map<String, dynamic> data) {
    final raw = data['attendanceHistory'];
    if (raw is! List) return [];
    final out = <Attendance>[];
    for (final a in raw) {
      if (a is! Map) continue;
      try {
        final statusString = (a['status'] as String?) ?? 'present';
        final status = AttendanceStatus.values.firstWhere(
          (e) => e.name == statusString,
          orElse: () => AttendanceStatus.present,
        );
        final dateRaw = a['date'];
        final date = dateRaw is Timestamp
            ? dateRaw.toDate()
            : DateTime.parse(dateRaw.toString());
        out.add(Attendance(date: date, status: status));
      } catch (_) {
        // Skip unparseable rows rather than failing the whole student.
      }
    }
    return out;
  }

  factory Student.fromFirestore(Map<String, dynamic> data, String id) {
    return Student(
      id: id,
      name: data['name'] ?? '',
      sessionIds: _parseSessionIds(data),
      registrationNumber: data['registrationNumber'],
      gender: data['gender'],
      birthdate: data['birthdate'],
      fatherName: data['fatherName'] ?? data['guardianName'],
      fatherPhone: data['fatherPhone'] ?? data['guardianPhone'],
      motherName: data['motherName'] ?? data['guardianName2'],
      motherPhone: data['motherPhone'] ?? data['guardianPhone2'],
      country: data['country'],
      province: data['province'],
      district: data['district'],
      sector: data['sector'],
      cell: data['cell'],
      fingerprintData: data['fingerprintData'],
      fingerprintTimestamp: data['fingerprintTimestamp'],
      attendanceHistory: _parseAttendanceHistory(data),
    );
  }

  /// Serializes student-owned fields to the unified `members` schema
  /// (`kind:"student"`, guardian* contact keys). The caller is responsible
  /// for injecting `orgId` (the student model does not carry it).
  Map<String, dynamic> toFirestore() {
    return {
      'kind': 'student',
      'name': name,
      if (registrationNumber != null) 'registrationNumber': registrationNumber,
      if (gender != null) 'gender': gender,
      if (birthdate != null) 'birthdate': birthdate,
      if (fatherName != null) 'guardianName': fatherName,
      if (fatherPhone != null) 'guardianPhone': fatherPhone,
      if (motherName != null) 'guardianName2': motherName,
      if (motherPhone != null) 'guardianPhone2': motherPhone,
      if (country != null) 'country': country,
      if (province != null) 'province': province,
      if (district != null) 'district': district,
      if (sector != null) 'sector': sector,
      if (cell != null) 'cell': cell,
      if (sessionIds.isNotEmpty) 'legacySessionIds': sessionIds,
      if (fingerprintData != null) 'fingerprintData': fingerprintData,
      if (fingerprintTimestamp != null)
        'fingerprintTimestamp': fingerprintTimestamp,
      'attendanceHistory': attendanceHistory.map((a) => a.toJson()).toList(),
    };
  }

  Student copyWith({
    String? id,
    String? name,
    List<String>? sessionIds,
    String? registrationNumber,
    String? gender,
    String? birthdate,
    String? fatherName,
    String? fatherPhone,
    String? motherName,
    String? motherPhone,
    String? country,
    String? province,
    String? district,
    String? sector,
    String? cell,
    List<Attendance>? attendanceHistory,
    String? fingerprintData,
    String? fingerprintTimestamp,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      sessionIds: sessionIds ?? this.sessionIds,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      fatherName: fatherName ?? this.fatherName,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherPhone: motherPhone ?? this.motherPhone,
      country: country ?? this.country,
      province: province ?? this.province,
      district: district ?? this.district,
      sector: sector ?? this.sector,
      cell: cell ?? this.cell,
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      fingerprintData: fingerprintData ?? this.fingerprintData,
      fingerprintTimestamp: fingerprintTimestamp ?? this.fingerprintTimestamp,
    );
  }
}
