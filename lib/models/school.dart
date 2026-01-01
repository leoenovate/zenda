import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  final String? id;
  final String name;
  final String? code;
  final String? tagline;
  final String? description;
  final String? address;
  final String? city;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final bool isActive;
  final DateTime? createdAt;
  
  // Attendance settings
  final String? morningStart;
  final String? morningEnd;
  final String? morningLateTime;
  final String? afternoonStart;
  final String? afternoonEnd;
  final String? afternoonLateTime;

  const School({
    this.id,
    required this.name,
    this.code,
    this.tagline,
    this.description,
    this.address,
    this.city,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.isActive = true,
    this.createdAt,
    this.morningStart,
    this.morningEnd,
    this.morningLateTime,
    this.afternoonStart,
    this.afternoonEnd,
    this.afternoonLateTime,
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

  factory School.fromFirestore(Map<String, dynamic> data, String id) {
    // Handle nested address structure
    String? address;
    String? city;
    String? country;
    
    if (data['address'] is Map) {
      final addrMap = data['address'] as Map<String, dynamic>;
      address = addrMap['address'] ?? addrMap['sector'] ?? addrMap['cell'];
      city = addrMap['city'] ?? addrMap['district'] ?? addrMap['province'];
      country = addrMap['country'];
    } else if (data['address'] is String) {
      address = data['address'];
    }
    
    // Handle nested contact structure
    String? phone;
    String? email;
    if (data['contact'] is Map) {
      final contactMap = data['contact'] as Map<String, dynamic>;
      phone = contactMap['phone'] ?? data['phone'];
      email = contactMap['email'] ?? data['email'];
    } else {
      phone = data['phone'];
      email = data['email'];
    }
    
    // Handle attendance settings
    Map<String, dynamic>? attendanceSettings;
    if (data['attendanceSettings'] is Map) {
      attendanceSettings = data['attendanceSettings'] as Map<String, dynamic>;
    }
    
    return School(
      id: id,
      name: data['name'] ?? '',
      code: data['code'],
      tagline: data['tagline'],
      description: data['description'],
      address: address ?? data['address'],
      city: city ?? data['city'],
      country: country ?? data['country'],
      phone: phone,
      email: email,
      website: data['website'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      morningStart: attendanceSettings?['morningStart'] ?? data['morningStart'],
      morningEnd: attendanceSettings?['morningEnd'] ?? data['morningEnd'],
      morningLateTime: attendanceSettings?['morningLateTime'] ?? data['morningLateTime'],
      afternoonStart: attendanceSettings?['afternoonStart'] ?? data['afternoonStart'],
      afternoonEnd: attendanceSettings?['afternoonEnd'] ?? data['afternoonEnd'],
      afternoonLateTime: attendanceSettings?['afternoonLateTime'] ?? data['afternoonLateTime'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (code != null) 'code': code,
      if (tagline != null) 'tagline': tagline,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (website != null) 'website': website,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (morningStart != null || morningEnd != null || morningLateTime != null ||
          afternoonStart != null || afternoonEnd != null || afternoonLateTime != null)
        'attendanceSettings': {
          if (morningStart != null) 'morningStart': morningStart,
          if (morningEnd != null) 'morningEnd': morningEnd,
          if (morningLateTime != null) 'morningLateTime': morningLateTime,
          if (afternoonStart != null) 'afternoonStart': afternoonStart,
          if (afternoonEnd != null) 'afternoonEnd': afternoonEnd,
          if (afternoonLateTime != null) 'afternoonLateTime': afternoonLateTime,
        },
    };
  }
}

