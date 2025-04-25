import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/worker.dart';
import 'models/api_log.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'workers';
  static const String _logsCollection = 'api_logs';

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
  
  // API Logs Methods
  
  // Add a new API log
  static Future<String> addApiLog(ApiLog log) async {
    try {
      final DocumentReference docRef = await _firestore.collection(_logsCollection).add(log.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add API log: $e');
    }
  }
  
  // Get all API logs
  static Future<List<ApiLog>> getApiLogs({int limit = 100}) async {
    try {
      // Get logs without orderBy to avoid requiring an index
      final QuerySnapshot snapshot = await _firestore
          .collection(_logsCollection)
          .limit(limit * 2) // Get extra records to allow for sorting
          .get();
          
      // Process logs in memory
      final logs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ApiLog.fromMap(data, doc.id);
      }).toList();
      
      // Sort by timestamp descending in memory
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Ensure we only return the requested number
      if (logs.length > limit) {
        return logs.sublist(0, limit);
      }
      
      return logs;
    } catch (e) {
      throw Exception('Failed to get API logs: $e');
    }
  }
  
  // Get API logs by endpoint
  static Future<List<ApiLog>> getApiLogsByEndpoint(String endpoint, {int limit = 100}) async {
    try {
      // Modified query to not require a composite index - first filter by endpoint
      final QuerySnapshot snapshot = await _firestore
          .collection(_logsCollection)
          .where('endpoint', isEqualTo: endpoint)
          .limit(limit)
          .get();
          
      // Then sort the results in memory instead of in the query
      final logs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ApiLog.fromMap(data, doc.id);
      }).toList();
      
      // Sort in memory by timestamp descending
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return logs;
    } catch (e) {
      throw Exception('Failed to get API logs by endpoint: $e');
    }
  }
  
  // Delete API logs older than a specified date
  static Future<void> deleteOldApiLogs(DateTime olderThan) async {
    try {
      // Convert DateTime to ISO string for comparison
      final cutoffDate = olderThan.toIso8601String();
      
      // Get all logs
      final QuerySnapshot snapshot = await _firestore
          .collection(_logsCollection)
          .get();
          
      // Filter in memory
      final docsToDelete = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Handle different timestamp formats
        dynamic timestamp = data['timestamp'];
        String timestampStr;
        
        if (timestamp is String) {
          timestampStr = timestamp;
        } else if (timestamp != null) {
          try {
            // For Firestore Timestamp objects
            timestampStr = timestamp.toDate().toIso8601String();
          } catch (e) {
            return false;
          }
        } else {
          return false;
        }
        
        return timestampStr.compareTo(cutoffDate) < 0;
      }).toList();
      
      // Delete in batches to avoid limits
      if (docsToDelete.isNotEmpty) {
        final batch = _firestore.batch();
        int count = 0;
        
        for (var doc in docsToDelete) {
          batch.delete(doc.reference);
          count++;
          
          // Firestore batches are limited to 500 operations
          if (count >= 450) {
            await batch.commit();
            count = 0;
          }
        }
        
        if (count > 0) {
          await batch.commit();
        }
      }
    } catch (e) {
      throw Exception('Failed to delete old API logs: $e');
    }
  }
} 