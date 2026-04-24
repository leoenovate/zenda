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
}
