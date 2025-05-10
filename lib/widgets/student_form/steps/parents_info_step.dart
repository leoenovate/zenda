import 'package:flutter/material.dart';

class ParentsInfoStep extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const ParentsInfoStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ParentsInfoStep> createState() => _ParentsInfoStepState();
}

class _ParentsInfoStepState extends State<ParentsInfoStep> {
  late TextEditingController _fatherNameController;
  late TextEditingController _fatherPhoneController;
  late TextEditingController _motherNameController;
  late TextEditingController _motherPhoneController;

  @override
  void initState() {
    super.initState();
    _fatherNameController = TextEditingController(text: widget.formData['fatherName']);
    _fatherPhoneController = TextEditingController(text: widget.formData['fatherPhone']);
    _motherNameController = TextEditingController(text: widget.formData['motherName']);
    _motherPhoneController = TextEditingController(text: widget.formData['motherPhone']);
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _fatherPhoneController.dispose();
    _motherNameController.dispose();
    _motherPhoneController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ParentsInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData['fatherName'] != _fatherNameController.text) {
      _fatherNameController.text = widget.formData['fatherName'] ?? '';
    }
    if (widget.formData['fatherPhone'] != _fatherPhoneController.text) {
      _fatherPhoneController.text = widget.formData['fatherPhone'] ?? '';
    }
    if (widget.formData['motherName'] != _motherNameController.text) {
      _motherNameController.text = widget.formData['motherName'] ?? '';
    }
    if (widget.formData['motherPhone'] != _motherPhoneController.text) {
      _motherPhoneController.text = widget.formData['motherPhone'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Father\'s Name'),
          controller: _fatherNameController,
          onChanged: (value) => widget.onChanged('fatherName', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Father\'s Phone'),
          controller: _fatherPhoneController,
          onChanged: (value) => widget.onChanged('fatherPhone', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Mother\'s Name'),
          controller: _motherNameController,
          onChanged: (value) => widget.onChanged('motherName', value),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Mother\'s Phone'),
          controller: _motherPhoneController,
          onChanged: (value) => widget.onChanged('motherPhone', value),
        ),
      ],
    );
  }
} 