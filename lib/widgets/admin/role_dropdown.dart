import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../services/role_constants.dart';
import 'admin_list_scaffold.dart';

/// Reusable dropdown for picking a custom [Role] when editing a worker,
/// teacher, or admin record. Lists every active role for [schoolId]
/// whose `appliesTo` array contains [kind] (one of `AuthRoles.kind*`).
///
/// The selected value is the role's `id` (or null for "no role"). Pass
/// the loaded `_roles` list down so this widget doesn't reload data.
class RoleDropdown extends StatelessWidget {
  final List<Role> roles;
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

  List<Role> get _eligibleRoles => roles
      .where(
        (r) =>
            r.isActive &&
            r.appliesTo.contains(kind) &&
            (schoolId == null || r.schoolId == schoolId),
      )
      .toList();

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
