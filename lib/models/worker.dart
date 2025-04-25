import 'package:flutter/material.dart';

class Attendance {
  final DateTime date;
  final AttendanceStatus status;

  const Attendance({
    required this.date,
    required this.status,
  });
}

enum AttendanceStatus {
  present,
  late,
  absent,
}

class Worker {
  final String? id;
  final String name;
  final String period;
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

  const Worker({
    this.id,
    required this.name,
    required this.period,
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
  });

  // Helper method to validate period
  static bool isValidPeriod(String period) {
    return ['Morning', 'Afternoon'].contains(period);
  }

  // Helper method to get short form of period
  static String getShortPeriod(String period) {
    return period;
  }
} 