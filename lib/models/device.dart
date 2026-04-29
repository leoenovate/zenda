import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String? id;
  final String deviceId;
  final String? deviceName;
  final String? deviceType;
  final String? schoolId;
  final bool isActive;
  final DateTime? lastSeen;
  final bool? isOnline;
  final String? ip;
  final int? rssi;
  final String? location;
  final String? status; // "active" | "offline" | "maintenance"

  const Device({
    this.id,
    required this.deviceId,
    this.deviceName,
    this.deviceType,
    this.schoolId,
    this.isActive = true,
    this.lastSeen,
    this.isOnline,
    this.ip,
    this.rssi,
    this.location,
    this.status,
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

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  factory Device.fromFirestore(Map<String, dynamic> data, String id) {
    return Device(
      id: id,
      deviceId: data['deviceId'] ?? '',
      deviceName: data['deviceName'],
      deviceType: data['deviceType'] ?? 'fingerprint_scanner',
      schoolId: data['schoolId'],
      isActive: data['isActive'] ?? true,
      lastSeen: _parseDate(data['lastSeen']),
      isOnline: data['isOnline'],
      ip: data['ip']?.toString(),
      rssi: _parseInt(data['rssi']),
      location: data['location'],
      status: data['status'] ?? 'offline',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      if (deviceName != null) 'deviceName': deviceName,
      if (deviceType != null) 'deviceType': deviceType,
      if (schoolId != null) 'schoolId': schoolId,
      'isActive': isActive,
      if (lastSeen != null) 'lastSeen': lastSeen,
      if (isOnline != null) 'isOnline': isOnline,
      if (ip != null) 'ip': ip,
      if (rssi != null) 'rssi': rssi,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
    };
  }
}
