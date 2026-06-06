import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/parent.dart' as app_parent;
import '../models/student.dart';
import '../models/user.dart' as app_user;
import 'auth_storage_service.dart';
import 'firebase_service.dart';

/// Application-level user roles. Kept in sync with the `role` field stored on
/// `users/{uid}` Firestore documents.
enum UserRole { parent, teacher, schoolAdmin, systemOwner }

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

/// Centralized authentication service. Backed entirely by Firestore — no
/// external identity provider involved. Email + password admins live in `users/{uid}`
/// with `passwordHash` (SHA-256 hex of `passwordSalt + plainPassword`) and
/// `passwordSalt` (random hex string). Parents sign in by student number.
///
/// The service exposes the resolved [AuthSession] for school-scoped queries
/// elsewhere in the app (see `FirebaseService._scopedSchool` / `_scoped`).
class AuthService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Random _rng = Random.secure();

  static AuthSession? _current;

  /// Demo credentials kept so first-run exploration works without seeding
  /// any Firestore data.
  static const Map<UserRole, Map<String, String>> _demoCredentials = {
    UserRole.systemOwner: {'email': 'owner@school.com', 'password': 'owner123'},
    UserRole.schoolAdmin: {'email': 'admin@school.com', 'password': 'admin123'},
    UserRole.teacher: {'email': 'teacher@school.com', 'password': 'teacher123'},
  };
  static const Map<String, String> _bootstrapAdminCredentials = {
    'email': 'isaacngendahayo2020@gmail.com',
    'password': 'admin123',
  };
  static const String demoParentStudentNumber = 'STD001';
  static const String demoParentPassword = 'parent123';

  /// Stable id used by demo admin/teacher sessions when Firestore has no
  /// seeded school doc yet.
  static const String demoSchoolId = 'demo-school';

  static AuthSession? get currentSession => _current;
  static UserRole? get currentRole => _current?.role;
  static String? get currentSchoolId => _current?.schoolId;
  static String? get currentUid => _current?.uid;

  // --- Password hashing -------------------------------------------------

  /// Generate a fresh 16-byte hex salt for a new password.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// SHA-256 hex of `salt + password`. Same hash + salt are stored on the
  /// user doc so [signInWithEmail] can reproduce and compare.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  static bool _verifyPassword(
    String password, {
    required String? hash,
    required String? salt,
  }) {
    if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) {
      return false;
    }
    return hashPassword(password, salt) == hash;
  }

  // --- Sign-in entry points ---------------------------------------------

  /// Sign in an admin/teacher/system-owner with email + password by looking
  /// up `users` where `email == X` and verifying the stored salt+hash. Falls
  /// back to a synthetic demo session for the built-in demo credentials so
  /// the app remains explorable out of the box.
  static Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      final snap =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: normalizedEmail)
              .limit(1)
              .get();
      if (snap.docs.isNotEmpty) doc = snap.docs.first;
    } catch (_) {
      // Network / rules failure — fall through to demo handling below.
    }

    if (doc != null) {
      final data = doc.data() ?? {};
      if (data['isActive'] == false) {
        throw Exception('This account has been deactivated');
      }
      final hash = data['passwordHash'] as String?;
      final salt = data['passwordSalt'] as String?;
      final legacyPassword =
          (data['password'] ?? data['temporaryPassword']) as String?;
      final hasHash = hash != null && hash.isNotEmpty;
      final hasLegacyPassword =
          legacyPassword != null && legacyPassword.isNotEmpty;

      if (hasHash) {
        if (!_verifyPassword(password, hash: hash, salt: salt)) {
          throw Exception('Incorrect password');
        }
      } else if (hasLegacyPassword) {
        if (legacyPassword != password) {
          throw Exception('Incorrect password');
        }
      } else if (!_isDemoCredentials(normalizedEmail, password)) {
        throw Exception('Account has no password set. Contact your admin.');
      }

      final role =
          _parseUserRole(data['role'] as String?) ??
          expectedRole ??
          _demoRoleForEmail(normalizedEmail);
      if (role == null) {
        throw Exception('User record is missing a role');
      }

      // Bump lastLogin for admin visibility and upgrade any legacy plain-text
      // password doc to the Firestore hash format (best effort).
      final updateData = <String, dynamic>{
        'lastLogin': FieldValue.serverTimestamp(),
      };
      if (!hasHash && hasLegacyPassword) {
        final newSalt = generateSalt();
        updateData
          ..['passwordSalt'] = newSalt
          ..['passwordHash'] = hashPassword(password, newSalt)
          ..['password'] = FieldValue.delete()
          ..['temporaryPassword'] = FieldValue.delete();
      }
      unawaited(doc.reference.update(updateData));

      _current = AuthSession(
        role: role,
        uid: doc.id,
        email: normalizedEmail,
        schoolId: data['schoolId'] as String?,
        name: data['name'] as String?,
      );
      return _current!;
    }

    // No matching Firestore user. Allow the built-in demo accounts so the
    // app can still be explored on a blank database.
    if (_isDemoCredentials(normalizedEmail, password)) {
      final role = _demoRoleForEmail(normalizedEmail)!;
      final demoSchoolId =
          role == UserRole.schoolAdmin || role == UserRole.teacher
              ? AuthService.demoSchoolId
              : null;
      _current = AuthSession(
        role: role,
        email: normalizedEmail,
        name: 'Demo ${role.name}',
        schoolId: demoSchoolId,
      );
      return _current!;
    }

    if (_isBootstrapAdminCredentials(normalizedEmail, password)) {
      final session = await _createBootstrapAdmin(normalizedEmail, password);
      if (session != null) return session;
    }

    throw Exception('No account found with this email');
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

    final isDemo =
        normalized.toUpperCase() == demoParentStudentNumber &&
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
      unawaited(
        _upsertParentRecord(
          phone: phone,
          name: students.first.fatherName ?? students.first.motherName,
          studentIds: students.map((s) => s.id!).toList(),
        ),
      );
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
      final snap =
          await _firestore
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

  /// Restore the in-memory session from the SharedPreferences cache. Returns
  /// the resolved [AuthSession] or `null` when nothing usable is stored.
  ///
  /// For email-based sessions we re-read the `users/{uid}` doc so role,
  /// schoolId, and active state stay fresh.
  static Future<AuthSession?> restoreSession() async {
    final stored = await AuthStorageService.getStoredSession();
    if (stored == null) return null;

    final role = stored['role'] as UserRole?;
    final email = stored['email'] as String?;
    final uid = stored['uid'] as String?;
    final cachedSchoolId = stored['schoolId'] as String?;
    final studentNumber = stored['studentNumber'] as String?;

    if (role == null) return null;

    if (role == UserRole.parent && studentNumber != null) {
      // Parents are restored entirely from cache; the live student lookup
      // happens in main.dart so it can synthesise the demo student when
      // Firestore is empty.
      _current = AuthSession(
        role: role,
        studentNumber: studentNumber,
        email: email,
      );
      return _current;
    }

    if (uid != null && uid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          if (data['isActive'] == false) return null;
          final freshRole = _parseUserRole(data['role'] as String?) ?? role;
          _current = AuthSession(
            role: freshRole,
            uid: uid,
            email: email ?? data['email'] as String?,
            schoolId: data['schoolId'] as String? ?? cachedSchoolId,
            name: data['name'] as String?,
          );
          return _current;
        }
      } catch (_) {
        // Fall through to cache-only restore.
      }
    }

    // Cache-only restore (covers the demo accounts that have no Firestore
    // doc, and offline restarts).
    var restoredSchoolId = cachedSchoolId;
    if ((restoredSchoolId == null || restoredSchoolId.isEmpty) &&
        uid == null &&
        (role == UserRole.schoolAdmin || role == UserRole.teacher)) {
      restoredSchoolId = demoSchoolId;
    }
    _current = AuthSession(
      role: role,
      uid: uid,
      email: email,
      schoolId: restoredSchoolId,
    );
    return _current;
  }

  static Future<void> signOut() async {
    _current = null;
    try {
      await AuthStorageService.clearStoredLogin();
    } catch (_) {
      // Ignore — the in-memory session is already cleared.
    }
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
        session.students.isNotEmpty
            ? (session.students.first.fatherPhone ??
                session.students.first.motherPhone)
            : null;
    if (phone == null) return null;
    try {
      final snap =
          await _firestore
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

  static bool _isBootstrapAdminCredentials(String email, String password) {
    return _bootstrapAdminCredentials['email'] == email.toLowerCase() &&
        _bootstrapAdminCredentials['password'] == password;
  }

  static Future<AuthSession?> _createBootstrapAdmin(
    String email,
    String password,
  ) async {
    try {
      final existing =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
      if (existing.docs.isNotEmpty) return null;

      final salt = generateSalt();
      final doc = await _firestore.collection('users').add({
        'email': email,
        'name': 'School Admin',
        'role': 'admin',
        'passwordSalt': salt,
        'passwordHash': hashPassword(password, salt),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _current = AuthSession(
        role: UserRole.schoolAdmin,
        uid: doc.id,
        email: email,
        name: 'School Admin',
      );
      return _current;
    } catch (_) {
      return null;
    }
  }

  /// Overrides the in-memory session. Used by main.dart when restoring a
  /// cached parent session after fetching live student data.
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
