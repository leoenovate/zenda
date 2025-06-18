/// Status of attendance for a worker/student
enum AttendanceStatus { 
  present, 
  late, 
  absent,
  unknown
}

/// Represents a single attendance record for a worker/student
class Attendance {
  /// Date of the attendance record
  final DateTime date;
  
  /// Status of the attendance (present, late, absent)
  final AttendanceStatus status;

  /// Creates a new attendance record
  Attendance({
    required this.date, 
    required this.status
  });
  
  /// Creates an attendance record from JSON data
  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      date: DateTime.parse(json['date']),
      status: AttendanceStatus.values.byName(json['status']),
    );
  }
  
  /// Converts the attendance record to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'status': status.name,
    };
  }
} 