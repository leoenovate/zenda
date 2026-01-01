import 'package:flutter/material.dart';
import '../../models/student.dart';
import 'student_form_stepper.dart';
import '../../services/firebase_service.dart';

class AddStudentDialog extends StatelessWidget {
  final Function(Student) onStudentAdded;

  const AddStudentDialog({
    Key? key,
    required this.onStudentAdded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Text('Add New Student'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: StudentFormStepper(
          onSubmit: (studentData) => _submitForm(context, studentData),
        ),
      ),
    );
  }

  Future<void> _submitForm(BuildContext context, Map<String, dynamic> studentData) async {
    try {
      final String studentId = await FirebaseService.addStudent(studentData);

      final student = Student(
        id: studentId,
        name: studentData['name'],
        period: studentData['period'],
        registrationNumber: studentData['registrationNumber'],
        gender: studentData['gender'],
        birthdate: studentData['birthdate'],
        fatherName: studentData['fatherName'],
        fatherPhone: studentData['fatherPhone'],
        motherName: studentData['motherName'],
        motherPhone: studentData['motherPhone'],
        country: studentData['country'],
        province: studentData['province'],
        district: studentData['district'],
        sector: studentData['sector'],
        cell: studentData['cell'],
        attendanceHistory: [],
      );

      onStudentAdded(student);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 