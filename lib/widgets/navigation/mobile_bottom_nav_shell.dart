import 'package:flutter/material.dart';

/// A destination shown in the mobile bottom [NavigationBar].
class MobileNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// Shorter label used when the bar has more than four destinations.
  final String? shortLabel;

  const MobileNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.shortLabel,
  });

  /// Label shown in the bottom bar (compact when needed).
  String displayLabel({required bool compact}) {
    if (compact && shortLabel != null) return shortLabel!;
    return label;
  }
}

/// Scaffold wrapper for mobile dashboards with a Material 3 bottom nav bar.
class MobileBottomNavShell extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<MobileNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const MobileBottomNavShell({
    super.key,
    this.appBar,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compactBar = destinations.length > 4;

    return Scaffold(
      appBar: appBar,
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              height: 64,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: colorScheme.secondaryContainer,
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: selected ? 24 : 22,
                  color:
                      selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1,
                  letterSpacing: 0,
                  color:
                      selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                );
              }),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            elevation: 0,
            shadowColor: colorScheme.shadow,
            surfaceTintColor: Colors.transparent,
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.secondaryContainer,
            labelBehavior:
                compactBar
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final dest in destinations)
                NavigationDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
                  label: dest.displayLabel(compact: compactBar),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
