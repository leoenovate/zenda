import 'package:flutter/material.dart';

class AddressInfoStep extends StatelessWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const AddressInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Country'),
          controller: TextEditingController(text: formData['country']),
          onChanged: (value) => onChanged('country', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Province'),
          controller: TextEditingController(text: formData['province']),
          onChanged: (value) => onChanged('province', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'District'),
          controller: TextEditingController(text: formData['district']),
          onChanged: (value) => onChanged('district', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Sector'),
          controller: TextEditingController(text: formData['sector']),
          onChanged: (value) => onChanged('sector', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Cell'),
          controller: TextEditingController(text: formData['cell']),
          onChanged: (value) => onChanged('cell', value),
        ),
      ],
    );
  }
} 