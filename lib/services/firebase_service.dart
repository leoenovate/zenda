import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import '../models/school.dart';
import '../models/device.dart';
import '../models/user.dart' as app_user;
import '../models/session.dart';
import '../models/teacher.dart';
import '../models/class_group.dart';
import '../models/parent.dart' as app_parent;
import '../models/system_config.dart';
import '../models/worker.dart';
import '../models/staff_time_off.dart';
import '../models/role.dart';
import '../models/device_enrollment.dart';
import 'auth_service.dart';
import 'dart:async';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'students';
  static const String _messagesCollection = 'messages';

  /// Optional `schoolId` filter for collections whose rules allow broad admin
  /// reads without `sameSchool` on every doc (e.g. `users`, `parents`).
  ///
  /// Non–system-owners with a session school still filter when possible.
  /// When there is no school on the session, the query stays unfiltered — fine
  /// only where Firestore rules do not require per-document school checks.
  static Query<Map<String, dynamic>> _scoped(
    Query<Map<String, dynamic>> q, {
    String? explicitSchoolId,
  }) {
    if (explicitSchoolId != null) {
      return q.where('schoolId', isEqualTo: explicitSchoolId);
    }
    final session = AuthService.currentSession;
    if (session == null || session.role == UserRole.systemOwner) {
      return q;
    }
    final schoolId = session.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return q;
    }
    return q.where('schoolId', isEqualTo: schoolId);
  }

  /// School-bound collections (`devices`, `students`, …) deny unscoped list
  /// reads for non-owners in Firestore rules. Always filter by school, or skip
  /// the query when the session has no school (empty result).
  static Query<Map<String, dynamic>>? _scopedSchool(
    Query<Map<String, dynamic>> q, {
    String? explicitSchoolId,
  }) {
    if (explicitSchoolId != null) {
      return q.where('schoolId', isEqualTo: explicitSchoolId);
    }
    final session = AuthService.currentSession;
    if (session == null || session.role == UserRole.systemOwner) {
      return q;
    }
    final schoolId = session.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return null;
    }
    return q.where('schoolId', isEqualTo: schoolId);
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _getWithAuthRetry(
    Query<Map<String, dynamic>> query,
  ) async {
    return query.get();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _getDocWithAuthRetry(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    return doc.get();
  }

  // Add a new student
  static Future<String> addStudent(Map<String, dynamic> studentData) async {
    try {
      // Ensure attendanceHistory is properly formatted
      studentData['attendanceHistory'] = studentData['attendanceHistory'] ?? [];

      // Add timestamp if not present
      studentData['createdAt'] =
          studentData['createdAt'] ?? DateTime.now().toIso8601String();

      final DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(studentData);

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
        final studentsQuery = _scopedSchool(_firestore.collection(_collection));
        if (studentsQuery == null) return [];
        final QuerySnapshot snapshot = await studentsQuery.get();
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Student(
            id: doc.id,
            name: data['name'] ?? '',
            sessionIds: _parseSessionIds(data),
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
          throw Exception(
            'Failed to get students after multiple attempts: ${e.message}',
          );
        }
      } catch (e) {
        throw Exception('Failed to get students: $e');
      }
    }

    return attemptGetStudents();
  }

  // Helper to parse sessionIds list from a Firestore student document.
  // Accepts the new `sessionIds` array. Returns an empty list when missing.
  static List<String> _parseSessionIds(Map<String, dynamic> data) {
    final raw = data['sessionIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  // Helper to parse attendance history with better error handling
  static List<Attendance> _parseAttendanceHistory(Map<String, dynamic> data) {
    try {
      final List<dynamic> rawAttendance =
          data['attendanceHistory'] as List<dynamic>? ?? [];
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

  /// Assign every student that currently has no `schoolId` to [schoolId].
  /// Useful for backfilling legacy records after multi-school support was
  /// introduced. Returns the number of students updated.
  static Future<int> backfillStudentSchoolIds(String schoolId) async {
    try {
      final snap = await _firestore.collection(_collection).get();
      final batch = _firestore.batch();
      int updated = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['schoolId'] == null || (data['schoolId'] as String).isEmpty) {
          batch.update(doc.reference, {'schoolId': schoolId});
          updated++;
        }
      }
      if (updated > 0) {
        await batch.commit();
      }
      return updated;
    } catch (e) {
      throw Exception('Failed to backfill student schoolIds: $e');
    }
  }

  /// Bulk assign a specific set of students to [schoolId], overwriting any
  /// existing value. Returns the number of students updated.
  static Future<int> assignStudentsToSchool(
    List<String> studentIds,
    String schoolId,
  ) async {
    if (studentIds.isEmpty) return 0;
    try {
      final batch = _firestore.batch();
      for (final id in studentIds) {
        batch.update(_firestore.collection(_collection).doc(id), {
          'schoolId': schoolId,
        });
      }
      await batch.commit();
      return studentIds.length;
    } catch (e) {
      throw Exception('Failed to assign students: $e');
    }
  }

  // Update a student
  static Future<void> updateStudent(
    String studentId,
    Map<String, dynamic> studentData,
  ) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(studentId)
          .update(studentData);
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

      final DocumentReference docRef = await _firestore
          .collection(_messagesCollection)
          .add(message);
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
            return snapshot.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();
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
  static Stream<int> getUnreadMessageCount(
    String studentId,
    MessageSender recipient,
  ) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where('studentId', isEqualTo: studentId)
          .where(
            'sender',
            isEqualTo: recipient == MessageSender.school ? 'parent' : 'school',
          )
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting unread message count: $e');
      return Stream.value(0);
    }
  }

  // Get all conversations with unread messages (for overview)
  static Stream<Map<String, int>> getAllUnreadMessages(
    MessageSender recipient,
  ) {
    try {
      return _firestore
          .collection(_messagesCollection)
          .where(
            'sender',
            isEqualTo: recipient == MessageSender.school ? 'parent' : 'school',
          )
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
      final studentDoc =
          await _firestore.collection(_collection).doc(studentId).get();
      if (!studentDoc.exists) {
        throw Exception('Student not found');
      }

      final data = studentDoc.data()!;
      List<dynamic> attendanceHistory =
          data['attendanceHistory'] as List<dynamic>? ?? [];

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
  static Future<List<Student>> getStudentsByStudentNumber(
    String studentNumber,
  ) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('registrationNumber', isEqualTo: studentNumber)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Student(
          id: doc.id,
          name: data['name'] ?? '',
          sessionIds: _parseSessionIds(data),
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
  static Future<List<Student>> getStudentsByParentPhone(
    String phoneNumber,
  ) async {
    try {
      // Format phone number (remove +250 if present, handle variations)
      String normalizedPhone = phoneNumber
          .replaceAll('+250', '')
          .replaceAll(' ', '');

      // Query for students with matching father or mother phone
      final QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('fatherPhone', isEqualTo: normalizedPhone)
              .get();

      final QuerySnapshot motherSnapshot =
          await _firestore
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
          students.add(
            Student(
              id: doc.id,
              name: data['name'] ?? '',
              sessionIds: _parseSessionIds(data),
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
            ),
          );
        }
      }

      // Add students from mother phone query
      for (var doc in motherSnapshot.docs) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          final data = doc.data() as Map<String, dynamic>;
          students.add(
            Student(
              id: doc.id,
              name: data['name'] ?? '',
              sessionIds: _parseSessionIds(data),
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
            ),
          );
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
      final session = AuthService.currentSession;
      if (session != null && session.role != UserRole.systemOwner) {
        final schoolId = session.schoolId;
        if (schoolId == null || schoolId.isEmpty) return [];

        final doc = await _getDocWithAuthRetry(
          _firestore.collection('schools').doc(schoolId),
        );
        if (!doc.exists || doc.data() == null) return [];
        return [School.fromFirestore(doc.data()!, doc.id)];
      }

      final QuerySnapshot snapshot = await _getWithAuthRetry(
        _firestore.collection('schools'),
      );
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
      await _firestore
          .collection('schools')
          .doc(school.id)
          .update(school.toFirestore());
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
      final q = _scopedSchool(_firestore.collection('devices'));
      if (q == null) return [];
      final QuerySnapshot snapshot = await _getWithAuthRetry(q);
      return snapshot.docs.map((doc) {
        return Device.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get devices: $e');
    }
  }

  // Add a device
  static Future<String> addDevice(Device device) async {
    try {
      final data = device.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('devices').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add device: $e');
    }
  }

  // Update an existing device
  static Future<void> updateDevice(Device device) async {
    try {
      if (device.id == null) {
        throw Exception('Device ID is required for update');
      }
      await _firestore
          .collection('devices')
          .doc(device.id)
          .update(device.toFirestore());
    } catch (e) {
      throw Exception('Failed to update device: $e');
    }
  }

  // Delete a device
  static Future<void> deleteDevice(String deviceId) async {
    try {
      await _firestore.collection('devices').doc(deviceId).delete();
    } catch (e) {
      throw Exception('Failed to delete device: $e');
    }
  }

  // --- Device enrollments ---------------------------------------------
  //
  // The `device_enrollments` collection tracks which employee is
  // programmed at which slot on which fingerprint device. Document id
  // is `${deviceId}_${slotId}` so writes are idempotent upserts.
  //
  // The Flutter app is the system of record for this collection — we
  // write here as soon as the device confirms a successful enroll, and
  // we read here for every list view, so we never have to wait for a
  // possibly-sleeping api-v2 server to mirror state from MQTT pushes.

  /// Lists every enrollment in the current school's scope. Pass
  /// [deviceId] to narrow to a single device.
  static Future<List<DeviceEnrollment>> getDeviceEnrollments({
    String? deviceId,
  }) async {
    try {
      final base = _scopedSchool(_firestore.collection('device_enrollments'));
      if (base == null) return [];
      Query<Map<String, dynamic>> q = base;
      if (deviceId != null && deviceId.isNotEmpty) {
        q = q.where('deviceId', isEqualTo: deviceId);
      }
      final snapshot = await _getWithAuthRetry(q);
      final results =
          snapshot.docs
              .map((doc) => DeviceEnrollment.fromFirestore(doc.data(), doc.id))
              .toList();
      results.sort((a, b) => a.slotId.compareTo(b.slotId));
      return results;
    } catch (e) {
      throw Exception('Failed to load device enrollments: $e');
    }
  }

  /// Upserts a single enrollment record. Always uses the deterministic
  /// `${deviceId}_${slotId}` doc id so subsequent enrolls at the same
  /// slot replace the previous holder cleanly.
  static Future<void> upsertDeviceEnrollment(
    DeviceEnrollment enrollment,
  ) async {
    try {
      final docId = DeviceEnrollment.makeDocId(
        enrollment.deviceId,
        enrollment.slotId,
      );
      final data = enrollment.toFirestore();
      data['enrolledAt'] ??= FieldValue.serverTimestamp();
      await _firestore
          .collection('device_enrollments')
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save enrollment: $e');
    }
  }

  static Future<void> deleteDeviceEnrollment({
    required String deviceId,
    required int slotId,
  }) async {
    try {
      final docId = DeviceEnrollment.makeDocId(deviceId, slotId);
      await _firestore.collection('device_enrollments').doc(docId).delete();
    } catch (e) {
      throw Exception('Failed to delete enrollment: $e');
    }
  }

  /// Removes every enrollment row for [deviceId]. Done in batched
  /// commits to stay within Firestore's 500-write batch limit.
  static Future<void> clearDeviceEnrollments(String deviceId) async {
    try {
      final snapshot =
          await _firestore
              .collection('device_enrollments')
              .where('deviceId', isEqualTo: deviceId)
              .get();
      if (snapshot.docs.isEmpty) return;
      const batchLimit = 400;
      for (var i = 0; i < snapshot.docs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final end = (i + batchLimit).clamp(0, snapshot.docs.length);
        for (final doc in snapshot.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to clear enrollments: $e');
    }
  }

  // Get all users/admins
  static Future<List<app_user.AppUser>> getUsers() async {
    try {
      final QuerySnapshot snapshot =
          await _scoped(_firestore.collection('users')).get();
      return snapshot.docs.map((doc) {
        return app_user.AppUser.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // ADMIN / USER MANAGEMENT

  // Create a new admin user as a Firestore-only account. The temporary
  // password is stored as a salted hash and checked by AuthService.
  // Returns the new user's document id.
  static Future<String> addAdmin({
    required String email,
    required String password,
    required String role,
    String? name,
    String? schoolId,
    String? phone,
    String? roleId,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final existing =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: normalizedEmail)
              .limit(1)
              .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('An account with this email already exists.');
      }

      final salt = AuthService.generateSalt();
      final doc = await _firestore.collection('users').add({
        'email': normalizedEmail,
        'passwordSalt': salt,
        'passwordHash': AuthService.hashPassword(password, salt),
        if (name != null && name.isNotEmpty) 'name': name,
        'role': role,
        if (schoolId != null) 'schoolId': schoolId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });

      return doc.id;
    } catch (e) {
      throw Exception('Failed to create admin: $e');
    }
  }

  // Update an existing admin user's profile fields.
  static Future<void> updateAdmin(app_user.AppUser user) async {
    try {
      if (user.id == null) {
        throw Exception('User ID is required for update');
      }
      final data = user.toFirestore();
      // Explicit null handling so the form can clear optional fields.
      if (user.roleId == null) data['roleId'] = FieldValue.delete();
      if (user.phone == null) data['phone'] = FieldValue.delete();
      await _firestore.collection('users').doc(user.id).update(data);
    } catch (e) {
      throw Exception('Failed to update admin: $e');
    }
  }

  // Replace the stored Firestore password for an admin account.
  static Future<void> resetAdminPassword(String userId, String password) async {
    try {
      final salt = AuthService.generateSalt();
      await _firestore.collection('users').doc(userId).update({
        'passwordSalt': salt,
        'passwordHash': AuthService.hashPassword(password, salt),
        'password': FieldValue.delete(),
        'temporaryPassword': FieldValue.delete(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  // Activate or deactivate an admin user.
  static Future<void> setAdminActive(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Failed to update admin status: $e');
    }
  }

  // Delete an admin user document.
  static Future<void> deleteAdmin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete admin: $e');
    }
  }

  // Get sessions scoped to the current user / given school.
  static Future<List<Session>> getSessions({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('sessions'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      final sessions =
          snap.docs.map((d) => Session.fromFirestore(d.data(), d.id)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      return sessions;
    } catch (e) {
      throw Exception('Failed to get sessions: $e');
    }
  }

  // Get sessions for a specific school
  static Future<List<Session>> getSchoolSessions(String schoolId) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('sessions')
              .where('schoolId', isEqualTo: schoolId)
              .orderBy('date', descending: true)
              .get();
      return snapshot.docs.map((doc) {
        return Session.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      // If index doesn't exist yet, try without orderBy
      try {
        final QuerySnapshot snapshot =
            await _firestore
                .collection('sessions')
                .where('schoolId', isEqualTo: schoolId)
                .get();
        final sessions =
            snapshot.docs.map((doc) {
              return Session.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
        // Sort manually
        sessions.sort((a, b) => b.date.compareTo(a.date));
        return sessions;
      } catch (e2) {
        throw Exception('Failed to get school sessions: $e2');
      }
    }
  }

  // Get recent activity (from api_logs).
  //
  // Recent activity is a non-critical dashboard widget. Return an empty list
  // on permission issues so callers using `Future.wait` do not lose the rest
  // of the dashboard data because this optional query failed.
  static Future<List<Map<String, dynamic>>> getRecentActivity({
    int limit = 10,
  }) async {
    try {
      final QuerySnapshot snapshot = await _getWithAuthRetry(
        _firestore
            .collection('api_logs')
            .orderBy('timestamp', descending: true)
            .limit(limit),
      );

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
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const [];
      }
      throw Exception('Failed to get recent activity: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to get recent activity: $e');
    }
  }

  // TEACHERS

  static Future<List<Teacher>> getTeachers({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('teachers'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      return snap.docs
          .map((d) => Teacher.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get teachers: $e');
    }
  }

  static Future<String> addTeacher(Teacher teacher) async {
    try {
      final data = teacher.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('teachers').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add teacher: $e');
    }
  }

  static Future<void> updateTeacher(Teacher teacher) async {
    try {
      if (teacher.id == null) {
        throw Exception('Teacher ID is required for update');
      }
      final data = teacher.toFirestore();
      // Explicit null handling so the form can clear optional fields.
      if (teacher.roleId == null) data['roleId'] = FieldValue.delete();
      if (teacher.email == null) data['email'] = FieldValue.delete();
      if (teacher.phone == null) data['phone'] = FieldValue.delete();
      if (teacher.subject == null) data['subject'] = FieldValue.delete();
      if (teacher.employeeId == null) data['employeeId'] = FieldValue.delete();
      await _firestore.collection('teachers').doc(teacher.id).update(data);
    } catch (e) {
      throw Exception('Failed to update teacher: $e');
    }
  }

  static Future<void> deleteTeacher(String id) async {
    try {
      await _firestore.collection('teachers').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete teacher: $e');
    }
  }

  // CLASSES

  static Future<List<ClassGroup>> getClasses({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('classes'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      return snap.docs
          .map((d) => ClassGroup.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get classes: $e');
    }
  }

  static Future<String> addClass(ClassGroup group) async {
    try {
      final data = group.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('classes').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add class: $e');
    }
  }

  static Future<void> updateClass(ClassGroup group) async {
    try {
      if (group.id == null) {
        throw Exception('Class ID is required for update');
      }
      await _firestore
          .collection('classes')
          .doc(group.id)
          .update(group.toFirestore());
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  static Future<void> deleteClass(String id) async {
    try {
      await _firestore.collection('classes').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  static Future<void> assignStudentsToClass(
    String classId,
    List<String> studentIds,
  ) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': studentIds,
      });
    } catch (e) {
      throw Exception('Failed to assign students to class: $e');
    }
  }

  // PARENTS

  static Future<List<app_parent.Parent>> getParents({String? schoolId}) async {
    try {
      final q = _scoped(
        _firestore.collection('parents'),
        explicitSchoolId: schoolId,
      );
      final snap = await q.get();
      return snap.docs
          .map((d) => app_parent.Parent.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get parents: $e');
    }
  }

  static Future<String> addParent(app_parent.Parent parent) async {
    try {
      final data = parent.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('parents').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add parent: $e');
    }
  }

  static Future<void> updateParent(app_parent.Parent parent) async {
    try {
      if (parent.id == null) {
        throw Exception('Parent ID is required for update');
      }
      await _firestore
          .collection('parents')
          .doc(parent.id)
          .update(parent.toFirestore());
    } catch (e) {
      throw Exception('Failed to update parent: $e');
    }
  }

  static Future<void> deleteParent(String id) async {
    try {
      await _firestore.collection('parents').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete parent: $e');
    }
  }

  /// Derive parent records from existing students. Creates one parent doc per
  /// unique phone (father or mother), with `studentIds` collecting all children.
  /// Skips phones that already have a parent document. Returns the number of
  /// parent records created.
  static Future<int> syncParentsFromStudents() async {
    try {
      final existing = await getParents();
      final existingPhones = existing.map((p) => p.phone).toSet();

      final students = await getStudents();
      final Map<String, Map<String, dynamic>> byPhone = {};

      void record(
        String? phone,
        String? name,
        String relationship,
        String studentId,
      ) {
        if (phone == null || phone.trim().isEmpty) return;
        final key = phone.trim();
        if (existingPhones.contains(key)) return;
        final entry = byPhone.putIfAbsent(
          key,
          () => {
            'phone': key,
            'name': name,
            'relationship': relationship,
            'studentIds': <String>[],
          },
        );
        (entry['studentIds'] as List<String>).add(studentId);
        entry['name'] ??= name;
      }

      for (final s in students) {
        record(s.fatherPhone, s.fatherName, 'father', s.id!);
        record(s.motherPhone, s.motherName, 'mother', s.id!);
      }

      int created = 0;
      final batch = _firestore.batch();
      for (final entry in byPhone.values) {
        final docRef = _firestore.collection('parents').doc();
        batch.set(docRef, {
          'phone': entry['phone'],
          if (entry['name'] != null) 'name': entry['name'],
          'relationship': entry['relationship'],
          'studentIds': entry['studentIds'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        created++;
      }
      if (created > 0) {
        await batch.commit();
      }
      return created;
    } catch (e) {
      throw Exception('Failed to sync parents from students: $e');
    }
  }

  // SESSIONS (create / update / end)

  static Future<String> createSession(Session session) async {
    try {
      final data = session.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('sessions').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  static Future<void> updateSession(Session session) async {
    try {
      if (session.id == null) {
        throw Exception('Session ID is required for update');
      }
      await _firestore
          .collection('sessions')
          .doc(session.id)
          .update(session.toFirestore());
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  static Future<void> endSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to end session: $e');
    }
  }

  static Future<void> deleteSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).delete();
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  /// One-off migration: for every school that still carries legacy
  /// `morningStart/afternoonStart` fields (either top-level or under
  /// `attendanceSettings`/`weeklySchedule`), seed matching `Session` documents
  /// and then clear those legacy fields. Students with a legacy `period`
  /// string get their `sessionIds` populated with the matching seeded session
  /// and have `period` removed. Idempotent: skips schools/students that have
  /// already been migrated. Returns a summary map.
  static Future<Map<String, int>> migrateSchoolPeriodsToSessions() async {
    int schoolsMigrated = 0;
    int sessionsCreated = 0;
    int studentsMigrated = 0;

    final schoolsSnap = await _firestore.collection('schools').get();
    final Map<String, Map<String, String>> schoolPeriodToSessionId = {};

    for (final schoolDoc in schoolsSnap.docs) {
      final data = schoolDoc.data();

      String? morningStart, morningEnd, morningLateTime;
      String? afternoonStart, afternoonEnd, afternoonLateTime;

      final attendanceSettings = data['attendanceSettings'];
      if (attendanceSettings is Map) {
        morningStart = attendanceSettings['morningStart'] as String?;
        morningEnd = attendanceSettings['morningEnd'] as String?;
        morningLateTime = attendanceSettings['morningLateTime'] as String?;
        afternoonStart = attendanceSettings['afternoonStart'] as String?;
        afternoonEnd = attendanceSettings['afternoonEnd'] as String?;
        afternoonLateTime = attendanceSettings['afternoonLateTime'] as String?;
      }

      final weeklySchedule = data['weeklySchedule'];
      if (weeklySchedule is Map) {
        final morning = weeklySchedule['morning'];
        if (morning is Map) {
          morningStart ??= morning['start'] as String?;
          morningEnd ??= morning['end'] as String?;
          morningLateTime ??= morning['lateTime'] as String?;
        }
        final afternoon = weeklySchedule['afternoon'];
        if (afternoon is Map) {
          afternoonStart ??= afternoon['start'] as String?;
          afternoonEnd ??= afternoon['end'] as String?;
          afternoonLateTime ??= afternoon['lateTime'] as String?;
        }
      }

      morningStart ??= data['morningStart'] as String?;
      morningEnd ??= data['morningEnd'] as String?;
      morningLateTime ??= data['morningLateTime'] as String?;
      afternoonStart ??= data['afternoonStart'] as String?;
      afternoonEnd ??= data['afternoonEnd'] as String?;
      afternoonLateTime ??= data['afternoonLateTime'] as String?;

      final hasMorning = morningStart != null || morningEnd != null;
      final hasAfternoon = afternoonStart != null || afternoonEnd != null;
      if (!hasMorning && !hasAfternoon) continue;

      final today = DateTime.now();
      final schoolId = schoolDoc.id;
      final perSchool = <String, String>{};

      if (hasMorning) {
        final session = Session(
          schoolId: schoolId,
          date: DateTime(today.year, today.month, today.day),
          isActive: true,
          startTime: morningStart,
          endTime: morningEnd,
          lateTime: morningLateTime,
          className: 'Morning (default)',
        );
        final id = await createSession(session);
        perSchool['Morning'] = id;
        sessionsCreated++;
      }
      if (hasAfternoon) {
        final session = Session(
          schoolId: schoolId,
          date: DateTime(today.year, today.month, today.day),
          isActive: true,
          startTime: afternoonStart,
          endTime: afternoonEnd,
          lateTime: afternoonLateTime,
          className: 'Afternoon (default)',
        );
        final id = await createSession(session);
        perSchool['Afternoon'] = id;
        sessionsCreated++;
      }

      schoolPeriodToSessionId[schoolId] = perSchool;

      await schoolDoc.reference.update({
        'attendanceSettings': FieldValue.delete(),
        'weeklySchedule': FieldValue.delete(),
        'morningStart': FieldValue.delete(),
        'morningEnd': FieldValue.delete(),
        'morningLateTime': FieldValue.delete(),
        'afternoonStart': FieldValue.delete(),
        'afternoonEnd': FieldValue.delete(),
        'afternoonLateTime': FieldValue.delete(),
      });
      schoolsMigrated++;
    }

    // Backfill students' sessionIds from their legacy period string.
    final studentsSnap = await _firestore.collection(_collection).get();
    for (final studentDoc in studentsSnap.docs) {
      final data = studentDoc.data();
      final legacyPeriod = data['period'] as String?;
      if (legacyPeriod == null) continue;
      final schoolId = data['schoolId'] as String?;
      final mapping =
          schoolId == null ? null : schoolPeriodToSessionId[schoolId];
      final existing =
          (data['sessionIds'] as List?)?.map((e) => e.toString()).toList() ??
          <String>[];
      final sessionId = mapping?[legacyPeriod];
      final List<String> nextIds = [...existing];
      if (sessionId != null && !nextIds.contains(sessionId)) {
        nextIds.add(sessionId);
      }
      await studentDoc.reference.update({
        'sessionIds': nextIds,
        'period': FieldValue.delete(),
      });
      studentsMigrated++;
    }

    return {
      'schools': schoolsMigrated,
      'sessions': sessionsCreated,
      'students': studentsMigrated,
    };
  }

  // SYSTEM CONFIG

  static const String _systemConfigDocId = 'config';

  static Future<SystemConfig> getSystemConfig() async {
    try {
      final doc =
          await _firestore.collection('system').doc(_systemConfigDocId).get();
      if (!doc.exists) {
        return const SystemConfig();
      }
      return SystemConfig.fromFirestore(doc.data() ?? {});
    } catch (e) {
      throw Exception('Failed to get system config: $e');
    }
  }

  static Future<void> setSystemConfig(SystemConfig config) async {
    try {
      await _firestore
          .collection('system')
          .doc(_systemConfigDocId)
          .set(config.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save system config: $e');
    }
  }

  // WORKERS

  static Future<List<Worker>> getWorkers({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('workers'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      return snap.docs
          .map((d) => Worker.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get workers: $e');
    }
  }

  static Future<String> addWorker(Worker worker) async {
    try {
      final data = worker.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('workers').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add worker: $e');
    }
  }

  static Future<void> updateWorker(Worker worker) async {
    try {
      if (worker.id == null) {
        throw Exception('Worker ID is required for update');
      }
      final data = worker.toFirestore();
      // Explicit null handling: clear roleId / employeeId / phone / email
      // when the form leaves them blank, so updates don't keep stale values.
      if (worker.roleId == null) data['roleId'] = FieldValue.delete();
      if (worker.employeeId == null) data['employeeId'] = FieldValue.delete();
      if (worker.phone == null) data['phone'] = FieldValue.delete();
      if (worker.email == null) data['email'] = FieldValue.delete();
      // Once a worker is edited, the legacy free-form role text is
      // superseded by roleId. Clear it so reads no longer fall back to
      // the stale string.
      data['role'] = FieldValue.delete();
      await _firestore.collection('workers').doc(worker.id).update(data);
    } catch (e) {
      throw Exception('Failed to update worker: $e');
    }
  }

  static Future<void> deleteWorker(String id) async {
    try {
      await _firestore.collection('workers').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete worker: $e');
    }
  }

  static Future<List<StaffTimeOff>> getStaffTimeOffs({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('worker_time_off'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      final list =
          snap.docs
              .map((d) => StaffTimeOff.fromFirestore(d.data(), d.id))
              .toList();
      list.sort((a, b) {
        final c = b.startDate.compareTo(a.startDate);
        if (c != 0) return c;
        return (a.assigneeName).compareTo(b.assigneeName);
      });
      return list;
    } catch (e) {
      throw Exception('Failed to get staff time off: $e');
    }
  }

  static Future<String> addStaffTimeOff(StaffTimeOff entry) async {
    try {
      final doc = _firestore.collection('worker_time_off').doc();
      final data = entry.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      await doc.set(data);
      return doc.id;
    } catch (e) {
      throw Exception('Failed to add staff time off: $e');
    }
  }

  static Future<void> updateStaffTimeOff(StaffTimeOff entry) async {
    try {
      if (entry.id == null) {
        throw Exception('Time off ID is required for update');
      }
      final data = entry.toFirestore();
      if (entry.assigneeKind != 'worker') {
        data['workerId'] = FieldValue.delete();
        data['workerName'] = FieldValue.delete();
      }
      if (!entry.hasAttachment) {
        data['attachmentStoragePath'] = FieldValue.delete();
        data['attachmentUrl'] = FieldValue.delete();
        data['attachmentFileName'] = FieldValue.delete();
        data['attachmentBase64'] = FieldValue.delete();
        data['attachmentContentType'] = FieldValue.delete();
      } else if (entry.hasBase64Attachment) {
        data['attachmentStoragePath'] = FieldValue.delete();
        data['attachmentUrl'] = FieldValue.delete();
      } else if (entry.hasLegacyStorageAttachment) {
        data['attachmentBase64'] = FieldValue.delete();
        data['attachmentContentType'] = FieldValue.delete();
      }
      await _firestore.collection('worker_time_off').doc(entry.id).update(data);
    } catch (e) {
      throw Exception('Failed to update staff time off: $e');
    }
  }

  static Future<void> deleteLegacyStaffTimeOffStorage(
    String? storagePath,
  ) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (_) {}
  }

  static Future<void> deleteStaffTimeOff(StaffTimeOff entry) async {
    try {
      if (entry.id == null) {
        throw Exception('Time off ID is required for delete');
      }
      await deleteLegacyStaffTimeOffStorage(entry.attachmentStoragePath);
      await _firestore.collection('worker_time_off').doc(entry.id).delete();
    } catch (e) {
      throw Exception('Failed to delete staff time off: $e');
    }
  }

  // ROLES (custom, school-scoped role definitions)

  static Future<List<Role>> getRoles({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('roles'),
        explicitSchoolId: schoolId,
      );
      if (q == null) return [];
      final snap = await q.get();
      final roles =
          snap.docs.map((d) => Role.fromFirestore(d.data(), d.id)).toList();
      roles.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return roles;
    } catch (e) {
      throw Exception('Failed to get roles: $e');
    }
  }

  static Future<String> addRole(Role role) async {
    try {
      final data = role.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      final ref = await _firestore.collection('roles').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add role: $e');
    }
  }

  static Future<void> updateRole(Role role) async {
    try {
      if (role.id == null) {
        throw Exception('Role ID is required for update');
      }
      final data = role.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('roles').doc(role.id).update(data);
    } catch (e) {
      throw Exception('Failed to update role: $e');
    }
  }

  static Future<void> deleteRole(String id) async {
    try {
      await _firestore.collection('roles').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete role: $e');
    }
  }

  /// Returns every active role for [schoolId] whose `appliesTo` array
  /// contains [kind]. Defaults to the current session's school via
  /// `_scoped`.
  static Future<List<Role>> getRolesByApplyTo(
    String kind, {
    String? schoolId,
  }) async {
    final all = await getRoles(schoolId: schoolId);
    return all
        .where((r) => r.isActive && r.appliesTo.contains(kind.toLowerCase()))
        .toList();
  }

  /// Resolves the Firestore collection that backs a given `assigneeKind`
  /// value. Returns null for unknown kinds.
  static String? _collectionForKind(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case 'worker':
        return 'workers';
      case 'teacher':
        return 'teachers';
      case 'admin':
      case 'staff':
        return 'users';
      default:
        return null;
    }
  }

  /// Sets `roleId` on every person identified by [ids] in the collection
  /// matching [kind] (`worker`, `teacher`, `admin` or `staff`). Pass null
  /// or empty [roleId] to clear the assignment.
  static Future<void> setPersonsRole({
    required String kind,
    required List<String> ids,
    required String? roleId,
  }) async {
    if (ids.isEmpty) return;
    final collection = _collectionForKind(kind);
    if (collection == null) {
      throw Exception('Unknown role kind: $kind');
    }
    try {
      final batch = _firestore.batch();
      final clear = roleId == null || roleId.isEmpty;
      for (final id in ids) {
        final ref = _firestore.collection(collection).doc(id);
        if (clear) {
          batch.update(ref, {'roleId': FieldValue.delete()});
        } else {
          batch.update(ref, {'roleId': roleId});
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update role assignments: $e');
    }
  }

  /// Clears `roleId` on every person currently assigned to [roleId] across
  /// every collection that the role's [appliesTo] covers. Returns the
  /// total number of records updated.
  static Future<int> clearRoleAssignments({
    required String roleId,
    required List<String> appliesTo,
    String? schoolId,
  }) async {
    if (roleId.isEmpty || appliesTo.isEmpty) return 0;
    var total = 0;
    try {
      for (final kind in appliesTo) {
        final collection = _collectionForKind(kind);
        if (collection == null) continue;
        final base = _scopedSchool(
          _firestore.collection(collection),
          explicitSchoolId: schoolId,
        );
        if (base == null) continue;
        final snap = await base.where('roleId', isEqualTo: roleId).get();
        if (snap.docs.isEmpty) continue;
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.update(d.reference, {'roleId': FieldValue.delete()});
        }
        await batch.commit();
        total += snap.docs.length;
      }
      return total;
    } catch (e) {
      throw Exception('Failed to clear role assignments: $e');
    }
  }

  /// One-time migration that promotes legacy free-form `workers/{id}.role`
  /// strings into proper `roles/{id}` references. For every distinct
  /// `(schoolId, role)` combination not already represented in the roles
  /// collection, a new active Role doc is created (preserving the original
  /// capitalization). Then every worker is rewritten to set
  /// `roleId = matchedRoleId` and clear the legacy `role` text.
  ///
  /// Pass [schoolId] to migrate a single school (typical for school-admin
  /// callers); omit it to migrate every school in one pass (system
  /// owners).
  ///
  /// Returns a summary keyed by `rolesCreated`, `workersMigrated`,
  /// `workersSkipped`.
  static Future<Map<String, int>> migrateRoleStringsToRoleIds({
    String? schoolId,
  }) async {
    var rolesCreated = 0;
    var workersMigrated = 0;
    var workersSkipped = 0;

    try {
      // Load every role in one go (or scoped to the school).
      final existingRoles = await getRoles(schoolId: schoolId);
      // (schoolId, lowercaseName) → Role
      final roleIndex = <String, Role>{};
      for (final r in existingRoles) {
        roleIndex['${r.schoolId}::${r.name.trim().toLowerCase()}'] = r;
      }

      // Load every worker that still has a legacy role string.
      final workersQuery = _scopedSchool(
        _firestore.collection('workers'),
        explicitSchoolId: schoolId,
      );
      if (workersQuery == null) {
        return {
          'rolesCreated': rolesCreated,
          'workersMigrated': workersMigrated,
          'workersSkipped': workersSkipped,
        };
      }
      final workersSnap = await workersQuery.get();

      // First pass: ensure a Role doc exists for every distinct legacy
      // value. We do this in serial so concurrent migration calls don't
      // race to create duplicates.
      for (final doc in workersSnap.docs) {
        final data = doc.data();
        final legacy = (data['role'] as String?)?.trim() ?? '';
        if (legacy.isEmpty) continue;
        final docSchoolId = (data['schoolId'] as String?) ?? '';
        if (docSchoolId.isEmpty) continue;
        final key = '$docSchoolId::${legacy.toLowerCase()}';
        if (roleIndex.containsKey(key)) continue;
        final created = Role(
          name: legacy,
          schoolId: docSchoolId,
          appliesTo: const ['worker'],
        );
        final newId = await addRole(created);
        roleIndex[key] = created.copyWith(id: newId);
        rolesCreated++;
      }

      // Second pass: write roleId / clear legacy role on every worker.
      // Firestore batch limit is 500; chunk to be safe.
      const chunk = 400;
      final docs = workersSnap.docs;
      for (var i = 0; i < docs.length; i += chunk) {
        final slice = docs.sublist(i, (i + chunk).clamp(0, docs.length));
        final batch = _firestore.batch();
        for (final doc in slice) {
          final data = doc.data();
          final legacy = (data['role'] as String?)?.trim() ?? '';
          final docSchoolId = (data['schoolId'] as String?) ?? '';
          final hasRoleId = (data['roleId'] as String?)?.isNotEmpty ?? false;

          if (legacy.isEmpty && !hasRoleId) {
            workersSkipped++;
            continue;
          }
          if (legacy.isEmpty && hasRoleId) {
            // Already migrated — nothing to do.
            workersSkipped++;
            continue;
          }
          final key = '$docSchoolId::${legacy.toLowerCase()}';
          final role = roleIndex[key];
          if (role == null || role.id == null) {
            workersSkipped++;
            continue;
          }
          batch.update(doc.reference, {
            'roleId': role.id,
            'role': FieldValue.delete(),
          });
          workersMigrated++;
        }
        await batch.commit();
      }

      return {
        'rolesCreated': rolesCreated,
        'workersMigrated': workersMigrated,
        'workersSkipped': workersSkipped,
      };
    } catch (e) {
      throw Exception('Failed to migrate worker roles: $e');
    }
  }
}
