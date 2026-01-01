import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String? id;
  final String email;
  final String? name;
  final String? role; // "admin" | "teacher" | "system_owner" | "staff"
  final String? schoolId;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const AppUser({
    this.id,
    required this.email,
    this.name,
    this.role,
    this.schoolId,
    this.phone,
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
  });

  // Helper function to parse date from Firestore (handles both Timestamp and ISO string)
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('Error parsing date string: $dateValue - $e');
        return null;
      }
    } else if (dateValue is DateTime) {
      return dateValue;
    }
    
    return null;
  }

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      name: data['name'],
      role: data['role'],
      schoolId: data['schoolId'],
      phone: data['phone'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      lastLogin: _parseDate(data['lastLogin']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (schoolId != null) 'schoolId': schoolId,
      if (phone != null) 'phone': phone,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastLogin != null) 'lastLogin': lastLogin,
    };
  }
}

