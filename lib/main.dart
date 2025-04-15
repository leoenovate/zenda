import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'parent_screens.dart';
import 'models/worker.dart';
import 'screens/welcome_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Attendance System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1E88E5), // School blue
          secondary: const Color(0xFFF5F5F5), // Light gray/white
          surface: const Color(0xFF2A2A2A),
          background: const Color(0xFF1A1A1A),
          onPrimary: Colors.white,
          onSecondary: const Color(0xFF1A1A1A),
          onSurface: const Color(0xFFF5F5F5),
          onBackground: const Color(0xFFF5F5F5),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: CardTheme(
          color: const Color(0xFF2A2A2A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E88E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFF5F5F5).withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E88E5)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/parent-login': (context) => const ParentLoginScreen(),
        '/admin': (context) => const HomeScreen(),
        '/parent-dashboard': (context) => const ParentDashboardScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
