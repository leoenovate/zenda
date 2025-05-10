import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'students';

  // Add a new student
  static Future<String> addStudent(Map<String, dynamic> studentData) async {
    try {
      // Ensure attendanceHistory is properly formatted
      studentData['attendanceHistory'] = studentData['attendanceHistory'] ?? [];
      
      // Add timestamp if not present
      studentData['createdAt'] = studentData['createdAt'] ?? DateTime.now().toIso8601String();
      
      final DocumentReference docRef = await _firestore.collection(_collection).add(studentData);
      
      // Return the document ID
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add student: $e');
    }
  }

  // Get all students
  static Future<List<Student>> getStudents() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Student(
          id: doc.id,
          name: data['name'] ?? '',
          period: data['period'] ?? 'Morning',
          registrationNumber: data['registrationNumber'],
          gender: data['gender'],
          birthdate: data['birthdate'],
          fatherName: data['fatherName'],
          fatherPhone: data['fatherPhone'],
          motherName: data['motherName'],
          motherPhone: data['motherPhone'],
          country: data['country'],
          province: data['province'],
          district: data['district'],
          sector: data['sector'],
          cell: data['cell'],
          fingerprintData: data['fingerprintData'],
          fingerprintTimestamp: data['fingerprintTimestamp'],
          attendanceHistory: (data['attendanceHistory'] as List<dynamic>? ?? []).map((attendance) {
            return Attendance(
              date: DateTime.parse(attendance['date']),
              status: AttendanceStatus.values.firstWhere(
                (e) => e.toString() == attendance['status'],
                orElse: () => AttendanceStatus.present,
              ),
            );
          }).toList(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get students: $e');
    }
  }

  // Update a student
  static Future<void> updateStudent(String studentId, Map<String, dynamic> studentData) async {
    try {
      await _firestore.collection(_collection).doc(studentId).update(studentData);
    } catch (e) {
      throw Exception('Failed to update student: $e');
    }
  }

  // Delete a student
  static Future<void> deleteStudent(String studentId) async {
    try {
      await _firestore.collection(_collection).doc(studentId).delete();
    } catch (e) {
      throw Exception('Failed to delete student: $e');
    }
  }
} 