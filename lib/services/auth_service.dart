import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parent.dart' as app_parent;
import '../models/student.dart';
import '../models/user.dart' as app_user;
import 'firebase_service.dart';

/// Application-level user roles. Kept in sync with the `role` field stored on
/// `users/{uid}` Firestore documents.
enum UserRole {
  parent,
  teacher,
  schoolAdmin,
  systemOwner,
}

UserRole? _parseUserRole(String? role) {
  switch (role) {
    case 'system_owner':
    case 'systemOwner':
      return UserRole.systemOwner;
    case 'admin':
    case 'school_admin':
    case 'schoolAdmin':
      return UserRole.schoolAdmin;
    case 'teacher':
      return UserRole.teacher;
    case 'parent':
      return UserRole.parent;
    default:
      return null;
  }
}

String userRoleToFirestore(UserRole role) {
  switch (role) {
    case UserRole.systemOwner:
      return 'system_owner';
    case UserRole.schoolAdmin:
      return 'admin';
    case UserRole.teacher:
      return 'teacher';
    case UserRole.parent:
      return 'parent';
  }
}

/// Result returned by [AuthService.signIn] and related helpers describing who
/// is currently signed in.
class AuthSession {
  final UserRole role;
  final String? uid;
  final String? email;
  final String? schoolId;
  final String? studentNumber;
  final String? name;

  /// For parent sessions, the students that this phone/student-number resolved
  /// to. Empty list for admin roles.
  final List<Student> students;

  const AuthSession({
    required this.role,
    this.uid,
    this.email,
    this.schoolId,
    this.studentNumber,
    this.name,
    this.students = const [],
  });
}

