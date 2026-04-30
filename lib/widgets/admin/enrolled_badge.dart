import 'package:flutter/material.dart';

import '../../services/device_enrollment_lookup_service.dart';

/// Compact pill rendered next to an employee row when the school's
/// fingerprint device(s) have at least one slot programmed with that
/// person's card. Hover/long-press reveals every device + slot the person
/// is enrolled on.
///
/// The data is supplied by [DeviceEnrollmentLookup]; if [enrollments] is
/// empty the widget renders nothing so callers can pass it
/// unconditionally.
class EnrolledBadge extends StatelessWidget {
  final List<DeviceEnrollmentInfo> enrollments;

  const EnrolledBadge({super.key, required this.enrollments});

  @override
  Widget build(BuildContext context) {
    if (enrollments.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    final tooltip = enrollments
        .map((e) => '${e.deviceLabel} · slot ${e.slotId}')
        .join('\n');

    return Tooltip(
      message: 'Enrolled on:\n$tooltip',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fingerprint,
              size: 12,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'ENROLLED',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
