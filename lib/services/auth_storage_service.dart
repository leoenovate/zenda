import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';

class AuthStorageService {
  static const String _keyIsDemoLogin = 'is_demo_login';
  static const String _keyUserRole = 'user_role';
  static const String _keyEmail = 'user_email';
  static const String _keyStudentNumber = 'student_number';

  // Save demo login credentials
  static Future<void> saveDemoLogin({
    required UserRole role,
    String? email,
    String? studentNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('AuthStorage: Saving demo login - Role: ${role.name}, Email: $email, StudentNumber: $studentNumber');
      
      final boolSaved = await prefs.setBool(_keyIsDemoLogin, true);
      final roleSaved = await prefs.setString(_keyUserRole, role.name);
      
      print('AuthStorage: Saved isDemoLogin: $boolSaved, role: $roleSaved');
      
      if (email != null) {
        final emailSaved = await prefs.setString(_keyEmail, email);
        print('AuthStorage: Saved email: $emailSaved');
      }
      if (studentNumber != null) {
        final studentSaved = await prefs.setString(_keyStudentNumber, studentNumber);
        print('AuthStorage: Saved studentNumber: $studentSaved');
      }
      
      // Verify what was saved
      final savedRole = prefs.getString(_keyUserRole);
      final savedEmail = prefs.getString(_keyEmail);
      final savedStudent = prefs.getString(_keyStudentNumber);
      print('AuthStorage: Verification - Role: $savedRole, Email: $savedEmail, Student: $savedStudent');
    } catch (e) {
      print('AuthStorage: Error saving demo login: $e');
      rethrow;
    }
  }

  // Save Firebase Auth login (not demo)
  static Future<void> saveFirebaseLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDemoLogin, false);
  }

  // Check if there's a stored demo login
  static Future<Map<String, dynamic>?> getStoredDemoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Debug: Check all stored values
      final isDemoLogin = prefs.getBool(_keyIsDemoLogin);
      final roleString = prefs.getString(_keyUserRole);
      final email = prefs.getString(_keyEmail);
      final studentNumber = prefs.getString(_keyStudentNumber);
      
      print('AuthStorage: Reading stored values - isDemoLogin: $isDemoLogin, role: $roleString, email: $email, studentNumber: $studentNumber');
      
      if (isDemoLogin == null || !isDemoLogin) {
        print('AuthStorage: No demo login found (isDemoLogin is null or false)');
        return null; // Not a demo login or no stored login
      }

      if (roleString == null) {
        print('AuthStorage: No role found in storage');
        return null;
      }

      UserRole? role;
      try {
        role = UserRole.values.firstWhere((r) => r.name == roleString);
        print('AuthStorage: Found role: ${role.name}');
      } catch (e) {
        print('AuthStorage: Error parsing role: $e');
        return null;
      }

      print('AuthStorage: Returning stored login - Role: ${role.name}, Email: $email, StudentNumber: $studentNumber');
      return {
        'role': role,
        'email': email,
        'studentNumber': studentNumber,
      };
    } catch (e) {
      print('AuthStorage: Error getting stored demo login: $e');
      return null;
    }
  }

  // Clear stored login credentials
  static Future<void> clearStoredLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsDemoLogin);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyStudentNumber);
  }

  // Check if user is logged in (demo or Firebase)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsDemoLogin) != null;
  }

  // Debug method to print all stored values
  static Future<void> debugPrintStoredValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      print('AuthStorage: All stored keys: $allKeys');
      
      for (final key in allKeys) {
        final value = prefs.get(key);
        print('AuthStorage: $key = $value');
      }
    } catch (e) {
      print('AuthStorage: Error printing stored values: $e');
    }
  }
}

