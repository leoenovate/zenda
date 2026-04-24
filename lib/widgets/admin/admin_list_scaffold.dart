import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../utils/responsive_builder.dart';

/// Shared scaffolding for a system-owner admin list screen.
class AdminListScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final String searchHint;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  final List<School> schools;
  final String schoolFilter;
  final ValueChanged<String> onSchoolFilterChanged;
  final bool showSchoolFilter;

  final List<FilterOption> extraFilters;

  final String? addButtonLabel;
  final VoidCallback? onAddPressed;

  final Widget listContent;
  final Widget? headerExtras;

  const AdminListScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.schools,
    required this.schoolFilter,
    required this.onSchoolFilterChanged,
    required this.listContent,
    this.showSchoolFilter = true,
    this.extraFilters = const [],
    this.addButtonLabel,
    this.onAddPressed,
    this.headerExtras,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding = context.isMobile
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (headerExtras != null) headerExtras!,
              if (onAddPressed != null) ...[
                if (headerExtras != null) const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(addButtonLabel ?? 'Add'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              if (showSchoolFilter) ...[
                const SizedBox(width: 12),
                _buildDropdown(
                  context: context,
                  value: schoolFilter,
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All schools')),
                    ...schools.map((s) => DropdownMenuItem(
                        value: s.id ?? 'all', child: Text(s.name))),
                  ],
                  onChanged: (v) => onSchoolFilterChanged(v ?? 'all'),
                ),
              ],
              for (final f in extraFilters) ...[
                const SizedBox(width: 12),
                _buildDropdown(
                  context: context,
                  value: f.value,
                  items: f.items,
                  onChanged: f.onChanged,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          listContent,
        ],
      ),
    );
  }

  static Widget _buildDropdown({
    required BuildContext context,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox.shrink(),
        dropdownColor: colorScheme.surface,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
      ),
    );
  }
}

class FilterOption {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const FilterOption({
    required this.value,
    required this.items,
    required this.onChanged,
  });
}

/// Standard rounded card that wraps an admin list.
class AdminListCard extends StatelessWidget {
  final Widget child;
  const AdminListCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const AdminEmptyState(
      {super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
                color: colorScheme.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Standard form-field decoration used across admin dialogs. Style comes
/// from `Theme.of(context).inputDecorationTheme`, so only labelText is set.
InputDecoration adminInputDecoration(String label, {bool required = false}) {
  return InputDecoration(
    labelText: required ? '$label *' : label,
  );
}
