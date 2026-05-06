# Zenda - School Attendance System

Flutter + Firebase app for tracking student (and staff) attendance, chatting
with parents, managing fingerprint scanner devices, and administering
multiple schools from a single system-owner dashboard.

## Stack

- **Flutter** 3.7+ (mobile, web, Windows, macOS, Linux)
- **Firebase**: Firestore, Storage, Cloud Functions
- **fl_chart / syncfusion_flutter_charts** for dashboard visualizations

## Features

- Parent login by student registration number; parent dashboard with
  attendance history and school chat.
- Admin / teacher login via Firestore `users` documents (email + password).
- System owner dashboard with nine sections: Dashboard, Schools, Devices,
  Teachers, Classes, Parents, Sessions, Workers, System.
- Full CRUD for `schools`, `users`, `devices`, `teachers`, `classes`,
  `parents`, `sessions`, `workers`, and a global `system/config` doc.
- Fingerprint scanner integration via the `fingerprints` collection.
- Chat with image attachments uploaded to Firebase Storage.

## Project layout

```
lib/
  main.dart                    # entrypoint + AuthWrapper
  firebase_options.dart
  models/                      # Firestore-backed data classes
  screens/
    login_screen.dart          # unified login (parent / admin / teacher / owner)
    admin_login_screen.dart    # Firestore admin login
    home_screen.dart           # school admin / teacher dashboard
    parent_dashboard_screen.dart
    system_owner_dashboard.dart
    admin/                     # system-owner CRUD screens
  services/
    auth_service.dart          # centralized sign-in, role lookup, session state
    auth_storage_service.dart  # SharedPreferences cache for the session
    firebase_service.dart      # all Firestore reads/writes, schoolId-scoped
  utils/
  widgets/
    admin/                     # shared admin list scaffold
    chat/
    dashboard/
    student_form/
functions/                     # Cloud Functions placeholder
firestore.rules                # Firestore-only development rules
firestore.indexes.json
storage.rules                  # chat_attachments/* size + MIME constraints
firebase.json
```

## Getting started

### Prerequisites

- Flutter 3.7+
- A Firebase project with Firestore enabled
- Node.js 20+ (only if you plan to deploy the Cloud Functions)
- Firebase CLI: `npm install -g firebase-tools`

### Install

```
flutter pub get
```

### Run

```
flutter run -d chrome          # web
flutter run -d windows         # Windows desktop
flutter run                    # attached mobile device / emulator
```

### Demo credentials

The three demo accounts below work out of the box even against an empty
Firestore - `AuthService` silently falls back to a synthetic session when
the email/password are not found in `users`.

| Role           | Email / student #   | Password      |
|----------------|---------------------|---------------|
| System owner   | owner@school.com    | owner123      |
| School admin   | admin@school.com    | admin123      |
| Teacher        | teacher@school.com  | teacher123    |
| Parent         | STD001              | parent123     |

Creating real accounts via **System Owner > System > Add Administrator**
writes a `users/{uid}` document with the chosen role, `schoolId`, and a
salted password hash.

## Roles

Roles are stored as a string on `users/{uid}.role`. The following values
are recognised across the app and rules:

| Role string                    | UI enum                |
|--------------------------------|------------------------|
| system_owner                   | UserRole.systemOwner   |
| admin / school_admin           | UserRole.schoolAdmin   |
| teacher                        | UserRole.teacher       |
| parent                         | UserRole.parent        |

System owners see all data across schools. Every other role is scoped to
the `schoolId` stored on their user document - enforced both by
`FirebaseService._scoped()` on the client and by the Firestore security
rules on the server.

## Deploying Firestore rules and indexes

```
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

## Cloud Functions (optional)

Authentication is handled directly in Firestore by the Flutter app. The
`functions/` package is currently just a placeholder for future backend work;
there are no identity or role-claim functions to deploy.

```
cd functions
npm install
npm run build
firebase deploy --only functions
```

The rules in `firestore.rules` work with or without this function
deployed - they transparently fall back to reading `users/{uid}` when a
custom claim is absent.

## Multi-school backfill

If you upgrade from the original single-school data model (no `schoolId`
on student docs), run the one-click backfill:

1. Sign in as a system owner.
2. Open System > Data migration.
3. Pick a target school from the dropdown.
4. Press Run backfill. Every student that is missing a `schoolId` is
   assigned to the selected school.

Under the hood this calls
`FirebaseService.backfillStudentSchoolIds(schoolId)`, which uses a single
Firestore batch write.

## Deriving parents from students

Parent contact details (fatherPhone / motherPhone) currently live on the
student document. To populate the standalone `parents` collection in
bulk, open Parents > Sync from students. One `parents/{id}` document is
created per unique phone, with `studentIds` collecting every child of
that contact.

## Storage

Chat attachments are uploaded to
`chat_attachments/{studentId}/{timestamp}.{ext}` and constrained by
`storage.rules` to images < 10 MB.

## Analyzer

```
flutter analyze
```

All production files are analyzer-clean; only pre-existing `info`-level
hints in `lib/widgets/student_form/` remain.
