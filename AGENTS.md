# AGENTS.md

## Learned User Preferences

- Target Flutter Windows desktop (`flutter run -d windows`) from `c:\i\zenda` for dev; build Android release via `flutter build apk --release`.
- When Firestore has no matching record for a demo flow (e.g., parent `STD001`), synthesize an in-memory fallback (e.g., `_buildDemoStudent`) so the UI is explorable end-to-end.
- New UI must read colors from `Theme.of(context).colorScheme.*` tokens via the shared `lib/theme/` system — avoid hardcoded hex like `0xFF1A5F5F` and honor the teal ↔ orange + light/dark switch.
- Before committing Dart, audit for stray `Â·` (U+00C2 U+00B7) that should be middle-dot `·` (e.g. `rg "Â" --type dart`); it recurs in admin list subtitles.
- Demo credential rows on the login screen should be tappable and auto-fill role + email + password.
- Modal dialogs that run background work (e.g., fingerprint scan) must include a Cancel button that cancels timers/subscriptions and resets `_isScanning` without raising an error.
- When fixing Flutter sliver/`ListView.builder` assertions, add stable `ValueKey`s, cancel any `StreamSubscription` in `dispose`, and guard `setState` with `if (!mounted) return;`.
- Place new admin CRUD screens under `lib/screens/admin/` and shared admin widgets under `lib/widgets/admin/` (reuse `admin_list_scaffold.dart`).
- New Firestore-backed models should follow `lib/models/school.dart`'s `fromFirestore` / `toFirestore` + `_parseDate` pattern.
- Logout pattern: `AuthService.signOut()` (wraps `FirebaseAuth.signOut()` + `AuthStorageService.clearStoredLogin()`) then `Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false)`.

## Learned Workspace Facts

- Project is a Flutter 3.7 + Firebase school attendance app named `zenda`, rooted at `c:\i\zenda`.
- Four user roles (enum `UserRole`: `systemOwner`, `schoolAdmin`, `teacher`, `parent`); role strings on `users/{uid}.role` are `system_owner`, `admin`/`school_admin`, `teacher`, `parent`.
- Demo logins (work against empty Firestore via `AuthService`'s synthetic fallback): `owner@school.com / owner123`, `admin@school.com / admin123`, `teacher@school.com / teacher123`, parent `STD001 / parent123`.
- `lib/services/auth_service.dart` is the single login entry point (`signInWithEmail`, `signInAsParent`, `restoreSession`, `signOut`); `auth_storage_service.dart` caches the `AuthSession` in SharedPreferences and `AuthWrapper` in `lib/main.dart` routes on startup.
- `lib/services/firebase_service.dart` owns all Firestore I/O; `_scoped()` auto-applies a `schoolId` filter for non-owner callers across students/devices/users/teachers/classes/parents/workers. Collection inventory is tracked in `FIRESTORE_COLLECTIONS_ANALYSIS.md`.
- System owner dashboard has 9 sections (Dashboard, Schools, Devices, Teachers, Classes, Parents, Sessions, Workers, System); each admin section lives under `lib/screens/admin/` and uses `lib/widgets/admin/admin_list_scaffold.dart`.
- Unified theme system lives in `lib/theme/` (`app_colors.dart`, `app_theme.dart`, `theme_controller.dart`); `ThemeController` persists `ThemeMode` + `AppPrimary` (teal/orange) via SharedPreferences keys `pref.theme_mode` / `pref.theme_primary` and exposes `ThemeSwitcher` for AppBars. `system_owner_dashboard.dart` is wrapped in a scoped `Theme(data: AppTheme.light(primary: …))` and is light-only by design.
- Morning/Afternoon is gone: `Student.sessionIds: List<String>` references `sessions/{id}`; `Session` has `lateTime`; legacy data is migrated via System Owner dashboard → Quick Actions → **Migrate period data** (`FirebaseService.migrateSchoolPeriodsToSessions`).
- `firestore.rules` is role + schoolId aware (works with custom auth claims or falls back to `users/{uid}` lookups). `storage.rules` restricts `chat_attachments/{studentId}/{file}` to authenticated users, `image/*`, <10 MB; attachments are uploaded from `widgets/chat/message_input.dart` via `image_picker`.
- Cloud Functions (Node 20) live at `functions/src/index.ts`: `setRoleClaim` (callable; bootstraps the first `system_owner`) and `syncClaimsOnUserWrite` (mirrors `users/{uid}.role`+`schoolId` into custom claims). Build + deploy with `npm --prefix functions run build && firebase deploy --only functions`.
- Dev environment (Windows): use PowerShell with `;` (not `&&`) and `Set-Location`. Android release needs `-Djava.net.preferIPv4Stack=true` in `android/gradle.properties` (Gradle JVM IPv6 issues to `storage.googleapis.com`); Kotlin Android plugin is pinned to `2.1.0` in `android/settings.gradle.kts`; release APK at `build/app/outputs/flutter-apk/app-release.apk`. Windows desktop: Firebase C++ SDK zip (`build\windows\x64\firebase_cpp_sdk_windows_*.zip`) may truncate via CMake's bundled curl — pre-cache with `Start-BitsTransfer` from `https://dl.google.com/firebase/sdk/cpp/`; reconfigure with `-DCMAKE_INSTALL_PREFIX=C:/i/zenda/build/windows/x64/runner/Debug` since the default `C:/Program Files/zenda` is admin-only.
- School admin desktop shell in `lib/screens/school_admin_dashboard.dart`: outer `Row` should use `crossAxisAlignment: CrossAxisAlignment.stretch` so the main pane fills height. Short scroll pages (Dashboard, Devices): `LayoutBuilder` + `ConstrainedBox(minHeight: viewport maxHeight when finite)` + top-aligned `Column`. A nested `Row` with `CrossAxisAlignment.stretch` inside `SingleChildScrollView` gets unbounded height—wrap with `IntrinsicHeight` only if children are intrinsically measurable; avoid `IntrinsicHeight` around shrink-wrapped `ListView` (prefer `Column` or explicit height). Cards in scroll views: gate `Spacer` on bounded height (e.g. `LayoutBuilder`) to avoid unbounded flex errors.
