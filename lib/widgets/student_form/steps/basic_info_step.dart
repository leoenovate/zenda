import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.formData['name']);
    _registrationController = TextEditingController(text: widget.formData['registrationNumber']);
    _birthdateController = TextEditingController(text: widget.formData['birthdate']);
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
        DropdownButtonFormField<String>(
          value: widget.formData['period'],
          decoration: const InputDecoration(labelText: 'Session *'),
          items: ['Morning', 'Afternoon'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) widget.onChanged('period', value);
          },
        ),
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
} 