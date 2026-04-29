import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device_enrolled_user.dart';
import 'device_heartbeat_service.dart';

/// HTTP client for the zenda-api-v2 device control endpoints
/// (`/api/users/:deviceId`, `/api/command/*`, `/api/enrollment/status/...`).
///
/// Reuses [DeviceHeartbeatService.baseUrl] so heartbeat polling and enrollment
/// stay aimed at the same host.
class ZendaDeviceApiService {
  static String get baseUrl => DeviceHeartbeatService.baseUrl;
  static const Duration requestTimeout = Duration(seconds: 8);

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  static Future<List<DeviceEnrolledUser>> getUsersForDevice(
    String deviceId,
  ) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/users/$deviceId'))
        .timeout(requestTimeout);
    _ensureOk(response, 'load enrolled users');

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Users API returned an invalid payload');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DeviceEnrolledUser.fromJson)
        .toList(growable: false);
  }

  static Future<EnrollmentCommandResult> postEnroll({
    required String deviceId,
    required int id,
    required String cardId,
    required String name,
    String? phone,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/command/enroll'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'deviceId': deviceId,
            'id': id,
            'cardId': cardId,
            'name': name,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          }),
        )
        .timeout(requestTimeout);
    _ensureOk(response, 'send enroll command');
    return EnrollmentCommandResult.fromJson(_decodeMap(response.body));
  }

  static Future<void> postDelete({
    required String deviceId,
    required int id,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/command/delete'),
          headers: _jsonHeaders,
          body: jsonEncode({'deviceId': deviceId, 'id': id}),
        )
        .timeout(requestTimeout);
    _ensureOk(response, 'send delete command');
  }

  static Future<void> postClear({required String deviceId}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/command/clear'),
          headers: _jsonHeaders,
          body: jsonEncode({'deviceId': deviceId}),
        )
        .timeout(requestTimeout);
    _ensureOk(response, 'send clear command');
  }

  static Future<void> postGetStatus({required String deviceId}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/command/getstatus'),
          headers: _jsonHeaders,
          body: jsonEncode({'deviceId': deviceId}),
        )
        .timeout(requestTimeout);
    _ensureOk(response, 'request device status');
  }

  static Future<EnrollmentStatus> getEnrollmentStatus({
    required String deviceId,
    required int enrollmentId,
  }) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/enrollment/status/$deviceId/$enrollmentId'),
        )
        .timeout(requestTimeout);
    _ensureOk(response, 'check enrollment status');
    return EnrollmentStatus.fromJson(_decodeMap(response.body));
  }

  static void _ensureOk(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        detail = decoded['error'].toString();
      }
    } catch (_) {}
    throw Exception('Failed to $action (${response.statusCode}): $detail');
  }

  static Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object, got: $body');
    }
    return decoded;
  }
}

class EnrollmentCommandResult {
  final bool success;
  final String? message;
  final String? enrollmentKey;

  const EnrollmentCommandResult({
    required this.success,
    this.message,
    this.enrollmentKey,
  });

  factory EnrollmentCommandResult.fromJson(Map<String, dynamic> data) {
    return EnrollmentCommandResult(
      success: data['success'] == true,
      message: data['message']?.toString(),
      enrollmentKey: data['enrollmentKey']?.toString(),
    );
  }
}

class EnrollmentStatus {
  final bool found;
  final String status;
  final bool success;
  final int? step;
  final String? message;

  const EnrollmentStatus({
    required this.found,
    required this.status,
    required this.success,
    this.step,
    this.message,
  });

  factory EnrollmentStatus.fromJson(Map<String, dynamic> data) {
    return EnrollmentStatus(
      found: data['found'] == true,
      status: (data['status'] ?? 'unknown').toString(),
      success: data['success'] == true,
      step: data['step'] is int
          ? data['step'] as int
          : int.tryParse(data['step']?.toString() ?? ''),
      message: data['message']?.toString(),
    );
  }
}
