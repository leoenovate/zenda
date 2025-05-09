import 'package:flutter/material.dart';

class BasicInfoStep extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const BasicInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Name *'),
          controller: TextEditingController(text: formData['name']),
          onChanged: (value) => onChanged('name', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Registration Number *'),
          controller: TextEditingController(text: formData['registrationNumber']),
          onChanged: (value) => onChanged('registrationNumber', value),
        ),
        DropdownButtonFormField<String>(
          value: formData['period'],
          decoration: const InputDecoration(labelText: 'Session *'),
          items: ['Morning', 'Afternoon'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged('period', value);
          },
        ),
        DropdownButtonFormField<String>(
          value: formData['gender'],
          decoration: const InputDecoration(labelText: 'Gender *'),
          items: ['M', 'F'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'M' ? 'Male' : 'Female'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged('gender', value);
          },
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Birthdate (YYYY-MM-DD)'),
          controller: TextEditingController(text: formData['birthdate']),
          onChanged: (value) => onChanged('birthdate', value),
        ),
      ],
    );
  }
} 