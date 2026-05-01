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
    final isMobile = context.isMobile;
    final padding =
        context.isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(24);
    final actionButtons = <Widget>[
      if (headerExtras != null) headerExtras!,
      if (onAddPressed != null)
        ElevatedButton.icon(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add, size: 18),
          label: Text(addButtonLabel ?? 'Add'),
        ),
    ];

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, colorScheme, actionButtons, isMobile),
          const SizedBox(height: 20),
          _buildFilters(context, isMobile),
          const SizedBox(height: 20),
          listContent,
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    List<Widget> actionButtons,
    bool isMobile,
  ) {
    final titleBlock = Column(
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
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          if (actionButtons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actionButtons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  actionButtons[i],
                ],
              ],
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        if (actionButtons.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: actionButtons,
          ),
        ],
      ],
    );
  }

  Widget _buildFilters(BuildContext context, bool isMobile) {
    final searchField = TextField(
      decoration: InputDecoration(
        hintText: searchHint,
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: onSearchChanged,
    );
    final filters = <Widget>[
      if (showSchoolFilter)
        _buildDropdown(
          context: context,
          value: schoolFilter,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All schools')),
            ...schools.map(
              (s) => DropdownMenuItem(
                value: s.id ?? 'all',
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => onSchoolFilterChanged(v ?? 'all'),
        ),
      for (final f in extraFilters)
        _buildDropdown(
          context: context,
          value: f.value,
          isExpanded: true,
          items: f.items,
          onChanged: f.onChanged,
        ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          for (final filter in filters) ...[const SizedBox(height: 12), filter],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        for (final filter in filters) ...[
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: filter,
          ),
        ],
      ],
    );
  }

  static Widget _buildDropdown({
    required BuildContext context,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool isExpanded = false,
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
        isExpanded: isExpanded,
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
  const AdminEmptyState({super.key, required this.icon, required this.message});

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
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Standard form-field decoration used across admin dialogs. Style comes
/// from `Theme.of(context).inputDecorationTheme`, so only labelText is set.
InputDecoration adminInputDecoration(String label, {bool required = false}) {
  return InputDecoration(labelText: required ? '$label *' : label);
}
