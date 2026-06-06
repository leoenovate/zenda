import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/device_enrollment.dart';
import 'enrollment_participant.dart';

/// Person-first enrollment: a teacher/worker is pre-selected and the admin
/// picks which device to enroll them on.
Future<DeviceEnrollment?> showPersonDeviceEnrollDialog({
  required BuildContext context,
  required EnrollmentParticipant participant,
  required List<Device> devices,
  required String schoolId,
  required Map<String, Set<int>> usedSlotsByDevice,
}) {
  return showDialog<DeviceEnrollment>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PersonDeviceEnrollDialog(
      participant: participant,
      devices: devices,
      schoolId: schoolId,
      usedSlotsByDevice: usedSlotsByDevice,
    ),
  );
}

class _PersonDeviceEnrollDialog extends StatefulWidget {
  final EnrollmentParticipant participant;
  final List<Device> devices;
  final String schoolId;
  final Map<String, Set<int>> usedSlotsByDevice;

  const _PersonDeviceEnrollDialog({
    required this.participant,
    required this.devices,
    required this.schoolId,
    required this.usedSlotsByDevice,
  });

  @override
  State<_PersonDeviceEnrollDialog> createState() =>
      _PersonDeviceEnrollDialogState();
}

class _PersonDeviceEnrollDialogState extends State<_PersonDeviceEnrollDialog> {
  Device? _selectedDevice;
  bool _isSubmitting = false;
  String? _statusMessage;

  List<Device> get _activeDevices =>
      widget.devices.where((d) => d.isActive).toList(growable: false);

  String _deviceLabel(Device device) {
    final name = device.deviceName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return device.deviceId;
  }

  Set<int> _usedSlotsFor(Device device) =>
      widget.usedSlotsByDevice[device.deviceId] ?? {};

  int? _firstFreeSlot(Device device) =>
      DeviceEnrollmentFlow.firstFreeSlot(_usedSlotsFor(device));

  Future<void> _submit() async {
    final device = _selectedDevice;
    if (device == null) {
      setState(() => _statusMessage = 'Choose a device first.');
      return;
    }
    final slot = _firstFreeSlot(device);
    if (slot == null) {
      setState(
        () => _statusMessage = 'This device has no free enrollment slots.',
      );
      return;
    }
    if (widget.participant.cardId.isEmpty) {
      setState(
        () =>
            _statusMessage =
                'This person is missing an internal card identifier.',
      );
      return;
    }
    if (widget.schoolId.isEmpty) {
      setState(
        () =>
            _statusMessage =
                'This device is not linked to a school. Assign the device before enrolling.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final enrollment = await DeviceEnrollmentFlow.submitEnrollment(
        deviceId: device.deviceId,
        schoolId: widget.schoolId,
        slot: slot,
        participant: widget.participant,
        onStatus: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
        isMounted: () => mounted,
      );
      if (!mounted) return;
      if (enrollment == null) {
        setState(() {
          _isSubmitting = false;
          _statusMessage =
              'Enrollment was not confirmed yet. If the device is still asking for '
              'the second scan, finish it and refresh the list afterward.';
        });
        return;
      }
      Navigator.pop(context, enrollment);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = _activeDevices;

    return AlertDialog(
      title: Text('Enroll ${widget.participant.name}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputChip(
                avatar: Icon(
                  widget.participant.icon,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                label: Text(widget.participant.name),
              ),
              const SizedBox(height: 8),
              Text(
                widget.participant.subtitle,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (active.isEmpty)
                Text(
                  'No active devices found. Add a device first.',
                  style: TextStyle(color: colorScheme.error),
                )
              else
                DropdownButtonFormField<Device>(
                  value: _selectedDevice,
                  decoration: const InputDecoration(
                    labelText: 'Device',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final d in active)
                      DropdownMenuItem(
                        value: d,
                        child: Text(_deviceLabel(d)),
                      ),
                  ],
                  onChanged:
                      _isSubmitting
                          ? null
                          : (d) => setState(() => _selectedDevice = d),
                ),
              if (_selectedDevice != null) ...[
                const SizedBox(height: 12),
                _buildSlotNote(colorScheme),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isSubmitting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onSurface,
                          size: 18,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting || active.isEmpty ? null : _submit,
          child: const Text('Send enroll'),
        ),
      ],
    );
  }

  Widget _buildSlotNote(ColorScheme colorScheme) {
    final device = _selectedDevice!;
    final hasFreeSlot = _firstFreeSlot(device) != null;
    final text =
        hasFreeSlot
            ? 'Enrollment details are filled automatically from the selected person.'
            : 'This device has no free slots. Remove someone from the device first.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            hasFreeSlot
                ? colorScheme.secondaryContainer
                : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasFreeSlot ? Icons.auto_awesome_outlined : Icons.error_outline,
            size: 18,
            color:
                hasFreeSlot
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    hasFreeSlot
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
