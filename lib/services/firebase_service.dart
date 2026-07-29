import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import '../models/school.dart';
import '../models/device.dart';
import '../models/user.dart' as app_user;
import '../models/session.dart';
import '../models/session_attendee.dart';
import '../models/session_attendance.dart';
import '../models/session_date_override.dart';
import '../models/teacher.dart';
import '../models/class_group.dart';
import '../models/system_config.dart';
import '../models/worker.dart';
import '../models/staff_time_off.dart';
import '../models/role.dart';
import '../models/device_enrollment.dart';
import 'auth_service.dart';
import 'role_constants.dart';
import 'dart:async';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Unified people collection. Teacher / worker / student records all live
  /// here, discriminated by a `kind` field.
  static const String _collection = 'members';
  static const String _messagesCollection = 'messages';

  /// Deterministic `roles/{id}` value for the auto-created per-org Guardian
  /// role (mirrors `migration/mapping.js` guardianRoleId).
  static String guardianRoleId(String orgId) => 'guardian-$orgId';

  // --- Role access-level derivation (ports migration/mapping.js) ----------

  /// Lowercase slug: drop punctuation (incl. dots), spaces -> "_", collapse.
  /// e.g. "I.T Officer" -> "it_officer".
  static String roleSlug(String name) {
    var s = name.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s;
  }

  static String _accessLevelFor(String name) {
    final s = roleSlug(name);
    if (s == 'system_owner' || s == 'admin' || s == 'school_admin') {
      return 'admin';
    }
    if (s == 'teacher' || s == 'staff') return 'staff';
    return 'viewer';
  }

  static bool _canLogIn(String accessLevel) =>
      accessLevel == 'admin' || accessLevel == 'staff';

  /// Computes the derived role fields (accessLevel / audienceKey / canLogIn)
  /// written alongside a role definition in the new schema.
  static Map<String, dynamic> _roleDerivedFields(String name) {
    final accessLevel = _accessLevelFor(name);
    return {
      'accessLevel': accessLevel,
      'audienceKey': roleSlug(name),
      'canLogIn': _canLogIn(accessLevel),
    };
  }

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
      return q.where('orgId', isEqualTo: explicitSchoolId);
    }
    final session = AuthService.currentSession;
    if (session == null || session.role == UserRole.systemOwner) {
      return q;
    }
    final schoolId = session.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return q;
    }
    return q.where('orgId', isEqualTo: schoolId);
  }

  /// School-bound collections (`devices`, `students`, …) deny unscoped list
  /// reads for non-owners in Firestore rules. Always filter by school, or skip
  /// the query when the session has no school (empty result).
  static Query<Map<String, dynamic>>? _scopedSchool(
    Query<Map<String, dynamic>> q, {
    String? explicitSchoolId,
  }) {
    if (explicitSchoolId != null) {
      return q.where('orgId', isEqualTo: explicitSchoolId);
    }
    final session = AuthService.currentSession;
    if (session == null || session.role == UserRole.systemOwner) {
      return q;
    }
    final schoolId = session.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return null;
    }
    return q.where('orgId', isEqualTo: schoolId);
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

      // Members are discriminated by `kind`; scope by `orgId`.
      studentData['kind'] = 'student';
      final orgId =
          (studentData.remove('orgId') ?? studentData.remove('schoolId'))
              as String? ??
          AuthService.currentSchoolId;
      if (orgId != null && orgId.isNotEmpty) {
        studentData['orgId'] = orgId;
      }

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
        final base = _scopedSchool(_firestore.collection(_collection));
        if (base == null) return [];
        final studentsQuery = base.where('kind', isEqualTo: 'student');
        final QuerySnapshot snapshot = await studentsQuery.get();
        return snapshot.docs.map((doc) {
          return Student.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
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

  /// Loads student `members/{id}` docs by id (used for guardian → children
  /// hydration). Chunks into `whereIn` batches of 10.
  static Future<List<Student>> getStudentsByIds(List<String> ids) async {
    final unique = ids.where((e) => e.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return [];
    final out = <Student>[];
    for (var i = 0; i < unique.length; i += 10) {
      final slice = unique.sublist(i, (i + 10).clamp(0, unique.length));
      final snap = await _firestore
          .collection(_collection)
          .where(FieldPath.documentId, whereIn: slice)
          .get();
      out.addAll(snap.docs.map((d) => Student.fromFirestore(d.data(), d.id)));
    }
    return out;
  }

  /// Assign every student member that currently has no `orgId` to [schoolId].
  /// Useful for backfilling legacy records. Returns the number updated.
  static Future<int> backfillStudentSchoolIds(String schoolId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('kind', isEqualTo: 'student')
          .get();
      final batch = _firestore.batch();
      int updated = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final orgId = data['orgId'] ?? data['schoolId'];
        if (orgId == null || (orgId as String).isEmpty) {
          batch.update(doc.reference, {'orgId': schoolId});
          updated++;
        }
      }
      if (updated > 0) {
        await batch.commit();
      }
      return updated;
    } catch (e) {
      throw Exception('Failed to backfill student orgIds: $e');
    }
  }

  /// Bulk assign a specific set of student members to [schoolId] (`orgId`),
  /// overwriting any existing value. Returns the number updated.
  static Future<int> assignStudentsToSchool(
    List<String> studentIds,
    String schoolId,
  ) async {
    if (studentIds.isEmpty) return 0;
    try {
      final batch = _firestore.batch();
      for (final id in studentIds) {
        batch.update(_firestore.collection(_collection).doc(id), {
          'orgId': schoolId,
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
        'memberId': studentId,
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

  // Get messages for a specific student. Sort client-side so we do not need a
  // composite index on memberId + timestamp (legacy indexes use studentId).
  static Stream<List<Message>> getMessagesStream(String studentId) {
    Stream<List<Message>> streamForField(String field) {
      return _firestore
          .collection(_messagesCollection)
          .where(field, isEqualTo: studentId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();
          });
    }

    try {
      return Stream.multi((controller) {
        var memberMessages = <Message>[];
        var legacyMessages = <Message>[];

        void emitMerged() {
          final byId = <String, Message>{
            for (final message in [...memberMessages, ...legacyMessages])
              message.id: message,
          };
          final merged = byId.values.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(merged);
        }

        final subscriptions = <StreamSubscription<List<Message>>>[
          streamForField('memberId').listen(
            (messages) {
              memberMessages = messages;
              emitMerged();
            },
            onError: controller.addError,
          ),
          streamForField('studentId').listen(
            (messages) {
              legacyMessages = messages;
              emitMerged();
            },
            onError: controller.addError,
          ),
        ];

        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
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
    final fromSender =
        recipient == MessageSender.school
            ? MessageSender.parent
            : MessageSender.school;

    int countUnread(List<Message> messages) {
      return messages
          .where((message) => !message.isRead && message.sender == fromSender)
          .length;
    }

    try {
      return getMessagesStream(studentId).map(countUnread);
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
              final studentId =
                  (data['memberId'] ?? data['studentId']) as String?;
              if (studentId == null) continue;
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
              .where('kind', isEqualTo: 'student')
              .where('registrationNumber', isEqualTo: studentNumber)
              .get();

      return snapshot.docs.map((doc) {
        return Student.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
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

      final Set<String> seenIds = {};
      final List<Student> students = [];

      // Match against both guardian contact slots (new schema) plus the
      // legacy father/mother phone keys for any not-yet-migrated docs.
      for (final field in const [
        'guardianPhone',
        'guardianPhone2',
        'fatherPhone',
        'motherPhone',
      ]) {
        final snap = await _firestore
            .collection(_collection)
            .where('kind', isEqualTo: 'student')
            .where(field, isEqualTo: normalizedPhone)
            .get();
        for (final doc in snap.docs) {
          if (seenIds.add(doc.id)) {
            students.add(Student.fromFirestore(doc.data(), doc.id));
          }
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
          _firestore.collection('organizations').doc(schoolId),
        );
        if (!doc.exists || doc.data() == null) {
          if (schoolId == AuthService.demoSchoolId) {
            return [School(id: AuthService.demoSchoolId, name: 'Demo School')];
          }
          return [];
        }
        return [School.fromFirestore(doc.data()!, doc.id)];
      }

      final QuerySnapshot snapshot = await _getWithAuthRetry(
        _firestore.collection('organizations'),
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
      await _firestore.collection('organizations').add(data);
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
          .collection('organizations')
          .doc(school.id)
          .update(school.toFirestore());
    } catch (e) {
      throw Exception('Failed to update school: $e');
    }
  }

  // Delete a school
  static Future<void> deleteSchool(String schoolId) async {
    try {
      await _firestore.collection('organizations').doc(schoolId).delete();
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
        final doc = existing.docs.first;
        final data = doc.data();
        final updateData = <String, dynamic>{
          'role': role,
          if (name != null && name.isNotEmpty) 'name': name,
          if (schoolId != null) 'orgId': schoolId,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
          'isActive': true,
        };

        final hasPasswordHash =
            (data['passwordHash'] as String?)?.isNotEmpty ?? false;
        if (!hasPasswordHash && password.isNotEmpty) {
          final salt = AuthService.generateSalt();
          updateData
            ..['passwordSalt'] = salt
            ..['passwordHash'] = AuthService.hashPassword(password, salt)
            ..['password'] = FieldValue.delete()
            ..['temporaryPassword'] = FieldValue.delete()
            ..['passwordUpdatedAt'] = FieldValue.serverTimestamp();
        }

        await doc.reference.update(updateData);
        return doc.id;
      }

      final salt = AuthService.generateSalt();
      final doc = await _firestore.collection('users').add({
        'email': normalizedEmail,
        'passwordSalt': salt,
        'passwordHash': AuthService.hashPassword(password, salt),
        if (name != null && name.isNotEmpty) 'name': name,
        'role': role,
        if (schoolId != null) 'orgId': schoolId,
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
              .where('orgId', isEqualTo: schoolId)
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
                .where('orgId', isEqualTo: schoolId)
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
      final base = _scopedSchool(
        _firestore.collection(_collection),
        explicitSchoolId: schoolId,
      );
      if (base == null) return [];
      final snap = await base.where('kind', isEqualTo: 'teacher').get();
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
      final ref = await _firestore.collection(_collection).add(data);
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
      await _firestore.collection(_collection).doc(teacher.id).update(data);
    } catch (e) {
      throw Exception('Failed to update teacher: $e');
    }
  }

  static Future<void> deleteTeacher(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete teacher: $e');
    }
  }

  // CLASSES

  static Future<List<ClassGroup>> getClasses({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('groups'),
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
      final ref = await _firestore.collection('groups').add(data);
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
          .collection('groups')
          .doc(group.id)
          .update(group.toFirestore());
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  static Future<void> deleteClass(String id) async {
    try {
      await _firestore.collection('groups').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  static Future<void> assignStudentsToClass(
    String classId,
    List<String> studentIds,
  ) async {
    try {
      await _firestore.collection('groups').doc(classId).update({
        'memberIds': studentIds,
      });
    } catch (e) {
      throw Exception('Failed to assign students to class: $e');
    }
  }

  // GUARDIANS (parent login accounts; live in `users`)

  /// Normalize a phone number for matching: strip spaces and a leading
  /// `+250` country code so `+250 78…`, `078…`, and `78…` compare equal.
  static String normalizePhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+250')) p = p.substring(4);
    if (p.startsWith('250') && p.length > 9) p = p.substring(3);
    return p;
  }

  /// Lists guardian (parent) login accounts. A guardian is any `users` doc
  /// flagged by [AppUser.isGuardian]. Scoped to the caller's org.
  static Future<List<app_user.AppUser>> getGuardians({String? schoolId}) async {
    try {
      final q = _scoped(
        _firestore.collection('users'),
        explicitSchoolId: schoolId,
      );
      final snap = await q.get();
      return snap.docs
          .map((d) => app_user.AppUser.fromFirestore(d.data(), d.id))
          .where((u) => u.isGuardian)
          .toList();
    } catch (e) {
      throw Exception('Failed to get guardians: $e');
    }
  }

  /// Creates a guardian login account in `users`. When [password] is given,
  /// stores a salted hash so the guardian can sign in by phone immediately.
  static Future<String> addGuardian({
    required String name,
    required String phone,
    List<String> linkedStudentIds = const [],
    String? schoolId,
    String? password,
  }) async {
    try {
      final orgId =
          (schoolId == null || schoolId.isEmpty)
              ? AuthService.currentSchoolId
              : schoolId;
      final data = <String, dynamic>{
        'role': 'parent',
        if (name.trim().isNotEmpty) 'name': name.trim(),
        'phone': normalizePhone(phone),
        if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
        if (orgId != null && orgId.isNotEmpty) 'roleId': guardianRoleId(orgId),
        'linkedStudentIds': linkedStudentIds,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (password != null && password.isNotEmpty) {
        final salt = AuthService.generateSalt();
        data['passwordSalt'] = salt;
        data['passwordHash'] = AuthService.hashPassword(password, salt);
        data['passwordUpdatedAt'] = FieldValue.serverTimestamp();
      }
      final ref = await _firestore.collection('users').add(data);
      return ref.id;
    } catch (e) {
      throw Exception('Failed to add guardian: $e');
    }
  }

  /// Updates a guardian's profile fields (name / phone / linked students).
  static Future<void> updateGuardian(app_user.AppUser guardian) async {
    try {
      if (guardian.id == null) {
        throw Exception('Guardian ID is required for update');
      }
      final data = <String, dynamic>{
        'name': guardian.name,
        'phone': normalizePhone(guardian.phone ?? ''),
        'linkedStudentIds': guardian.linkedStudentIds,
        'isActive': guardian.isActive,
        if (guardian.schoolId != null) 'orgId': guardian.schoolId,
        if (guardian.schoolId != null)
          'roleId': guardianRoleId(guardian.schoolId!),
      };
      await _firestore.collection('users').doc(guardian.id).update(data);
    } catch (e) {
      throw Exception('Failed to update guardian: $e');
    }
  }

  static Future<void> deleteGuardian(String id) async {
    try {
      await _firestore.collection('users').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete guardian: $e');
    }
  }

  /// Sets (or resets) a guardian's login password.
  static Future<void> setGuardianPassword(
    String userId,
    String password,
  ) async {
    try {
      final salt = AuthService.generateSalt();
      await _firestore.collection('users').doc(userId).update({
        'passwordSalt': salt,
        'passwordHash': AuthService.hashPassword(password, salt),
        'password': FieldValue.delete(),
        'temporaryPassword': FieldValue.delete(),
        'mustChangePassword': false,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to set guardian password: $e');
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

  // SESSION ATTENDANCE -------------------------------------------------------
  //
  // Per-session/per-occurrence attendance lives in the top-level `attendance`
  // collection (deterministic doc ids — see SessionAttendanceRecord.makeDocId)
  // so manual marks and device-fed scans upsert idempotently. Manual records
  // are authoritative; device ingestion never clobbers them.

  /// Parses an `HH:mm` string to minutes-since-midnight, or null when the
  /// value is missing/malformed.
  static int? _minutesFromHHmm(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Present-vs-late for a [checkInTime] (`HH:mm`) measured against the
  /// session's effective late cutoff on [day]. A null/blank check-in (or no
  /// configured late time) is treated as present.
  static AttendanceStatus statusFromCheckIn(
    Session session,
    DateTime day,
    String? checkInTime,
  ) {
    final lateMinutes = _minutesFromHHmm(
      session.effectiveTimesFor(day).lateTime,
    );
    final checkMinutes = _minutesFromHHmm(checkInTime);
    if (lateMinutes == null || checkMinutes == null) {
      return AttendanceStatus.present;
    }
    return checkMinutes > lateMinutes
        ? AttendanceStatus.late
        : AttendanceStatus.present;
  }

  static Future<List<Student>> _fetchStudentsForSchool(String? schoolId) async {
    final base = _scopedSchool(
      _firestore.collection(_collection),
      explicitSchoolId: schoolId,
    );
    if (base == null) return [];
    final snap = await base.where('kind', isEqualTo: 'student').get();
    return snap.docs
        .map((d) => Student.fromFirestore(d.data(), d.id))
        .toList();
  }

  static Future<List<app_user.AppUser>> _fetchUsersForSchool(
    String? schoolId,
  ) async {
    final snap =
        await _scoped(
          _firestore.collection('users'),
          explicitSchoolId: schoolId,
        ).get();
    return snap.docs
        .map((d) => app_user.AppUser.fromFirestore(d.data(), d.id))
        .toList();
  }

  /// Resolves everyone expected at [session] on [day] into a de-duplicated,
  /// name-sorted roster, unioning three audience sources:
  ///   * students in the session's classes plus students whose `sessionIds`
  ///     reference this session,
  ///   * everyone currently in each role in `session.audienceRoles`
  ///     (built-in `teacher`/`admin`/`staff`/`worker` or a custom role name),
  ///   * individually-picked `session.attendees`.
  static Future<List<SessionAttendee>> resolveSessionRoster(
    Session session, [
    DateTime? day,
  ]) async {
    final schoolId = session.schoolId.isEmpty ? null : session.schoolId;

    // Kick off every catalog read in parallel (each scoped to the school).
    final studentsF = _fetchStudentsForSchool(schoolId);
    final classesF = getClasses(schoolId: schoolId);
    final teachersF = getTeachers(schoolId: schoolId);
    final workersF = getWorkers(schoolId: schoolId);
    final usersF = _fetchUsersForSchool(schoolId);
    final rolesF = getRoles(schoolId: schoolId);

    return _buildRoster(
      session: session,
      students: await studentsF,
      classes: await classesF,
      teachers: await teachersF,
      workers: await workersF,
      users: await usersF,
      roles: await rolesF,
    );
  }

  /// Pure roster resolution from pre-loaded catalogs. Shared by
  /// [resolveSessionRoster] (single session) and [ingestDeviceScans] (which
  /// loads the catalogs once and resolves many sessions). Membership is
  /// day-independent, so no occurrence date is needed here.
  static List<SessionAttendee> _buildRoster({
    required Session session,
    required List<Student> students,
    required List<ClassGroup> classes,
    required List<Teacher> teachers,
    required List<Worker> workers,
    required List<app_user.AppUser> users,
    required List<Role> roles,
  }) {
    // Defensive school filter so a roster never picks up another school's
    // people even when callers pass catalogs spanning multiple schools (e.g.
    // the owner-wide device-scan sync). Students carry no schoolId, but they
    // only enter via this school's classes or via session-id linkage, both of
    // which are inherently school-correct.
    final sid = session.schoolId;
    bool sameSchool(String? other) => sid.isEmpty || other == sid;

    final roster = <String, SessionAttendee>{};
    void add(SessionAttendee a) {
      if (a.id.isEmpty) return;
      roster.putIfAbsent(a.compoundKey, () => a);
    }

    // --- Students: classes + explicit session linkage -----------------------
    if (session.classIds.isNotEmpty || students.isNotEmpty) {
      final studentById = {
        for (final s in students)
          if (s.id != null) s.id!: s,
      };
      final targetStudentIds = <String>{};
      if (session.classIds.isNotEmpty) {
        final classIdSet = session.classIds.toSet();
        for (final c in classes) {
          if (c.id != null &&
              classIdSet.contains(c.id) &&
              sameSchool(c.schoolId)) {
            targetStudentIds.addAll(c.studentIds);
          }
        }
      }
      for (final s in students) {
        if (s.id != null && session.id != null &&
            s.sessionIds.contains(session.id)) {
          targetStudentIds.add(s.id!);
        }
      }
      for (final id in targetStudentIds) {
        final s = studentById[id];
        if (s == null) continue;
        add(SessionAttendee(
          kind: 'student',
          id: id,
          name: s.name,
          roleKey: 'student',
        ));
      }
    }

    // --- Whole roles --------------------------------------------------------
    bool isSchoolAdminRole(String? role) => AuthRoles.isSchoolAdmin(role);

    for (final rawKey in session.audienceRoles) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      final lower = key.toLowerCase();
      switch (lower) {
        case 'teacher':
          for (final t in teachers) {
            if (t.isActive && t.id != null && sameSchool(t.schoolId)) {
              add(SessionAttendee(
                kind: 'teacher',
                id: t.id!,
                name: t.name,
                roleKey: 'teacher',
              ));
            }
          }
          break;
        case 'admin':
          for (final u in users) {
            if (u.isActive &&
                u.id != null &&
                isSchoolAdminRole(u.role) &&
                sameSchool(u.schoolId)) {
              add(SessionAttendee(
                kind: 'admin',
                id: u.id!,
                name: (u.name?.trim().isNotEmpty ?? false) ? u.name!.trim() : u.email,
                roleKey: 'admin',
              ));
            }
          }
          break;
        case 'staff':
          for (final u in users) {
            if (u.isActive &&
                u.id != null &&
                AuthRoles.isStaff(u.role) &&
                sameSchool(u.schoolId)) {
              add(SessionAttendee(
                kind: 'staff',
                id: u.id!,
                name: (u.name?.trim().isNotEmpty ?? false) ? u.name!.trim() : u.email,
                roleKey: 'staff',
              ));
            }
          }
          break;
        case 'worker':
          for (final w in workers) {
            if (w.isActive && w.id != null && sameSchool(w.schoolId)) {
              add(SessionAttendee(
                kind: 'worker',
                id: w.id!,
                name: w.name,
                roleKey: 'worker',
              ));
            }
          }
          break;
        default:
          // Custom role: match by roleId (current scheme) across workers /
          // teachers / users, and by the legacy free-form worker role text.
          final roleIds = roles
              .where((r) =>
                  r.id != null &&
                  r.name.toLowerCase() == lower &&
                  sameSchool(r.schoolId))
              .map((r) => r.id!)
              .toSet();
          for (final w in workers) {
            if (!w.isActive || w.id == null || !sameSchool(w.schoolId)) {
              continue;
            }
            final byId = w.roleId != null && roleIds.contains(w.roleId);
            final byLegacy = (w.role ?? '').trim().toLowerCase() == lower;
            if (byId || byLegacy) {
              add(SessionAttendee(
                kind: 'worker',
                id: w.id!,
                name: w.name,
                roleKey: key,
              ));
            }
          }
          for (final t in teachers) {
            if (t.isActive &&
                t.id != null &&
                sameSchool(t.schoolId) &&
                t.roleId != null &&
                roleIds.contains(t.roleId)) {
              add(SessionAttendee(
                kind: 'teacher',
                id: t.id!,
                name: t.name,
                roleKey: key,
              ));
            }
          }
          for (final u in users) {
            if (!u.isActive || u.id == null || !sameSchool(u.schoolId)) {
              continue;
            }
            if (u.roleId != null && roleIds.contains(u.roleId)) {
              final kind = AuthRoles.isStaff(u.role) ? 'staff' : 'admin';
              add(SessionAttendee(
                kind: kind,
                id: u.id!,
                name: (u.name?.trim().isNotEmpty ?? false) ? u.name!.trim() : u.email,
                roleKey: key,
              ));
            }
          }
      }
    }

    // --- Individually-picked attendees -------------------------------------
    for (final a in session.attendees) {
      add(a);
    }

    final list = roster.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// All attendance records for one occurrence (`sessionId` + `dateKey`).
  ///
  /// Filters on the auto-indexed `sessionId` field and narrows `dateKey`
  /// client-side, so reads keep working even before the composite index is
  /// deployed.
  static Future<List<SessionAttendanceRecord>> getSessionAttendance(
    String sessionId,
    String dateKey,
  ) async {
    try {
      final snap = await _firestore
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      return snap.docs
          .map((d) => SessionAttendanceRecord.fromFirestore(d.data(), d.id))
          .where((r) => r.dateKey == dateKey)
          .toList();
    } catch (e) {
      throw Exception('Failed to get session attendance: $e');
    }
  }

  /// Attendance records for the caller's school (optionally [schoolId]),
  /// limited to occurrences on/after [sinceDateKey] when provided. Used by the
  /// dashboard and reports to aggregate per-session attendance. Returns an
  /// empty list on permission errors so it can ride inside `Future.wait`.
  static Future<List<SessionAttendanceRecord>> getSchoolAttendance({
    String? schoolId,
    String? sinceDateKey,
  }) async {
    try {
      final base = _scopedSchool(
        _firestore.collection('attendance'),
        explicitSchoolId: schoolId,
      );
      if (base == null) return [];
      final snap = await base.get();
      var records = snap.docs
          .map((d) => SessionAttendanceRecord.fromFirestore(d.data(), d.id))
          .toList();
      if (sinceDateKey != null) {
        records =
            records.where((r) => r.dateKey.compareTo(sinceDateKey) >= 0).toList();
      }
      return records;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return const [];
      throw Exception('Failed to get school attendance: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to get school attendance: $e');
    }
  }

  /// Idempotent upsert of one attendance record (deterministic doc id).
  static Future<void> upsertSessionAttendance(
    SessionAttendanceRecord record,
  ) async {
    try {
      final docId = SessionAttendanceRecord.makeDocId(
        sessionId: record.sessionId,
        dateKey: record.dateKey,
        personKind: record.personKind,
        personId: record.personId,
      );
      await _firestore
          .collection('attendance')
          .doc(docId)
          .set(record.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save attendance: $e');
    }
  }

  /// Batched idempotent upsert; stays within Firestore's 500-write batch cap.
  static Future<void> bulkUpsertSessionAttendance(
    List<SessionAttendanceRecord> records,
  ) async {
    if (records.isEmpty) return;
    try {
      const batchLimit = 400;
      for (var i = 0; i < records.length; i += batchLimit) {
        final batch = _firestore.batch();
        final end = (i + batchLimit).clamp(0, records.length);
        for (final r in records.sublist(i, end)) {
          final docId = SessionAttendanceRecord.makeDocId(
            sessionId: r.sessionId,
            dateKey: r.dateKey,
            personKind: r.personKind,
            personId: r.personId,
          );
          batch.set(
            _firestore.collection('attendance').doc(docId),
            r.toFirestore(),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to save attendance: $e');
    }
  }

  /// Deletes every attendance record for one occurrence.
  static Future<void> clearSessionAttendance(
    String sessionId,
    String dateKey,
  ) async {
    try {
      final snap = await _firestore
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      final docs = snap.docs
          .where((d) => (d.data()['dateKey'] ?? '').toString() == dateKey)
          .toList();
      if (docs.isEmpty) return;
      const batchLimit = 400;
      for (var i = 0; i < docs.length; i += batchLimit) {
        final batch = _firestore.batch();
        final end = (i + batchLimit).clamp(0, docs.length);
        for (final d in docs.sublist(i, end)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to clear attendance: $e');
    }
  }

  /// Ingests fingerprint-device scans from `api_logs` into per-session
  /// attendance. For each successful scan it resolves the scanner to a person,
  /// finds the sessions occurring that day whose roster includes the person,
  /// and upserts a `device` attendance record (present/late computed from the
  /// session's effective late cutoff). Manual records are never overwritten;
  /// when several scans land on the same occurrence the earliest check-in
  /// wins.
  ///
  /// Returns a summary map: `scans`, `matched`, `written`, `skippedManual`.
  static Future<Map<String, int>> ingestDeviceScans({
    DateTime? since,
    String? schoolId,
  }) async {
    final sinceTime = since ?? DateTime.now().subtract(const Duration(days: 1));
    final summary = <String, int>{
      'scans': 0,
      'matched': 0,
      'written': 0,
      'skippedManual': 0,
    };

    // 1. Recent scans. Optional feature -> swallow permission errors.
    List<QueryDocumentSnapshot<Map<String, dynamic>>> logDocs;
    try {
      final snap = await _firestore
          .collection('api_logs')
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();
      logDocs = snap.docs;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return summary;
      rethrow;
    }
    if (logDocs.isEmpty) return summary;

    final effectiveSchoolId = (schoolId == null || schoolId.isEmpty)
        ? AuthService.currentSchoolId
        : schoolId;

    final sessions = await getSessions(schoolId: effectiveSchoolId);
    if (sessions.isEmpty) return summary;

    // 2. Load every catalog once.
    final studentsF = _fetchStudentsForSchool(effectiveSchoolId);
    final classesF = getClasses(schoolId: effectiveSchoolId);
    final teachersF = getTeachers(schoolId: effectiveSchoolId);
    final workersF = getWorkers(schoolId: effectiveSchoolId);
    final usersF = _fetchUsersForSchool(effectiveSchoolId);
    final rolesF = getRoles(schoolId: effectiveSchoolId);
    final enrollBase = _scopedSchool(
      _firestore.collection('device_enrollments'),
      explicitSchoolId: effectiveSchoolId,
    );
    final enrollF = enrollBase?.get();

    final students = await studentsF;
    final classes = await classesF;
    final teachers = await teachersF;
    final workers = await workersF;
    final users = await usersF;
    final roles = await rolesF;
    final enrollSnap = enrollF == null ? null : await enrollF;
    final enrollments = enrollSnap == null
        ? <DeviceEnrollment>[]
        : enrollSnap.docs
            .map((d) => DeviceEnrollment.fromFirestore(d.data(), d.id))
            .toList();

    // 3. Person catalogs for scan -> person resolution.
    final byMemberId = <String, ({String kind, String id, String name})>{};
    final byNameLower = <String, ({String kind, String id, String name})>{};
    void register(String kind, String? id, String name) {
      if (id == null || id.isEmpty) return;
      final p = (kind: kind, id: id, name: name);
      byMemberId[id] = p;
      final nl = name.trim().toLowerCase();
      if (nl.isNotEmpty) byNameLower.putIfAbsent(nl, () => p);
    }
    for (final s in students) {
      register('student', s.id, s.name);
    }
    for (final t in teachers) {
      register('teacher', t.id, t.name);
    }
    for (final w in workers) {
      register('worker', w.id, w.name);
    }
    for (final u in users) {
      final kind = AuthRoles.isStaff(u.role)
          ? 'staff'
          : (AuthRoles.isSchoolAdmin(u.role) ? 'admin' : null);
      if (kind != null) {
        register(
          kind,
          u.id,
          (u.name?.trim().isNotEmpty ?? false) ? u.name!.trim() : u.email,
        );
      }
    }

    final enrollBySlot = <String, DeviceEnrollment>{};
    final enrollByCard = <String, DeviceEnrollment>{};
    for (final e in enrollments) {
      enrollBySlot['${e.deviceId}_${e.slotId}'] = e;
      if (e.cardId.isNotEmpty) enrollByCard[e.cardId] = e;
    }

    // 4. Resolve each session's roster once; index person -> (session, role).
    final personToHits =
        <String, List<({Session session, String? roleKey})>>{};
    for (final s in sessions) {
      if (s.id == null) continue;
      final roster = _buildRoster(
        session: s,
        students: students,
        classes: classes,
        teachers: teachers,
        workers: workers,
        users: users,
        roles: roles,
      );
      for (final a in roster) {
        personToHits
            .putIfAbsent(a.compoundKey, () => [])
            .add((session: s, roleKey: a.roleKey));
      }
    }
    if (personToHits.isEmpty) return summary;

    ({String kind, String id, String name})? resolve(
      Map<String, dynamic> log,
    ) {
      final memberId = (log['studentId'] ?? log['memberId'] ?? '').toString();
      if (memberId.isNotEmpty && byMemberId.containsKey(memberId)) {
        return byMemberId[memberId];
      }
      final deviceId = (log['deviceId'] ?? '').toString();
      final slot = log['slotId'] ?? log['userId'];
      if (deviceId.isNotEmpty && slot != null) {
        final e = enrollBySlot['${deviceId}_$slot'];
        final hit = e == null ? null : byNameLower[e.name.trim().toLowerCase()];
        if (hit != null) return hit;
      }
      final cardId = (log['cardId'] ?? '').toString();
      if (cardId.isNotEmpty) {
        final e = enrollByCard[cardId];
        final hit = e == null ? null : byNameLower[e.name.trim().toLowerCase()];
        if (hit != null) return hit;
      }
      final name =
          (log['studentName'] ?? log['userName'] ?? log['name'] ?? '')
              .toString();
      if (name.trim().isNotEmpty) {
        return byNameLower[name.trim().toLowerCase()];
      }
      return null;
    }

    // 5. Build proposed device records (earliest check-in wins per doc).
    final proposed = <String, SessionAttendanceRecord>{};
    final earliestMins = <String, int>{};
    final touched = <String>{}; // 'sessionId|dateKey'

    for (final doc in logDocs) {
      final log = doc.data();
      if (log['success'] == false) continue;
      final ts = log['timestamp'];
      DateTime? when;
      if (ts is Timestamp) {
        when = ts.toDate();
      } else if (ts is String) {
        when = DateTime.tryParse(ts);
      }
      if (when == null || when.isBefore(sinceTime)) continue;
      summary['scans'] = (summary['scans'] ?? 0) + 1;

      final p = resolve(log);
      if (p == null) continue;
      final hits = personToHits['${p.kind}:${p.id}'];
      if (hits == null) continue;
      summary['matched'] = (summary['matched'] ?? 0) + 1;

      final day = DateTime(when.year, when.month, when.day);
      final dateKey = SessionDateOverride.formatDateKey(day);
      final checkIn =
          '${when.hour.toString().padLeft(2, '0')}:'
          '${when.minute.toString().padLeft(2, '0')}';
      final mins = when.hour * 60 + when.minute;

      for (final hit in hits) {
        final s = hit.session;
        if (!s.occursAndNotSkipped(day)) continue;
        final docId = SessionAttendanceRecord.makeDocId(
          sessionId: s.id!,
          dateKey: dateKey,
          personKind: p.kind,
          personId: p.id,
        );
        touched.add('${s.id}|$dateKey');
        if (proposed.containsKey(docId) &&
            (earliestMins[docId] ?? 1 << 30) <= mins) {
          continue; // an earlier scan already covers this occurrence
        }
        proposed[docId] = SessionAttendanceRecord(
          schoolId: s.schoolId,
          sessionId: s.id!,
          dateKey: dateKey,
          personId: p.id,
          personKind: p.kind,
          personName: p.name,
          roleKey: hit.roleKey,
          status: statusFromCheckIn(s, day, checkIn),
          source: AttendanceSource.device,
          checkInTime: checkIn,
        );
        earliestMins[docId] = mins;
      }
    }

    if (proposed.isEmpty) return summary;

    // 6. Load existing records for touched occurrences; manual records win.
    final manualDocIds = <String>{};
    for (final sd in touched) {
      final sep = sd.indexOf('|');
      if (sep < 0) continue;
      final sid = sd.substring(0, sep);
      final dk = sd.substring(sep + 1);
      final recs = await getSessionAttendance(sid, dk);
      for (final r in recs) {
        if (r.id != null && r.source == AttendanceSource.manual) {
          manualDocIds.add(r.id!);
        }
      }
    }

    final toWrite = <SessionAttendanceRecord>[];
    for (final entry in proposed.entries) {
      if (manualDocIds.contains(entry.key)) {
        summary['skippedManual'] = (summary['skippedManual'] ?? 0) + 1;
        continue;
      }
      toWrite.add(entry.value);
    }

    if (toWrite.isNotEmpty) {
      await bulkUpsertSessionAttendance(toWrite);
      summary['written'] = toWrite.length;
    }
    return summary;
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

    final schoolsSnap = await _firestore.collection('organizations').get();
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
    final studentsSnap = await _firestore
        .collection(_collection)
        .where('kind', isEqualTo: 'student')
        .get();
    for (final studentDoc in studentsSnap.docs) {
      final data = studentDoc.data();
      final legacyPeriod = data['period'] as String?;
      if (legacyPeriod == null) continue;
      final schoolId = (data['orgId'] ?? data['schoolId']) as String?;
      final mapping =
          schoolId == null ? null : schoolPeriodToSessionId[schoolId];
      final existing =
          ((data['legacySessionIds'] ?? data['sessionIds']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final sessionId = mapping?[legacyPeriod];
      final List<String> nextIds = [...existing];
      if (sessionId != null && !nextIds.contains(sessionId)) {
        nextIds.add(sessionId);
      }
      await studentDoc.reference.update({
        'legacySessionIds': nextIds,
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
      final base = _scopedSchool(
        _firestore.collection(_collection),
        explicitSchoolId: schoolId,
      );
      if (base == null) return [];
      final snap = await base.where('kind', isEqualTo: 'worker').get();
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
      final ref = await _firestore.collection(_collection).add(data);
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
      // superseded by roleId. Clear both the old `role` key and the
      // migrated `legacyRoleLabel` so reads no longer fall back to it.
      data['role'] = FieldValue.delete();
      data['legacyRoleLabel'] = FieldValue.delete();
      await _firestore.collection(_collection).doc(worker.id).update(data);
    } catch (e) {
      throw Exception('Failed to update worker: $e');
    }
  }

  static Future<void> deleteWorker(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete worker: $e');
    }
  }

  static Future<List<StaffTimeOff>> getStaffTimeOffs({String? schoolId}) async {
    try {
      final q = _scopedSchool(
        _firestore.collection('time_off'),
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
      final doc = _firestore.collection('time_off').doc();
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
      // Legacy worker mirror keys are no longer written; clear any that
      // survive on pre-migration docs.
      data['workerId'] = FieldValue.delete();
      data['workerName'] = FieldValue.delete();
      data['assigneeId'] = FieldValue.delete();
      data['assigneeName'] = FieldValue.delete();
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
      await _firestore.collection('time_off').doc(entry.id).update(data);
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
      await _firestore.collection('time_off').doc(entry.id).delete();
    } catch (e) {
      throw Exception('Failed to delete staff time off: $e');
    }
  }

  // ROLES (custom, school-scoped role definitions)

  static Future<List<Role>> getRoles({String? schoolId}) async {
    try {
      final session = AuthService.currentSession;
      final isOwner = session?.role == UserRole.systemOwner;

      if (isOwner) {
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
      }

      // School admins: filter client-side so legacy docs with empty or
      // mismatched `schoolId` still appear for the active school.
      final targetSchoolId = schoolId ?? session?.schoolId;
      if (targetSchoolId == null || targetSchoolId.isEmpty) return [];

      final snap = await _firestore.collection('roles').get();
      final roles =
          snap.docs
              .map((d) => Role.fromFirestore(d.data(), d.id))
              .where(
                (r) => r.schoolId.isEmpty || r.schoolId == targetSchoolId,
              )
              .toList();
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
      var schoolId = role.schoolId;
      if (schoolId.isEmpty) {
        schoolId = AuthService.currentSchoolId ?? '';
      }
      if (schoolId.isEmpty) {
        throw Exception('A school is required to create a role');
      }
      final data = role.copyWith(schoolId: schoolId).toFirestore();
      data.addAll(_roleDerivedFields(role.name));
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
      data.addAll(_roleDerivedFields(role.name));
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

  /// Resolves the Firestore collection that backs a given `assigneeKind`
  /// value. Returns null for unknown kinds.
  static String? _collectionForKind(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case 'worker':
      case 'teacher':
      case 'student':
        return _collection; // unified `members`
      case 'admin':
      case 'staff':
      case 'guardian':
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
  /// workers, teachers, and admin/staff users. Returns the total number of
  /// records updated.
  static Future<int> clearRoleAssignments({
    required String roleId,
    String? schoolId,
  }) async {
    if (roleId.isEmpty) return 0;
    var total = 0;
    try {
      for (final kind in AuthRoles.allKinds) {
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

      // Load every worker member that still has a legacy role string.
      final workersBase = _scopedSchool(
        _firestore.collection(_collection),
        explicitSchoolId: schoolId,
      );
      if (workersBase == null) {
        return {
          'rolesCreated': rolesCreated,
          'workersMigrated': workersMigrated,
          'workersSkipped': workersSkipped,
        };
      }
      final workersSnap =
          await workersBase.where('kind', isEqualTo: 'worker').get();

      // First pass: ensure a Role doc exists for every distinct legacy
      // value. We do this in serial so concurrent migration calls don't
      // race to create duplicates.
      for (final doc in workersSnap.docs) {
        final data = doc.data();
        final legacy =
            ((data['legacyRoleLabel'] ?? data['role']) as String?)?.trim() ??
            '';
        if (legacy.isEmpty) continue;
        final docSchoolId = ((data['orgId'] ?? data['schoolId']) as String?) ?? '';
        if (docSchoolId.isEmpty) continue;
        final key = '$docSchoolId::${legacy.toLowerCase()}';
        if (roleIndex.containsKey(key)) continue;
        final created = Role(
          name: legacy,
          schoolId: docSchoolId,
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
          final legacy =
              ((data['legacyRoleLabel'] ?? data['role']) as String?)?.trim() ??
              '';
          final docSchoolId =
              ((data['orgId'] ?? data['schoolId']) as String?) ?? '';
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
            'legacyRoleLabel': FieldValue.delete(),
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
