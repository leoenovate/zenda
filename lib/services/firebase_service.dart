import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import '../models/school.dart';
import '../models/device.dart';
import '../models/user.dart' as app_user;
import 'dart:async';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'students';
  static const String _messagesCollection = 'messages';

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
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    Future<List<Student>> attemptGetStudents() async {
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
            attendanceHistory: _parseAttendanceHistory(data),
          );
        }).toList();
      } on FirebaseException catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(retryDelay * retryCount);
          return attemptGetStudents();
        } else {
          throw Exception('Failed to get students after multiple attempts: ${e.message}');
        }
      } catch (e) {
        throw Exception('Failed to get students: $e');
      }
    }
    
    return attemptGetStudents();
  }
  
  // Helper to parse attendance history with better error handling
  static List<Attendance> _parseAttendanceHistory(Map<String, dynamic> data) {
    try {
      final List<dynamic> rawAttendance = data['attendanceHistory'] as List<dynamic>? ?? [];
      return rawAttendance.map((attendance) {
        try {
          final statusString = attendance['status'] as String? ?? 'present';
          AttendanceStatus status;
          try {
            status = AttendanceStatus.values.firstWhere(
              (e) => e.name == statusString,
              orElse: () => AttendanceStatus.present,
            );
          } catch (e) {
            status = AttendanceStatus.present;
          }
          
          return Attendance(
            date: DateTime.parse(attendance['date']),
            status: status,
          );
        } catch (e) {
          // Log error but don't fail the entire process
          print('Error parsing attendance record: $e');
          return Attendance(
            date: DateTime.now(),
            status: AttendanceStatus.unknown,
          );
        }
      }).toList();
    } catch (e) {
      print('Error parsing attendance history: $e');
      return []; // Return empty list rather than crashing
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
  
  // CHAT FUNCTIONALITY
  
  // Send a message
  static Future<String> sendMessage({
    required String studentId,
    required String content,
    required MessageSender sender,
    String? senderName,
    String? attachmentUrl,
  }) async {
    try {
      final message = {
        'studentId': studentId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': sender == MessageSender.school ? 'school' : 'parent',
        'isRead': false,
        'senderName': senderName,
        'attachmentUrl': attachmentUrl,
      };
      
      final DocumentReference docRef = await _firestore.collection(_messagesCollection).add(message);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
  
  // Get messages for a specific student
  static Stream<List<Message>> getMessagesStream(String studentId) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where('studentId', isEqualTo: studentId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Error getting messages: $e');
      return Stream.value([]);
    }
  }
  
  // Mark message as read
  static Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore.collection(_messagesCollection).doc(messageId).update({
        'isRead': true,
      });
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }
  
  // Delete a message
  static Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection(_messagesCollection).doc(messageId).delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }
  
  // Get unread message count for a student
  static Stream<int> getUnreadMessageCount(String studentId, MessageSender recipient) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where('studentId', isEqualTo: studentId)
          .where('sender', isEqualTo: recipient == MessageSender.school ? 'parent' : 'school')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting unread message count: $e');
      return Stream.value(0);
    }
  }
  
  // Get all conversations with unread messages (for overview)
  static Stream<Map<String, int>> getAllUnreadMessages(MessageSender recipient) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where('sender', isEqualTo: recipient == MessageSender.school ? 'parent' : 'school')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        final Map<String, int> result = {};
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final studentId = data['studentId'] as String;
          result[studentId] = (result[studentId] ?? 0) + 1;
        }
        return result;
      });
    } catch (e) {
      print('Error getting all unread messages: $e');
      return Stream.value({});
    }
  }

  // ATTENDANCE FUNCTIONALITY

  // Record attendance for a student
  static Future<void> recordAttendance({
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    try {
      final studentDoc = await _firestore.collection(_collection).doc(studentId).get();
      if (!studentDoc.exists) {
        throw Exception('Student not found');
      }

      final data = studentDoc.data()!;
      List<dynamic> attendanceHistory = data['attendanceHistory'] as List<dynamic>? ?? [];

      // Remove existing attendance for the same date if any
      attendanceHistory.removeWhere((att) {
        try {
          final attDate = DateTime.parse(att['date']);
          return attDate.year == date.year &&
                 attDate.month == date.month &&
                 attDate.day == date.day;
        } catch (e) {
          return false;
        }
      });

      // Add new attendance record
      attendanceHistory.add({
        'date': date.toIso8601String(),
        'status': status.name,
      });

      await _firestore.collection(_collection).doc(studentId).update({
        'attendanceHistory': attendanceHistory,
      });
    } catch (e) {
      throw Exception('Failed to record attendance: $e');
    }
  }

  // Get students by student number (registration number)
  static Future<List<Student>> getStudentsByStudentNumber(String studentNumber) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('registrationNumber', isEqualTo: studentNumber)
          .get();

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
          attendanceHistory: _parseAttendanceHistory(data),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get students by student number: $e');
    }
  }

  // Get students by parent phone number
  static Future<List<Student>> getStudentsByParentPhone(String phoneNumber) async {
    try {
      // Format phone number (remove +250 if present, handle variations)
      String normalizedPhone = phoneNumber.replaceAll('+250', '').replaceAll(' ', '');
      
      // Query for students with matching father or mother phone
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('fatherPhone', isEqualTo: normalizedPhone)
          .get();
      
      final QuerySnapshot motherSnapshot = await _firestore
          .collection(_collection)
          .where('motherPhone', isEqualTo: normalizedPhone)
          .get();

      final Set<String> seenIds = {};
      final List<Student> students = [];

      // Add students from father phone query
      for (var doc in snapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          final data = doc.data() as Map<String, dynamic>;
          students.add(Student(
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
            attendanceHistory: _parseAttendanceHistory(data),
          ));
        }
      }

      // Add students from mother phone query
      for (var doc in motherSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          final data = doc.data() as Map<String, dynamic>;
          students.add(Student(
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
            attendanceHistory: _parseAttendanceHistory(data),
          ));
        }
      }

      return students;
    } catch (e) {
      throw Exception('Failed to get students by parent phone: $e');
    }
  }

  // API LOGGING FUNCTIONALITY

  // Log an API call or authentication attempt
  static Future<void> logApiCall({
    required String studentId,
    required bool success,
    String? studentName,
    String? deviceId,
    String? errorMessage,
    String type = 'authentication',
  }) async {
    try {
      await _firestore.collection('api_logs').add({
        'studentId': studentId,
        'studentName': studentName,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': deviceId,
        'errorMessage': errorMessage,
        'type': type,
      });
    } catch (e) {
      // Don't throw error for logging failures, just print
      print('Failed to log API call: $e');
    }
  }

  // SYSTEM OWNER FUNCTIONALITY

  // Get all schools
  static Future<List<School>> getSchools() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('schools').get();
      return snapshot.docs.map((doc) {
        return School.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get schools: $e');
    }
  }

  // Add a new school
  static Future<void> addSchool(School school) async {
    try {
      final data = school.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('schools').add(data);
    } catch (e) {
      throw Exception('Failed to add school: $e');
    }
  }

  // Update an existing school
  static Future<void> updateSchool(School school) async {
    try {
      if (school.id == null) {
        throw Exception('School ID is required for update');
      }
      await _firestore.collection('schools').doc(school.id).update(school.toFirestore());
    } catch (e) {
      throw Exception('Failed to update school: $e');
    }
  }

  // Delete a school
  static Future<void> deleteSchool(String schoolId) async {
    try {
      await _firestore.collection('schools').doc(schoolId).delete();
    } catch (e) {
      throw Exception('Failed to delete school: $e');
    }
  }

  // Get all devices
  static Future<List<Device>> getDevices() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('devices').get();
      return snapshot.docs.map((doc) {
        return Device.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get devices: $e');
    }
  }

  // Get all users/admins
  static Future<List<app_user.AppUser>> getUsers() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        return app_user.AppUser.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // Get recent activity (from api_logs)
  static Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('api_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'studentId': data['studentId'],
          'studentName': data['studentName'],
          'success': data['success'] ?? false,
          'timestamp': data['timestamp'],
          'type': data['type'] ?? 'authentication',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get recent activity: $e');
    }
  }
} 