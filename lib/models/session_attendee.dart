/// One person individually picked for a [Session]. Distinct from
/// `Session.audienceRoles`, which expresses "everyone currently in role X"
/// without enumerating the people, and from `Session.classIds` which
/// targets entire student classes.
///
/// [kind] tells the UI which collection the person came from so we can
/// render an icon and resolve the live record:
///   - `teacher` -> `teachers/{id}`
///   - `admin`   -> `users/{id}` (role admin / school_admin)
///   - `staff`   -> `users/{id}` (role staff)
///   - `worker`  -> `workers/{id}` (covers built-in workers + every custom
///     role, since custom roles are stored as `workers/{id}.role`)
///
/// [roleKey] groups attendees by role in the UI (built-in role key like
/// `teacher`, or a custom role's name).
class SessionAttendee {
  final String kind;
  final String id;
  final String name;
  final String? roleKey;

  const SessionAttendee({
    required this.kind,
    required this.id,
    required this.name,
    this.roleKey,
  });

  factory SessionAttendee.fromMap(Map<String, dynamic> data) {
    return SessionAttendee(
      kind: (data['kind'] ?? 'worker').toString(),
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      roleKey: data['roleKey']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind,
      'id': id,
      'name': name,
      if (roleKey != null && roleKey!.isNotEmpty) 'roleKey': roleKey,
    };
  }

  SessionAttendee copyWith({
    String? kind,
    String? id,
    String? name,
    String? roleKey,
  }) {
    return SessionAttendee(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      name: name ?? this.name,
      roleKey: roleKey ?? this.roleKey,
    );
  }

  /// Stable identity for de-duplication / chip removal in the form.
  String get compoundKey => '$kind:$id';
}
