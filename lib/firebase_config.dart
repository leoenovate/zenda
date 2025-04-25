import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/worker.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'workers';

  // Add a new worker
  static Future<String> addWorker(Map<String, dynamic> workerData) async {
    try {
      // Ensure attendanceHistory is properly formatted
      workerData['attendanceHistory'] = workerData['attendanceHistory'] ?? [];
      
      // Add timestamp if not present
      workerData['createdAt'] = workerData['createdAt'] ?? DateTime.now().toIso8601String();
      
      final DocumentReference docRef = await _firestore.collection(_collection).add(workerData);
      
      // Return the document ID
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add worker: $e');
    }
  }

  // Get all workers
  static Future<List<Worker>> getWorkers() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Worker(
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
      throw Exception('Failed to get workers: $e');
    }
  }

  // Update a worker
  static Future<void> updateWorker(String workerId, Map<String, dynamic> workerData) async {
    try {
      await _firestore.collection(_collection).doc(workerId).update(workerData);
    } catch (e) {
      throw Exception('Failed to update worker: $e');
    }
  }

  // Delete a worker
  static Future<void> deleteWorker(String workerId) async {
    try {
      await _firestore.collection(_collection).doc(workerId).delete();
    } catch (e) {
      throw Exception('Failed to delete worker: $e');
    }
  }
} 