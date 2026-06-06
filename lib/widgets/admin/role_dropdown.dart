import 'package:flutter/material.dart';

import '../../models/role.dart';
import 'admin_list_scaffold.dart';

/// Reusable dropdown for picking a custom [Role] when editing a worker,
/// teacher, or admin record. Lists every active role defined for the
/// person's school. Every active role is shown — any role can be assigned
/// to any kind of person.
///
/// The selected value is the role's `id` (or null for "no role"). Pass
/// the loaded `_roles` list down so this widget doesn't reload data.
class RoleDropdown extends StatelessWidget {
  final List<Role> roles;

  /// Person kind being edited (`worker` / `teacher` / `admin` / `staff`).
  /// Kept on the widget so we can re-key the dropdown when switching
  /// records, but no longer filters the role list.
  final String kind;

  final String? schoolId;
  final String? selectedRoleId;
  final ValueChanged<String?> onChanged;
  final String label;

  const RoleDropdown({
    super.key,
    required this.roles,
    required this.kind,
    required this.schoolId,
    required this.selectedRoleId,
    required this.onChanged,
    this.label = 'Role',
  });

  /// Returns every active role provided by the caller. The caller is
  /// responsible for passing a school-scoped list (`getRoles()` already
  /// scopes server-side via `_scoped`). We deliberately don't re-filter
  /// by `schoolId` here because legacy role docs may have an empty
  /// schoolId or a schoolId that doesn't strictly match the person
  /// being edited; that re-filter would silently drop everything.
  List<Role> get _eligibleRoles {
    final filtered = roles.where((r) => r.isActive).toList();
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligibleRoles;
    final hasSelection =
        selectedRoleId != null && eligible.any((r) => r.id == selectedRoleId);
    final value = hasSelection ? selectedRoleId : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey('role-dropdown-$kind-$schoolId-$value'),
      initialValue: value,
      decoration: adminInputDecoration(label),
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No role selected'),
        ),
        for (final r in eligible)
          DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
      ],
      onChanged: onChanged,
    );
  }
}
