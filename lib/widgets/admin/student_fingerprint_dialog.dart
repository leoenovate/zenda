import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../services/firebase_service.dart';
import '../student_form/steps/fingerprint_step.dart';

/// Opens fingerprint capture for a student and persists the result to Firestore.
Future<bool> showStudentFingerprintDialog({
  required BuildContext context,
  required Student student,
}) async {
  final formData = <String, dynamic>{
    'fingerprintData': student.fingerprintData,
    'fingerprintTimestamp': student.fingerprintTimestamp,
  };

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _StudentFingerprintDialog(
      student: student,
      formData: formData,
    ),
  );
  return saved == true;
}

class _StudentFingerprintDialog extends StatefulWidget {
  final Student student;
  final Map<String, dynamic> formData;

  const _StudentFingerprintDialog({
    required this.student,
    required this.formData,
  });

  @override
  State<_StudentFingerprintDialog> createState() =>
      _StudentFingerprintDialogState();
}

class _StudentFingerprintDialogState extends State<_StudentFingerprintDialog> {
  bool _isSaving = false;

  void _onChanged(String key, dynamic value) {
    setState(() => widget.formData[key] = value);
  }

  Future<void> _save() async {
    if (widget.student.id == null) return;
    if (widget.formData['fingerprintData'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a fingerprint first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseService.updateStudent(widget.student.id!, {
        'fingerprintData': widget.formData['fingerprintData'],
        'fingerprintTimestamp': widget.formData['fingerprintTimestamp'],
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving fingerprint: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFingerprint = widget.formData['fingerprintData'] != null;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Enroll ${widget.student.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan the student fingerprint on the connected sensor.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            FingerprintStep(
              formData: widget.formData,
              onChanged: _onChanged,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving || !hasFingerprint ? null : _save,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Save'),
        ),
      ],
    );
  }
}
