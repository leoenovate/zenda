# AGENTS.md

## Learned User Preferences

- Target Flutter Windows desktop as the primary run surface (`flutter run -d windows`) from `c:\i\zenda`.
- When Firestore has no matching record for a demo flow (e.g., parent `STD001`), synthesize an in-memory fallback (e.g., `_buildDemoStudent`) so the UI is explorable end-to-end.
- Keep a consistent dark/teal theme across every UI; new admin screens should match the system owner dashboard palette (teal `0xFF1A5F5F`, dark dialog `0xFF2A2A2A`).
- Demo credential rows on the login screen should be tappable and auto-fill role + email + password.
- Modal dialogs that run background work (e.g., fingerprint scan) must include a Cancel button that cancels timers/subscriptions and resets `_isScanning` without raising an error.
- When fixing Flutter sliver/`ListView.builder` assertions, add stable `ValueKey`s, cancel any `StreamSubscription` in `dispose`, and guard `setState` with `if (!mounted) return;`.
- Place new admin CRUD screens under `lib/screens/admin/` and shared admin widgets under `lib/widgets/admin/`.
- New Firestore-backed models should follow `lib/models/school.dart`'s `fromFirestore` / `toFirestore` + `_parseDate` pattern.
- Logout pattern: `FirebaseAuth.instance.signOut()` → `AuthStorageService.clearStoredLogin()` → `Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false)`.

## Learned Workspace Facts

- Project is a Flutter 3.7 + Firebase school attendance app named `zenda`, rooted at `c:\i\zenda`.
- Four user roles live in `lib/screens/login_screen.dart`: `systemOwner`, `schoolAdmin`, `teacher`, `parent`. First three log in with email/password; `parent` logs in with a student registration number.
- Demo logins: `owner@school.com / owner123`, `admin@school.com / admin123`, `teacher@school.com / teacher123`, and parent `STD001 / parent123`.
- Session state is cached in `lib/services/auth_storage_service.dart` (SharedPreferences); `AuthWrapper` in `lib/main.dart` resolves the stored role on startup and routes to the correct dashboard.
- Key screens: `lib/screens/login_screen.dart`, `lib/screens/home_screen.dart` (school staff), `lib/screens/system_owner_dashboard.dart`, `lib/screens/parent_dashboard_screen.dart`, `lib/screens/chat_list_screen.dart`.
- Firestore data access is centralized in `lib/services/firebase_service.dart`; collection inventory and usage status are tracked in `FIRESTORE_COLLECTIONS_ANALYSIS.md`.
- `firestore.rules` is currently permissive (`allow read, write: if true`) and is not production-ready; indexes live in `firestore.indexes.json`.
- Firestore collections `teachers`, `classes`, `parents`, `devices`, `sessions`, `system`, and `workers` exist but are not yet wired to UI; new admin screens are being added under `lib/screens/admin/`.
- Shell is PowerShell on Windows; chain commands with `;` (not `&&`) and use `Set-Location` instead of `cd` when scripting.
- Windows Firebase C++ SDK zip (`build\windows\x64\firebase_cpp_sdk_windows_*.zip`) often fails/truncates via CMake's bundled curl; pre-cache it with `Start-BitsTransfer` from `https://dl.google.com/firebase/sdk/cpp/` before running `flutter run -d windows`.
- Default CMake install prefix resolves to `C:/Program Files/zenda` (admin-only) and breaks the INSTALL step; reconfigure with `-DCMAKE_INSTALL_PREFIX=C:/i/zenda/build/windows/x64/runner/Debug`.
- App routes include `/login` and `/api-logs`; home screen header hosts chat, analytics, and logout icon buttons.
