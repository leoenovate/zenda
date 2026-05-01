import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/device_enrollment.dart';
import '../../models/school.dart';
import '../../models/teacher.dart';
import '../../models/worker.dart';
import '../../services/firebase_service.dart';
import '../../services/zenda_device_api_service.dart';

/// Screen for managing fingerprint slots on a single device.
///
/// Reads the canonical enrolled-users list from the
/// `device_enrollments` Firestore collection (school-scoped via
/// `FirebaseService._scopedSchool`) and uses the api-v2 server only
/// as a MQTT relay for enroll / delete / clear commands. Persistence
/// is done in Firestore as soon as the device confirms an enroll, so
/// the list survives api-v2 server restarts and never collapses around
/// whatever the device firmware happens to have most-recently echoed
/// back via `/status`.
class DeviceEnrollmentsScreen extends StatefulWidget {
  final Device device;
  final School? school;
  final List<Teacher> teachers;
  final List<Worker> workers;

  const DeviceEnrollmentsScreen({
    super.key,
    required this.device,
    required this.school,
    this.teachers = const [],
    this.workers = const [],
  });

  @override
  State<DeviceEnrollmentsScreen> createState() =>
      _DeviceEnrollmentsScreenState();
}

class _DeviceEnrollmentsScreenState extends State<DeviceEnrollmentsScreen> {
  static const int _maxSlot = 200;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isEnrolling = false;
  String? _error;
  List<DeviceEnrollment> _enrollments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _schoolId =>
      widget.device.schoolId ?? widget.school?.id ?? '';

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final enrollments = await FirebaseService.getDeviceEnrollments(
        deviceId: widget.device.deviceId,
      );
      if (!mounted) return;
      setState(() {
        _enrollments = enrollments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Re-reads enrollments from Firestore. Synchronous and fast — no
  /// device round-trip is needed because Firestore is the system of
  /// record (we wrote there as soon as the device confirmed each enroll).
  Future<void> _refresh() async {
    if (_isRefreshing || _isEnrolling) return;
    setState(() => _isRefreshing = true);
    try {
      await _load();
      if (!mounted) return;
      _showSnackBar('Enrollments updated');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Refresh failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _confirmAndDelete(DeviceEnrollment enrollment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete enrollment?'),
            content: Text(
              'Remove ${enrollment.name} from '
              '$_deviceLabel? This sends a delete command to the device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Best-effort MQTT delete. We always remove the Firestore record
      // even if the device is offline — the local DB is the source of
      // truth, and the device will pick up the change on the next
      // clear / re-enroll cycle.
      try {
        await ZendaDeviceApiService.postDelete(
          deviceId: widget.device.deviceId,
          id: enrollment.slotId,
        );
      } catch (_) {}
      await FirebaseService.deleteDeviceEnrollment(
        deviceId: widget.device.deviceId,
        slotId: enrollment.slotId,
      );
      if (!mounted) return;
      _showSnackBar('Enrollment removed');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear all enrollments?'),
            content: Text(
              'This removes every fingerprint slot from $_deviceLabel and cannot '
              'be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear all'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    try {
      try {
        await ZendaDeviceApiService.postClear(
          deviceId: widget.device.deviceId,
        );
      } catch (_) {}
      await FirebaseService.clearDeviceEnrollments(widget.device.deviceId);
      if (!mounted) return;
      _showSnackBar('All enrollments cleared');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to clear: $e', isError: true);
    }
  }

  Future<void> _openEnrollDialog() async {
    final usedSlots = _enrollments.map((e) => e.slotId).toSet();
    final schoolId = _schoolId;
    setState(() => _isEnrolling = true);
    final result = await showDialog<DeviceEnrollment>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _EnrollDialog(
            deviceId: widget.device.deviceId,
            deviceLabel: _deviceLabel,
            schoolId: schoolId,
            usedSlots: usedSlots,
            maxSlot: _maxSlot,
            teachers: widget.teachers,
            workers: widget.workers,
          ),
    );
    if (!mounted) return;
    setState(() => _isEnrolling = false);
    if (result != null) {
      // The dialog already wrote the record to Firestore as soon as
      // the device confirmed enrollment, so the next list refresh is
      // just a re-read.
      await _load();
    }
  }

  String get _deviceLabel {
    final name = (widget.device.deviceName ?? '').trim();
    return name.isEmpty ? widget.device.deviceId : name;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_deviceLabel),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'clear') _confirmAndClear();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('Clear all enrollments'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _isEnrolling ? null : _openEnrollDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Enroll user'),
      ),
      body: RefreshIndicator(
        onRefresh: _isEnrolling ? () async {} : _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _buildHeaderCard(colorScheme),
            const SizedBox(height: 16),
            _buildActionsRow(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorCard(colorScheme)
            else if (_enrollments.isEmpty)
              _buildEmptyState(colorScheme)
            else
              _buildUsersList(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    final school = widget.school?.name ?? 'your school';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fingerprint,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _deviceLabel,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.device.deviceId} · $school',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_enrollments.length}/$_maxSlot slots',
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isRefreshing || _isEnrolling ? null : _refresh,
            icon:
                _isRefreshing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.sync),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fingerprint_outlined,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No enrollments on this device yet',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Enroll user" to add a teacher or worker to this device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enrolled users on this device',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_enrollments.length} user${_enrollments.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _enrollments.length,
            separatorBuilder:
                (_, __) =>
                    Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder:
                (_, i) => _buildUserRow(_enrollments[i], colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(DeviceEnrollment enrollment, ColorScheme colorScheme) {
    final deviceName = (widget.device.deviceName ?? '').trim();
    final deviceLine =
        deviceName.isEmpty
            ? widget.device.deviceId
            : '${widget.device.deviceId} · $deviceName';

    return Padding(
      key: ValueKey('enrolled-${enrollment.slotId}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fingerprint,
                  color: colorScheme.onPrimaryContainer,
                  size: 16,
                ),
                Text(
                  '#${enrollment.slotId}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  enrollment.name.isEmpty ? 'Unknown' : enrollment.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _EnrollmentField(
                  label: 'Slot',
                  value: enrollment.slotId.toString(),
                ),
                _EnrollmentField(
                  label: 'Card ID',
                  value: enrollment.cardId.isEmpty ? '—' : enrollment.cardId,
                  monospace: true,
                ),
                _EnrollmentField(
                  label: 'Phone',
                  value:
                      (enrollment.phone ?? '').isEmpty
                          ? '—'
                          : enrollment.phone!,
                ),
                _EnrollmentField(
                  label: 'Device',
                  value: deviceLine,
                  monospace: true,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete enrollment',
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            onPressed: () => _confirmAndDelete(enrollment),
          ),
        ],
      ),
    );
  }
}

/// One labelled key/value line inside an enrolled-user row. Keeps the
/// label column at a fixed width so multiple lines align vertically.
class _EnrollmentField extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _EnrollmentField({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
                fontFamily: monospace ? 'monospace' : null,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollDialog extends StatefulWidget {
  final String deviceId;
  final String deviceLabel;
  final String schoolId;
  final Set<int> usedSlots;
  final int maxSlot;
  final List<Teacher> teachers;
  final List<Worker> workers;

  const _EnrollDialog({
    required this.deviceId,
    required this.deviceLabel,
    required this.schoolId,
    required this.usedSlots,
    required this.maxSlot,
    required this.teachers,
    required this.workers,
  });

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _participantSearchController = TextEditingController();

  _EnrollmentParticipant? _selectedParticipant;
  String _participantSearch = '';
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    _participantSearchController.dispose();
    super.dispose();
  }

  int? _firstFreeSlot() {
    for (var i = 1; i <= widget.maxSlot; i++) {
      if (!widget.usedSlots.contains(i)) return i;
    }
    return null;
  }

  void _applyParticipant(_EnrollmentParticipant participant) {
    setState(() {
      _selectedParticipant = participant;
    });
  }

  List<_EnrollmentParticipant> get _teacherParticipants {
    return widget.teachers
        .where((t) => t.isActive)
        .map(_EnrollmentParticipant.fromTeacher)
        .toList(growable: false);
  }

  List<_EnrollmentParticipant> get _workerParticipants {
    return widget.workers
        .where((w) => w.isActive)
        .map(_EnrollmentParticipant.fromWorker)
        .toList(growable: false);
  }

  List<_EnrollmentParticipant> _filterParticipants(
    List<_EnrollmentParticipant> participants,
  ) {
    final q = _participantSearch.trim().toLowerCase();
    if (q.isEmpty) return participants;
    return participants
        .where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.cardId.toLowerCase().contains(q) ||
              p.subtitle.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final participant = _selectedParticipant;
    final slot = _firstFreeSlot();
    if (participant == null) {
      setState(() => _statusMessage = 'Choose a teacher or worker first.');
      return;
    }
    if (slot == null) {
      setState(() => _statusMessage = 'This device has no free slots left.');
      return;
    }
    if (participant.cardId.isEmpty) {
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
                'This device is not linked to a school. Open the device record and assign it before enrolling users.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Sending enroll command...';
    });

    try {
      await ZendaDeviceApiService.postEnroll(
        deviceId: widget.deviceId,
        id: slot,
        cardId: participant.cardId,
        name: participant.name,
        phone: participant.phone.isEmpty ? null : participant.phone,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Command sent. Place the same finger on the device twice when prompted.';
      });
      final confirmed = await _pollEnrollmentStatus(slot);
      if (!mounted) return;
      if (!confirmed) {
        setState(() {
          _isSubmitting = false;
          _statusMessage =
              'Enrollment was not confirmed yet. If the device is still asking for '
              'the second scan, finish it and try Refresh after the dialog closes.';
        });
        return;
      }

      // Persist to Firestore as the system of record so the next
      // enroll picks the next free slot — even if the api-v2
      // server's `/api/users/:deviceId` snapshot has collapsed
      // around the most recent enrollment.
      final enrollment = DeviceEnrollment(
        deviceId: widget.deviceId,
        schoolId: widget.schoolId,
        slotId: slot,
        name: participant.name,
        cardId: participant.cardId,
        phone: participant.phone.isEmpty ? null : participant.phone,
        enrolledAt: DateTime.now(),
      );
      try {
        await FirebaseService.upsertDeviceEnrollment(enrollment);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _statusMessage =
              'Enrolled on the device but failed to save the record: $e';
        });
        return;
      }
      if (!mounted) return;
      Navigator.pop(context, enrollment);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Failed: $e';
      });
    }
  }

  /// Polls the api-v2 server for an enrollment confirmation. The device
  /// enrollment flow needs two finger placements, so keep the dialog in
  /// a waiting state long enough for both scans instead of re-sending
  /// the enroll command after the first pass.
  Future<bool> _pollEnrollmentStatus(int slot) async {
    const maxAttempts = 90;
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      try {
        final status = await ZendaDeviceApiService.getEnrollmentStatus(
          deviceId: widget.deviceId,
          enrollmentId: slot,
        );
        if (!mounted) return false;
        if (status.found) {
          setState(() {
            _statusMessage = _formatEnrollmentStatus(status);
          });
          if (status.success) return true;
        } else if (i == 10 && mounted) {
          setState(() {
            _statusMessage =
                'Waiting for the device. Place the same finger twice when prompted.';
          });
        }
      } catch (_) {}
    }
    return false;
  }

  String _formatEnrollmentStatus(EnrollmentStatus status) {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Enroll user on ${widget.deviceLabel}'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildParticipantPicker(colorScheme),
                const SizedBox(height: 12),
                _buildAutomaticDetailsNote(colorScheme),
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
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Send enroll'),
        ),
      ],
    );
  }

  Widget _buildParticipantPicker(ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              tabs: const [Tab(text: 'Teachers'), Tab(text: 'Workers')],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _participantSearchController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: 'Search by name, role, subject, or phone...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _participantSearch = v),
              ),
            ),
            if (_selectedParticipant != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: InputChip(
                  avatar: Icon(
                    _selectedParticipant!.icon,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  label: Text('Selected: ${_selectedParticipant!.name}'),
                  onDeleted:
                      _isSubmitting
                          ? null
                          : () {
                            setState(() => _selectedParticipant = null);
                          },
                ),
              ),
            SizedBox(
              height: 220,
              child: TabBarView(
                children: [
                  _buildParticipantList(
                    _filterParticipants(_teacherParticipants),
                  ),
                  _buildParticipantList(
                    _filterParticipants(_workerParticipants),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomaticDetailsNote(ColorScheme colorScheme) {
    final hasFreeSlot = _firstFreeSlot() != null;
    final text =
        hasFreeSlot
            ? 'Enrollment details are filled automatically from the selected person.'
            : 'This device has no free enrollment slots. Delete someone before adding another person.';

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

  Widget _buildParticipantList(List<_EnrollmentParticipant> participants) {
    final colorScheme = Theme.of(context).colorScheme;
    if (participants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No matching people found',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: participants.length,
      separatorBuilder:
          (_, __) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (_, i) {
        final participant = participants[i];
        final selected = _selectedParticipant?.key == participant.key;
        return ListTile(
          key: ValueKey('participant-${participant.key}'),
          enabled: !_isSubmitting,
          selected: selected,
          leading: CircleAvatar(
            backgroundColor:
                selected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
            child: Icon(
              participant.icon,
              color:
                  selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          title: Text(participant.name),
          subtitle: Text(participant.subtitle),
          trailing:
              selected
                  ? Icon(Icons.check_circle, color: colorScheme.primary)
                  : const Icon(Icons.chevron_right),
          onTap: _isSubmitting ? null : () => _applyParticipant(participant),
        );
      },
    );
  }
}

class _EnrollmentParticipant {
  final String key;
  final String name;
  final String cardId;
  final String phone;
  final String subtitle;
  final IconData icon;

  const _EnrollmentParticipant({
    required this.key,
    required this.name,
    required this.cardId,
    required this.phone,
    required this.subtitle,
    required this.icon,
  });

  factory _EnrollmentParticipant.fromTeacher(Teacher teacher) {
    final cardId = _firstNonEmpty([teacher.employeeId, teacher.id]);
    final detail = _joinNonEmpty(['Teacher', teacher.subject, teacher.phone]);
    return _EnrollmentParticipant(
      key: 'teacher-${teacher.id ?? teacher.employeeId ?? teacher.name}',
      name: teacher.name,
      cardId: cardId,
      phone: teacher.phone ?? '',
      subtitle: detail,
      icon: Icons.school_outlined,
    );
  }

  factory _EnrollmentParticipant.fromWorker(Worker worker) {
    final cardId = _firstNonEmpty([worker.employeeId, worker.id]);
    final detail = _joinNonEmpty(['Worker', worker.role, worker.phone]);
    return _EnrollmentParticipant(
      key: 'worker-${worker.id ?? worker.employeeId ?? worker.name}',
      name: worker.name,
      cardId: cardId,
      phone: worker.phone ?? '',
      subtitle: detail,
      icon: Icons.engineering_outlined,
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
