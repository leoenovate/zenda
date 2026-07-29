import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Thin wrapper around SharedPreferences used to remember the most recent
/// sign-in so AuthWrapper can route the user to their dashboard on app open
/// without waiting for a network round-trip.
/// The authoritative account profile is the matching Firestore users doc.
class AuthStorageService {
  static const String _keyRole = 'auth_role';
  static const String _keyEmail = 'auth_email';
  static const String _keyUid = 'auth_uid';
  static const String _keySchoolId = 'auth_school_id';
  static const String _keyStudentNumber = 'auth_student_number';
  static const String _keyPhone = 'auth_phone';
  static const String _keyLastLoginIdentifier = 'auth_last_login_identifier';

  /// Save the latest session. All fields except role are optional.
  static Future<void> saveSession({
    required UserRole role,
    String? email,
    String? uid,
    String? schoolId,
    String? studentNumber,
    String? phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role.name);
      if (email != null) {
        await prefs.setString(_keyEmail, email);
      } else {
        await prefs.remove(_keyEmail);
      }
      if (uid != null) {
        await prefs.setString(_keyUid, uid);
      } else {
        await prefs.remove(_keyUid);
      }
      if (schoolId != null) {
        await prefs.setString(_keySchoolId, schoolId);
      } else {
        await prefs.remove(_keySchoolId);
      }
      if (studentNumber != null) {
        await prefs.setString(_keyStudentNumber, studentNumber);
      } else {
        await prefs.remove(_keyStudentNumber);
      }
      if (phone != null) {
        await prefs.setString(_keyPhone, phone);
      } else {
        await prefs.remove(_keyPhone);
      }
    } catch (e) {
      print('AuthStorage: Error saving session: $e');
      rethrow;
    }
  }

  /// Read back the cached session, or `null` if nothing is stored.
  static Future<Map<String, dynamic>?> getStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleString = prefs.getString(_keyRole);
      if (roleString == null) return null;

      UserRole? role;
      try {
        role = UserRole.values.firstWhere((r) => r.name == roleString);
      } catch (_) {
        return null;
      }

      return {
        'role': role,
        'email': prefs.getString(_keyEmail),
        'uid': prefs.getString(_keyUid),
        'schoolId': prefs.getString(_keySchoolId),
        'studentNumber': prefs.getString(_keyStudentNumber),
        'phone': prefs.getString(_keyPhone),
      };
    } catch (e) {
      print('AuthStorage: Error reading stored session: $e');
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final session = await getStoredSession();
    return session != null;
  }

  /// Remember only the login identifier (email or student number) for the
  /// login form. This intentionally survives logout; it is not an auth session.
  static Future<void> saveLastLoginIdentifier(String identifier) async {
    final trimmed = identifier.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyLastLoginIdentifier);
      return;
    }
    await prefs.setString(_keyLastLoginIdentifier, trimmed);
  }

  static Future<String?> getLastLoginIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastLoginIdentifier);
  }

  static Future<void> clearLastLoginIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastLoginIdentifier);
  }

  static Future<void> clearStoredLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUid);
    await prefs.remove(_keySchoolId);
    await prefs.remove(_keyStudentNumber);
    await prefs.remove(_keyPhone);
  }
}
