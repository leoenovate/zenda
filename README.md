# Zenda - School Attendance System

A mobile application for tracking student attendance in schools. This application allows administrators to manage attendance and parents to view their children's attendance records.

## Project Structure

The project follows a clean, layered architecture with the following structure:

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── attendance.dart       # Attendance model classes
│   ├── worker.dart           # Worker/student model
│   └── ...
├── screens/                  # UI screens
│   ├── admin_login_screen.dart    # Admin login screen
│   ├── api_logs_screen.dart       # API logs screen
│   ├── home_screen.dart           # Home screen for admins
│   ├── parent_dashboard_screen.dart # Parent dashboard
│   ├── parent_login_screen.dart   # Parent login screen
│   ├── welcome_screen.dart        # Welcome/initial screen
│   └── ...
├── services/                 # Service layer
│   ├── worker_service.dart   # Service for worker/student data
│   └── ...
└── utils/                    # Utility classes
    ├── ui_utils.dart         # UI helper functions
    └── ...
```

## Features

- **Admin Management**
  - Login interface for administrators
  - View and record student attendance
  - Access API logs

- **Parent Portal**
  - Login for parents using phone number verification
  - View children's attendance records
  - Track attendance statistics

## Technical Implementation

- Flutter for cross-platform mobile development
- Material Design UI components with custom styling
- JSON data storage for demo purposes (can be replaced with API)
- Animation effects for enhanced user experience
- Singleton pattern for service classes
- Separate model classes for clean data representation

## Best Practices

The code follows these best practices:

1. **Separation of concerns** - UI, data, and business logic are separated
2. **DRY (Don't Repeat Yourself)** - Common code is extracted to services and utils
3. **Consistent UI** - UI constants and helpers are in a shared utils class
4. **Error handling** - Try/catch blocks for data operations
5. **State management** - Clean state management with StatefulWidget
6. **Code organization** - Files are organized by functionality
7. **Documentation** - Clear comments on classes and methods

## Getting Started

1. Make sure you have Flutter installed
2. Clone the repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application
