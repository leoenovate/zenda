/// Centralized constants and helpers for the auth-role string values stored
/// on `users/{uid}.role` and the "kind" tags used by audience pickers / time
/// off entries / role definitions.
///
/// These are intentionally kept as plain string constants (not an enum) so
/// they can be compared directly against Firestore values without parsing.
///
/// The four user kinds the app cares about:
///
/// - `teacher` — a `teachers/{id}` record (separate Firestore collection).
/// - `admin`   — a `users/{uid}` row with `role` = `admin` or `school_admin`.
/// - `staff`   — a `users/{uid}` row with `role` = `staff`. Lower-privileged
///   admin seat (e.g. front-office personnel).
/// - `worker`  — a `workers/{id}` record (kitchen, cleaning, security, etc).
///
/// The `parent` kind is auth-only (parents have no admin presence) and the
/// `system_owner` kind is also auth-only (cross-school operator).
class AuthRoles {
  AuthRoles._();

  // --- Raw Firestore values stored on users/{uid}.role -------------------

  static const String systemOwner = 'system_owner';
  static const String admin = 'admin';
  static const String schoolAdmin = 'school_admin';
  static const String teacher = 'teacher';
  static const String staff = 'staff';
  static const String parent = 'parent';

  // --- "kind" labels used by Session.assigneeKind, StaffTimeOff.assigneeKind,
  //     role employee pickers, etc. ---------------------------------------
  //
  // These are *not* the same as the user.role string above:
  //   * `teacher` here means "from the teachers/ collection".
  //   * `admin` / `staff` here mean "from users/ with that role".
  //   * `worker` here means "from the workers/ collection".

  static const String kindTeacher = 'teacher';
  static const String kindAdmin = 'admin';
  static const String kindStaff = 'staff';
  static const String kindWorker = 'worker';

  /// Default and sort order for role-kind UI.
  static const List<String> allKinds = [
    kindTeacher,
    kindAdmin,
    kindStaff,
    kindWorker,
  ];

  // --- Predicates --------------------------------------------------------

  static bool isSystemOwner(String? role) =>
      (role ?? '').toLowerCase() == systemOwner;

  /// True for any user.role value that should be treated as a school admin
  /// (legacy projects sometimes stored `admin`, others `school_admin`).
  static bool isSchoolAdmin(String? role) {
    final v = (role ?? '').toLowerCase();
    return v == admin || v == schoolAdmin;
  }

  static bool isTeacher(String? role) =>
      (role ?? '').toLowerCase() == teacher;

  static bool isStaff(String? role) =>
      (role ?? '').toLowerCase() == staff;

  static bool isParent(String? role) =>
      (role ?? '').toLowerCase() == parent;

  /// True for school-admin OR generic staff users — i.e. anyone whose
  /// `users/{uid}` doc grants administrative access to a single school.
  static bool isAdminLike(String? role) =>
      isSchoolAdmin(role) || isStaff(role);

  // --- Display helpers ---------------------------------------------------

  /// Human-readable label for an `assigneeKind` value
  /// (e.g. for time-off rows or session pickers).
  static String kindLabel(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case kindTeacher:
        return 'Teacher';
      case kindAdmin:
        return 'Administrator';
      case kindStaff:
        return 'Staff';
      case kindWorker:
        return 'Worker';
      default:
        return 'Worker';
    }
  }

  /// Plural form for sidebar / filter dropdown labels.
  static String kindLabelPlural(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case kindTeacher:
        return 'Teachers';
      case kindAdmin:
        return 'Administrators';
      case kindStaff:
        return 'Staff accounts';
      case kindWorker:
        return 'Workers';
      default:
        return 'Workers';
    }
  }

  /// Maps an `assigneeKind` to the corresponding `users/{uid}.role` string
  /// for kinds that live in the `users/` collection. Returns null for
  /// `teacher` / `worker` since those have their own collections.
  static String? userRoleForKind(String? kind) {
    switch ((kind ?? '').toLowerCase()) {
      case kindAdmin:
        return admin;
      case kindStaff:
        return staff;
      default:
        return null;
    }
  }

  /// Inverse of [userRoleForKind]: given a `users/{uid}.role` value,
  /// return the corresponding `assigneeKind`. Defaults to `admin` for
  /// any school-admin variant, `staff` for staff, otherwise null.
  static String? kindForUserRole(String? role) {
    if (isSchoolAdmin(role)) return kindAdmin;
    if (isStaff(role)) return kindStaff;
    return null;
  }
}
