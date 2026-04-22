import 'package:flutter/material.dart';
import '../../models/school.dart';
import '../../utils/responsive_builder.dart';

/// Shared scaffolding for a system-owner admin list screen.
///
/// Gives every CRUD screen the same look: title + subtitle header, an
/// optional Add button, a search field, an optional school filter dropdown,
/// and a rounded card container for the list content.
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

  final List<_FilterOption> extraFilters;

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
                      style: const TextStyle(
                        color: Color(0xFF2C2C2C),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
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
                    hintStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF2C2C2C)),
                  onChanged: onSearchChanged,
                ),
              ),
              if (showSchoolFilter) ...[
                const SizedBox(width: 12),
                _buildDropdown(
                  value: schoolFilter,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All schools')),
                    ...schools.map((s) =>
                        DropdownMenuItem(value: s.id ?? 'all', child: Text(s.name))),
                  ],
                  onChanged: (v) => onSchoolFilterChanged(v ?? 'all'),
                ),
              ],
              for (final f in extraFilters) ...[
                const SizedBox(width: 12),
                _buildDropdown(
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
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Color(0xFF2C2C2C), fontSize: 14),
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterOption({
    required this.value,
    required this.items,
    required this.onChanged,
  });
}

/// Helpers to build the standard rounded white card that wraps a list.
class AdminListCard extends StatelessWidget {
  final Widget child;
  const AdminListCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const AdminEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFF999999)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Standard form-field decoration used across admin dialogs.
InputDecoration adminInputDecoration(String label, {bool required = false}) {
  return InputDecoration(
    labelText: required ? '$label *' : label,
    labelStyle: const TextStyle(color: Color(0xFF666666)),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
    ),
  );
}