/// Centralized authentication service. Handles:
///  - Email+password sign-in for admin/staff roles (Firebase Auth).
///  - Student-number based sign-in for parents (derived from students /
///    parents collections).
///  - Resolving the caller's role and schoolId from the `users/{uid}` doc.
///  - Exposing the current session for school-scoped queries elsewhere in
///    the app (see FirebaseService._scoped).
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static AuthSession? _current;

  /// Demo email-based credentials kept to make first-run exploration easy.
  /// If Firebase Auth sign-in fails with these exact credentials we fall
  /// back to a synthetic session so the UI remains reachable without seeding.
  static const Map<UserRole, Map<String, String>> _demoCredentials = {
    UserRole.systemOwner: {'email': 'owner@school.com', 'password': 'owner123'},
    UserRole.schoolAdmin: {'email': 'admin@school.com', 'password': 'admin123'},
    UserRole.teacher: {'email': 'teacher@school.com', 'password': 'teacher123'},
  };
  static const String demoParentStudentNumber = 'STD001';
  static const String demoParentPassword = 'parent123';

  static AuthSession? get currentSession => _current;
  static UserRole? get currentRole => _current?.role;
  static String? get currentSchoolId => _current?.schoolId;
  static String? get currentUid => _current?.uid;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Try to restore an admin session from a still-valid Firebase Auth user.
  /// Returns the resolved [AuthSession] or `null` when the user doc cannot be
  /// found or loaded.
  static Future<AuthSession?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final role = _parseUserRole(data['role'] as String?);
      if (role == null) return null;
      _current = AuthSession(
        role: role,
        uid: user.uid,
        email: user.email,
        schoolId: data['schoolId'] as String?,
        name: data['name'] as String?,
      );
      return _current;
    } catch (_) {
      return null;
    }
  }

  /// Sign in an admin/teacher/system-owner with email + password. The user's
  /// role and schoolId are loaded from `users/{uid}`. If that doc is missing
  /// but the email matches one of the demo accounts above, a synthetic
  /// session is returned so the app remains explorable out of the box.
  static Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final trimmedEmail = email.trim();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      final uid = cred.user!.uid;

      final doc = await _firestore.collection('users').doc(uid).get();
      UserRole? role;
      String? schoolId;
      String? name;
      if (doc.exists) {
        final data = doc.data() ?? {};
        if (data['isActive'] == false) {
          await _auth.signOut();
          throw Exception('This account has been deactivated');
        }
        role = _parseUserRole(data['role'] as String?);
        schoolId = data['schoolId'] as String?;
        name = data['name'] as String?;
        // Bump lastLogin for admin visibility.
        unawaited(doc.reference.update({'lastLogin': FieldValue.serverTimestamp()}));
      }

      role ??= expectedRole ?? _demoRoleForEmail(trimmedEmail);
      if (role == null) {
        throw Exception('User record is missing a role');
      }

      _current = AuthSession(
        role: role,
        uid: uid,
        email: trimmedEmail,
        schoolId: schoolId,
        name: name,
      );
      return _current!;
    } on FirebaseAuthException catch (e) {
      // If real auth fails and these are demo credentials, honor them so the
      // app stays explorable without a seeded Firebase project.
      if (_isDemoCredentials(trimmedEmail, password)) {
        final role = _demoRoleForEmail(trimmedEmail)!;
        _current = AuthSession(
          role: role,
          email: trimmedEmail,
          name: 'Demo ${role.name}',
        );
        return _current!;
      }
      throw Exception(_authMessage(e));
    }
  }

  /// Parent sign-in by student registration number + password. Looks up the
  /// matching students, optionally records a `parents/{id}` doc for the
  /// contact phone, and caches the session.
  static Future<AuthSession> signInAsParent({
    required String studentNumber,
    required String password,
  }) async {
    final normalized = studentNumber.trim();
    if (normalized.isEmpty) {
      throw Exception('Student number is required');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final isDemo = normalized.toUpperCase() == demoParentStudentNumber &&
        password == demoParentPassword;

    List<Student> students = [];
    try {
      students = await FirebaseService.getStudentsByStudentNumber(normalized);
    } catch (_) {
      if (!isDemo) rethrow;
    }

    if (students.isEmpty) {
      if (isDemo) {
        students = [_buildDemoStudent(normalized)];
      } else {
        throw Exception('No student found with this student number');
      }
    }

    final phone = students.first.fatherPhone ?? students.first.motherPhone;

    // Best-effort parent record upsert so the Parents admin screen can see
    // this contact and so we have a stable parent ID. Failures are ignored;
    // this isn't critical for login to succeed.
    if (!isDemo && phone != null && phone.trim().isNotEmpty) {
      unawaited(_upsertParentRecord(
        phone: phone,
        name: students.first.fatherName ?? students.first.motherName,
        studentIds: students.map((s) => s.id!).toList(),
      ));
    }

    _current = AuthSession(
      role: UserRole.parent,
      studentNumber: normalized,
      name: students.first.name,
      students: students,
    );
    return _current!;
  }

  static Future<void> _upsertParentRecord({
    required String phone,
    String? name,
    required List<String> studentIds,
  }) async {
    try {
      final snap = await _firestore
          .collection('parents')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        await _firestore.collection('parents').add({
          'phone': phone.trim(),
          if (name != null && name.isNotEmpty) 'name': name,
          'studentIds': studentIds,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        await snap.docs.first.reference.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'studentIds': studentIds,
          if (name != null && name.isNotEmpty) 'name': name,
        });
      }
    } catch (_) {
      // Intentionally swallowed.
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Ignore; the local session is cleared below.
    }
    _current = null;
  }

  /// Fetch the app_user.AppUser doc backing the current admin session, if any.
  static Future<app_user.AppUser?> currentUserRecord() async {
    final uid = _current?.uid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return app_user.AppUser.fromFirestore(doc.data() ?? {}, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Fetch the `parents/{id}` doc for the current parent session, if any.
  static Future<app_parent.Parent?> currentParentRecord() async {
    final session = _current;
    if (session == null || session.role != UserRole.parent) return null;
    final phone =
        session.students.isNotEmpty ? (session.students.first.fatherPhone ?? session.students.first.motherPhone) : null;
    if (phone == null) return null;
    try {
      final snap = await _firestore
          .collection('parents')
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return app_parent.Parent.fromFirestore(doc.data(), doc.id);
    } catch (_) {
      return null;
    }
  }

  // --- helpers ---

  static UserRole? _demoRoleForEmail(String email) {
    for (final entry in _demoCredentials.entries) {
      if (entry.value['email']?.toLowerCase() == email.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  static bool _isDemoCredentials(String email, String password) {
    for (final entry in _demoCredentials.entries) {
      if (entry.value['email']?.toLowerCase() == email.toLowerCase() &&
          entry.value['password'] == password) {
        return true;
      }
    }
    return false;
  }

  static String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  /// Overrides the in-memory session. Used by main.dart when restoring a
  /// cached session before Firebase Auth has rehydrated.
  static void setSession(AuthSession? session) {
    _current = session;
  }
}

Student _buildDemoStudent(String studentNumber) {
  final today = DateTime.now();
  return Student(
    id: 'demo-student-$studentNumber',
    name: 'Demo Student',
    sessionIds: const [],
    registrationNumber: studentNumber,
    gender: 'Male',
    birthdate: DateTime(today.year - 10, 1, 1).toIso8601String(),
    fatherName: 'Demo Father',
    fatherPhone: '0780000001',
    motherName: 'Demo Mother',
    motherPhone: '0780000002',
    country: 'Rwanda',
    province: 'Kigali',
    district: 'Gasabo',
    sector: 'Kimironko',
    cell: 'Kibagabaga',
    attendanceHistory: const [],
  );
}
