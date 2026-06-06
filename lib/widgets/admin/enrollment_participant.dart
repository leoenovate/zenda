import 'package:flutter/material.dart';

import '../../models/device_enrollment.dart';
import '../../models/teacher.dart';
import '../../models/user.dart' as app_user;
import '../../models/worker.dart';
import '../../services/role_constants.dart';
import '../../services/firebase_service.dart';
import '../../services/zenda_device_api_service.dart';

/// A teacher or worker selected for fingerprint device enrollment.
class EnrollmentParticipant {
  final String key;
  final String name;
  final String cardId;
  final String phone;
  final String subtitle;
  final IconData icon;
  final String kind;

  const EnrollmentParticipant({
    required this.key,
    required this.name,
    required this.cardId,
    required this.phone,
    required this.subtitle,
    required this.icon,
    required this.kind,
  });

  factory EnrollmentParticipant.fromTeacher(Teacher teacher) {
    final cardId = _firstNonEmpty([teacher.employeeId, teacher.id]);
    final detail = _joinNonEmpty(['Teacher', teacher.subject, teacher.phone]);
    return EnrollmentParticipant(
      key: 'teacher-${teacher.id ?? teacher.employeeId ?? teacher.name}',
      name: teacher.name,
      cardId: cardId,
      phone: teacher.phone ?? '',
      subtitle: detail,
      icon: Icons.school_outlined,
      kind: 'teacher',
    );
  }

  factory EnrollmentParticipant.fromWorker(Worker worker) {
    final cardId = _firstNonEmpty([worker.employeeId, worker.id]);
    final detail = _joinNonEmpty(['Worker', worker.role, worker.phone]);
    return EnrollmentParticipant(
      key: 'worker-${worker.id ?? worker.employeeId ?? worker.name}',
      name: worker.name,
      cardId: cardId,
      phone: worker.phone ?? '',
      subtitle: detail,
      icon: Icons.engineering_outlined,
      kind: 'worker',
    );
  }

  factory EnrollmentParticipant.fromAdminUser(app_user.AppUser user) {
    final kind = AuthRoles.kindForUserRole(user.role) ?? AuthRoles.kindAdmin;
    final cardId = _firstNonEmpty([user.id]);
    final kindLabel =
        kind == AuthRoles.kindStaff ? 'Staff' : 'Administrator';
    final detail = _joinNonEmpty([kindLabel, user.email, user.phone]);
    return EnrollmentParticipant(
      key: '$kind-${user.id ?? user.email}',
      name:
          (user.name != null && user.name!.trim().isNotEmpty)
              ? user.name!.trim()
              : user.email,
      cardId: cardId,
      phone: user.phone ?? '',
      subtitle: detail,
      icon:
          kind == AuthRoles.kindStaff
              ? Icons.badge_outlined
              : Icons.admin_panel_settings_outlined,
      kind: kind,
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _joinNonEmpty(List<String?> values) {
    return values
        .map((v) => v?.trim() ?? '')
        .where((v) => v.isNotEmpty)
        .join(' · ');
  }
}

/// Shared MQTT enroll + Firestore persist flow used by device-first and
/// person-first enrollment dialogs.
class DeviceEnrollmentFlow {
  DeviceEnrollmentFlow._();

  static const int defaultMaxSlot = 200;

  static int? firstFreeSlot(Set<int> usedSlots, {int maxSlot = defaultMaxSlot}) {
    for (var i = 1; i <= maxSlot; i++) {
      if (!usedSlots.contains(i)) return i;
    }
    return null;
  }

  static String formatEnrollmentStatus(EnrollmentStatus status) {
    if (status.success) return 'Enrollment confirmed.';
    final message = (status.message ?? '').trim();
    if (message.isNotEmpty) return message;
    final step = status.step;
    if (step == null) return 'Waiting for the second fingerprint scan...';
    if (step <= 1) {
      return 'First scan received. Place the same finger again to finish enrollment.';
    }
    return 'Waiting for device confirmation (step $step)...';
  }

  static Future<bool> pollEnrollmentStatus({
    required String deviceId,
    required int slot,
    void Function(String message)? onStatus,
    bool Function()? isMounted,
  }) async {
    const maxAttempts = 90;
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (isMounted != null && !isMounted()) return false;
      try {
        final status = await ZendaDeviceApiService.getEnrollmentStatus(
          deviceId: deviceId,
          enrollmentId: slot,
        );
        if (isMounted != null && !isMounted()) return false;
        if (status.found) {
          onStatus?.call(formatEnrollmentStatus(status));
          if (status.success) return true;
        } else if (i == 10) {
          onStatus?.call(
            'Waiting for the device. Place the same finger twice when prompted.',
          );
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<DeviceEnrollment?> submitEnrollment({
    required String deviceId,
    required String schoolId,
    required int slot,
    required EnrollmentParticipant participant,
    void Function(String message)? onStatus,
    bool Function()? isMounted,
  }) async {
    onStatus?.call('Sending enroll command...');
    await ZendaDeviceApiService.postEnroll(
      deviceId: deviceId,
      id: slot,
      cardId: participant.cardId,
      name: participant.name,
      phone: participant.phone.isEmpty ? null : participant.phone,
    );
    if (isMounted != null && !isMounted()) return null;
    onStatus?.call(
      'Command sent. Place the same finger on the device twice when prompted.',
    );
    final confirmed = await pollEnrollmentStatus(
      deviceId: deviceId,
      slot: slot,
      onStatus: onStatus,
      isMounted: isMounted,
    );
    if (isMounted != null && !isMounted()) return null;
    if (!confirmed) return null;

    final enrollment = DeviceEnrollment(
      deviceId: deviceId,
      schoolId: schoolId,
      slotId: slot,
      name: participant.name,
      cardId: participant.cardId,
      phone: participant.phone.isEmpty ? null : participant.phone,
      enrolledAt: DateTime.now(),
    );
    await FirebaseService.upsertDeviceEnrollment(enrollment);
    return enrollment;
  }
}
