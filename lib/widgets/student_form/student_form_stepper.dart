import 'package:flutter/material.dart';
import 'steps/basic_info_step.dart';
import 'steps/parents_info_step.dart';
import 'steps/address_info_step.dart';
import 'steps/fingerprint_step.dart';

class StudentFormStepper extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Map<String, dynamic>? initialData;

  const StudentFormStepper({
    Key? key,
    required this.onSubmit,
    this.initialData,
  }) : super(key: key);

  @override
  State<StudentFormStepper> createState() => _StudentFormStepperState();
}

class _StudentFormStepperState extends State<StudentFormStepper> {
  int _currentStep = 0;
  late final Map<String, dynamic> _formData;

  @override
  void initState() {
    super.initState();
    _formData = {
      'name': '',
      'registrationNumber': '',
      'gender': 'M',
      'birthdate': '',
      'period': 'Morning',
      'fatherName': '',
      'fatherPhone': '',
      'motherName': '',
      'motherPhone': '',
      'country': '',
      'province': '',
      'district': '',
      'sector': '',
      'cell': '',
      'fingerprintData': null,
    };

    // If initial data is provided, update the form data
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
  }

  void _updateFormData(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Basic Info'),
        content: BasicInfoStep(
          formData: _formData,
          onChanged: _updateFormData,
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Parents Info'),
        content: ParentsInfoStep(
          formData: _formData,
          onChanged: _updateFormData,
        ),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Address'),
        content: AddressInfoStep(
          formData: _formData,
          onChanged: _updateFormData,
        ),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Fingerprint'),
        content: FingerprintStep(
          formData: _formData,
          onChanged: _updateFormData,
        ),
        isActive: _currentStep >= 3,
        state: _formData['fingerprintData'] != null 
            ? StepState.complete 
            : _currentStep == 3 
              ? StepState.editing
              : StepState.indexed,
        subtitle: Text(
          _formData['fingerprintData'] != null
              ? 'Fingerprint captured'
              : 'Fingerprint not captured yet',
          style: TextStyle(
            color: _formData['fingerprintData'] != null ? Colors.green : Colors.grey,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    
    return Stepper(
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepContinue: () {
        if (_currentStep < steps.length - 1) {
          setState(() {
            _currentStep++;
          });
        } else {
          widget.onSubmit(_formData);
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() {
            _currentStep--;
          });
        }
      },
      steps: steps,
      controlsBuilder: (context, controls) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: controls.onStepCancel,
                    child: const Text('Back'),
                  ),
                ),
              if (_currentStep > 0)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: controls.onStepContinue,
                  child: Text(_currentStep == steps.length - 1 ? 'Submit' : 'Next'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 