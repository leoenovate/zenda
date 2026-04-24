import 'package:flutter/material.dart';
import '../../../models/session.dart';
import '../../../services/firebase_service.dart';

class BasicInfoStep extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const BasicInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late TextEditingController _nameController;
  late TextEditingController _registrationController;
  late TextEditingController _birthdateController;

  List<Session> _sessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.formData['name']);
    _registrationController = TextEditingController(text: widget.formData['registrationNumber']);
    _birthdateController = TextEditingController(text: widget.formData['birthdate']);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final schoolId = widget.formData['schoolId'] as String?;
      final sessions = await FirebaseService.getSessions(
        schoolId: (schoolId != null && schoolId.isNotEmpty) ? schoolId : null,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSessions = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BasicInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData['name'] != _nameController.text) {
      _nameController.text = widget.formData['name'] ?? '';
    }
    if (widget.formData['registrationNumber'] != _registrationController.text) {
      _registrationController.text = widget.formData['registrationNumber'] ?? '';
    }
    if (widget.formData['birthdate'] != _birthdateController.text) {
      _birthdateController.text = widget.formData['birthdate'] ?? '';
    }
  }

  List<String> get _selectedSessionIds {
    final raw = widget.formData['sessionIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  void _toggleSession(String id, bool? selected) {
    final current = List<String>.from(_selectedSessionIds);
    if (selected == true) {
      if (!current.contains(id)) current.add(id);
    } else {
      current.remove(id);
    }
    widget.onChanged('sessionIds', current);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Name *'),
          controller: _nameController,
          onChanged: (value) => widget.onChanged('name', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Registration Number *'),
          controller: _registrationController,
          onChanged: (value) => widget.onChanged('registrationNumber', value),
        ),
        const SizedBox(height: 12),
        _buildSessionsPicker(),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: widget.formData['gender'],
          decoration: const InputDecoration(labelText: 'Gender *'),
          items: ['M', 'F'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'M' ? 'Male' : 'Female'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) widget.onChanged('gender', value);
          },
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Birthdate (YYYY-MM-DD)'),
          controller: _birthdateController,
          onChanged: (value) => widget.onChanged('birthdate', value),
        ),
      ],
    );
  }

  Widget _buildSessionsPicker() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sessions',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          if (_loadingSessions)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            )
          else if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No sessions configured yet. Create sessions from the admin panel.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ..._sessions.map((s) {
              final selected = _selectedSessionIds.contains(s.id);
              final label = _sessionLabel(s);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected,
                title: Text(label),
                subtitle: (s.startTime != null && s.endTime != null)
                    ? Text('${s.startTime} - ${s.endTime}')
                    : null,
                onChanged: s.id == null ? null : (v) => _toggleSession(s.id!, v),
              );
            }).toList(),
        ],
      ),
    );
  }

  String _sessionLabel(Session s) {
    if (s.className != null && s.className!.isNotEmpty) return s.className!;
    if (s.teacherName != null && s.teacherName!.isNotEmpty) return s.teacherName!;
    return 'Session ${s.id ?? ''}';
  }
}
