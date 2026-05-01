import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';

class DeviceHeartbeat {
  final String deviceId;
  final bool? isOnline;
  final String? ip;
  final DateTime? lastSeen;
  final String status;
  final int? rssi;
  final String source;

  const DeviceHeartbeat({
    required this.deviceId,
    this.isOnline,
    this.ip,
    this.lastSeen,
    required this.status,
    this.rssi,
    required this.source,
  });

  factory DeviceHeartbeat.fromDevice(Device device) {
    return DeviceHeartbeat(
      deviceId: device.deviceId,
      isOnline: device.isOnline,
      ip: device.ip,
      lastSeen: device.lastSeen,
      status: device.status ?? 'offline',
      rssi: device.rssi,
      source: 'devices',
    );
  }

  factory DeviceHeartbeat.fromApi(Map<String, dynamic> data) {
    return DeviceHeartbeat(
      deviceId: (data['deviceId'] ?? data['device_id'] ?? '').toString(),
      isOnline: true,
      ip: data['ip']?.toString(),
      lastSeen: _parseDate(data['lastSeen'] ?? data['last_seen']),
      status: (data['status'] ?? 'online').toString(),
      rssi: _parseInt(data['rssi']),
      source: 'api',
    );
  }

  bool get hasSignal => lastSeen != null || isOnline != null;

  bool isFresh({DateTime? now}) {
    final seen = lastSeen;
    if (seen == null) return false;
    final age = (now ?? DateTime.now()).difference(seen.toLocal());
    return !age.isNegative && age <= DeviceHeartbeatService.freshnessWindow;
  }

  bool isOnlineNow({DateTime? now}) {
    if (isOnline == false) return false;
    return isFresh(now: now);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }
}

class DeviceHeartbeatService {
  static const String baseUrl = 'https://zenda.spura.app';
  static const Duration freshnessWindow = Duration(seconds: 35);
  static const Duration requestTimeout = Duration(seconds: 8);

  static Future<Map<String, DeviceHeartbeat>> fetchHeartbeats(
    List<Device> devices,
  ) async {
    final heartbeats = <String, DeviceHeartbeat>{};
    final deviceIds =
        devices.map((d) => d.deviceId).where((id) => id.isNotEmpty).toSet();

    for (final device in devices) {
      final heartbeat = DeviceHeartbeat.fromDevice(device);
      if (heartbeat.hasSignal) {
        heartbeats[device.deviceId] = heartbeat;
      }
    }

    final response = await http
        .get(Uri.parse('$baseUrl/api/devices'))
        .timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Heartbeat API returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Heartbeat API returned an invalid payload');
    }

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final heartbeat = DeviceHeartbeat.fromApi(item);
      if (heartbeat.deviceId.isEmpty) continue;
      if (!deviceIds.contains(heartbeat.deviceId)) continue;
      heartbeats[heartbeat.deviceId] = heartbeat;
    }

    return heartbeats;
  }
}
