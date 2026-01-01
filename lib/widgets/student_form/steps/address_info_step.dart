import 'package:flutter/material.dart';

class AddressInfoStep extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const AddressInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AddressInfoStep> createState() => _AddressInfoStepState();
}

class _AddressInfoStepState extends State<AddressInfoStep> {
  late TextEditingController _countryController;
  late TextEditingController _provinceController;
  late TextEditingController _districtController;
  late TextEditingController _sectorController;
  late TextEditingController _cellController;

  @override
  void initState() {
    super.initState();
    _countryController = TextEditingController(text: widget.formData['country']);
    _provinceController = TextEditingController(text: widget.formData['province']);
    _districtController = TextEditingController(text: widget.formData['district']);
    _sectorController = TextEditingController(text: widget.formData['sector']);
    _cellController = TextEditingController(text: widget.formData['cell']);
  }

  @override
  void dispose() {
    _countryController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _sectorController.dispose();
    _cellController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AddressInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData['country'] != _countryController.text) {
      _countryController.text = widget.formData['country'] ?? '';
    }
    if (widget.formData['province'] != _provinceController.text) {
      _provinceController.text = widget.formData['province'] ?? '';
    }
    if (widget.formData['district'] != _districtController.text) {
      _districtController.text = widget.formData['district'] ?? '';
    }
    if (widget.formData['sector'] != _sectorController.text) {
      _sectorController.text = widget.formData['sector'] ?? '';
    }
    if (widget.formData['cell'] != _cellController.text) {
      _cellController.text = widget.formData['cell'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Country'),
          controller: _countryController,
          onChanged: (value) => widget.onChanged('country', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Province'),
          controller: _provinceController,
          onChanged: (value) => widget.onChanged('province', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'District'),
          controller: _districtController,
          onChanged: (value) => widget.onChanged('district', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Sector'),
          controller: _sectorController,
          onChanged: (value) => widget.onChanged('sector', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Cell'),
          controller: _cellController,
          onChanged: (value) => widget.onChanged('cell', value),
        ),
      ],
    );
  }
} 