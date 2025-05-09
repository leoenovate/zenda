import 'package:flutter/material.dart';

class ParentsInfoStep extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const ParentsInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Father\'s Name'),
          controller: TextEditingController(text: formData['fatherName']),
          onChanged: (value) => onChanged('fatherName', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Father\'s Phone'),
          controller: TextEditingController(text: formData['fatherPhone']),
          onChanged: (value) => onChanged('fatherPhone', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Mother\'s Name'),
          controller: TextEditingController(text: formData['motherName']),
          onChanged: (value) => onChanged('motherName', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Mother\'s Phone'),
          controller: TextEditingController(text: formData['motherPhone']),
          onChanged: (value) => onChanged('motherPhone', value),
        ),
      ],
    );
  }
} 