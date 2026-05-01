import '../models/device.dart';
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

/// In-memory index of every fingerprint slot across the current school's
/// devices, keyed by the normalized `cardId` field on each
/// `device_enrollments/{deviceId}_{slotId}` Firestore document.
///
/// Built by [fetch], which performs a single school-scoped Firestore
/// query (no per-device HTTP fanout). The api-v2 server's
/// `/api/users/:deviceId` endpoint is not consulted here because that
/// snapshot can collapse around whatever the device firmware most
/// recently echoed back via `/status`, which would silently hide
/// enrollments that are still real.
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
  /// candidate found in [candidates]. Comparison is case-insensitive and
  /// ignores surrounding whitespace.
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

  /// Loads every persisted enrollment for the current school and
  /// returns a populated lookup. Devices passed in [devices] are used
  /// only to resolve a friendly label per `deviceId`; missing labels
  /// fall back to the raw deviceId from the Firestore document.
  static Future<DeviceEnrollmentLookup> fetch(Iterable<Device> devices) async {
    try {
      final enrollments = await FirebaseService.getDeviceEnrollments();
      if (enrollments.isEmpty) return const DeviceEnrollmentLookup.empty();

      final labels = <String, String>{};
      for (final d in devices) {
        if (d.deviceId.trim().isEmpty) continue;
        final raw = (d.deviceName ?? '').trim();
        labels[d.deviceId] = raw.isEmpty ? d.deviceId : raw;
      }

      final byCardId = <String, List<DeviceEnrollmentInfo>>{};
      for (final e in enrollments) {
        final key = _normalize(e.cardId);
        if (key.isEmpty) continue;
        final label = labels[e.deviceId] ?? e.deviceId;
        (byCardId[key] ??= <DeviceEnrollmentInfo>[]).add(
          DeviceEnrollmentInfo(
            deviceId: e.deviceId,
            deviceLabel: label,
            slotId: e.slotId,
          ),
        );
      }
      return DeviceEnrollmentLookup._(byCardId);
    } catch (_) {
      return const DeviceEnrollmentLookup.empty();
    }
  }
}
