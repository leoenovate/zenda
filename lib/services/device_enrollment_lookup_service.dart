import '../models/device.dart';
import '../models/device_enrollment.dart';
import 'firebase_service.dart';

/// One slot on one device that holds a particular cardId.
class DeviceEnrollmentInfo {
  final String deviceId;
  final String deviceLabel;
  final int slotId;

  const DeviceEnrollmentInfo({
    required this.deviceId,
    required this.deviceLabel,
    required this.slotId,
  });
}

/// In-memory index of every fingerprint slot across the current
/// school's devices, keyed by the normalized `cardId` programmed in
/// each slot.
///
/// Built by [fetch], which reads the `device_enrollments` Firestore
/// collection (school-scoped via `FirebaseService._scoped`) — a single
/// query that returns rows for every device, instead of an HTTP fan-out
/// across each device's API endpoint. The Flutter app writes to that
/// same collection on every successful enroll, so this lookup reflects
/// the live state without depending on the api-v2 server's MQTT-driven
/// SQLite mirror (which can stall on Render's free tier).
///
/// Consumers (admin list screens) compare a person's cardId candidates
/// (`employeeId`, then the document `id`) — the same fallback used by
/// the `_EnrollmentParticipant` selector in
/// `device_enrollments_screen.dart` — to decide whether to render an
/// "ENROLLED" badge.
class DeviceEnrollmentLookup {
  final Map<String, List<DeviceEnrollmentInfo>> _byCardId;

  const DeviceEnrollmentLookup._(this._byCardId);

  const DeviceEnrollmentLookup.empty() : _byCardId = const {};

  bool get isEmpty => _byCardId.isEmpty;

  /// Returns matching enrollments for the first non-empty cardId
  /// candidate found in [candidates]. Comparison is case-insensitive
  /// and ignores surrounding whitespace.
  List<DeviceEnrollmentInfo> findEnrollments(Iterable<String?> candidates) {
    for (final raw in candidates) {
      final key = _normalize(raw);
      if (key.isEmpty) continue;
      final hits = _byCardId[key];
      if (hits != null && hits.isNotEmpty) return hits;
    }
    return const [];
  }

  bool isEnrolled(Iterable<String?> candidates) =>
      findEnrollments(candidates).isNotEmpty;

  static String _normalize(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// Reads `device_enrollments` from Firestore (school-scoped) and
  /// indexes every row by normalized `cardId`. The [devices] list is
  /// only used to resolve human-readable labels for tooltips — we
  /// already query Firestore once for the entire school, so passing a
  /// subset of devices won't change which enrollments are returned.
  static Future<DeviceEnrollmentLookup> fetch(Iterable<Device> devices) async {
    final List<DeviceEnrollment> enrollments;
    try {
      enrollments = await FirebaseService.getDeviceEnrollments();
    } catch (_) {
      return const DeviceEnrollmentLookup.empty();
    }
    if (enrollments.isEmpty) return const DeviceEnrollmentLookup.empty();

    final labelByDeviceId = <String, String>{};
    for (final device in devices) {
      final id = device.deviceId;
      if (id.isEmpty) continue;
      final rawName = (device.deviceName ?? '').trim();
      labelByDeviceId[id] = rawName.isEmpty ? id : rawName;
    }

    final byCardId = <String, List<DeviceEnrollmentInfo>>{};
    for (final enrollment in enrollments) {
      final key = _normalize(enrollment.cardId);
      if (key.isEmpty) continue;
      final label = labelByDeviceId[enrollment.deviceId] ?? enrollment.deviceId;
      (byCardId[key] ??= <DeviceEnrollmentInfo>[]).add(
        DeviceEnrollmentInfo(
          deviceId: enrollment.deviceId,
          deviceLabel: label,
          slotId: enrollment.slotId,
        ),
      );
    }
    return DeviceEnrollmentLookup._(byCardId);
  }
}
