import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
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
          return Attendance(
            date: DateTime.parse(attendance['date']),
            status: AttendanceStatus.values.firstWhere(
              (e) => e.toString() == attendance['status'],
              orElse: () => AttendanceStatus.present,
            ),
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
} 