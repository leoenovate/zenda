import 'package:flutter/material.dart';

/// A destination shown in the mobile bottom [NavigationBar].
class MobileNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const MobileNavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
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
    return Scaffold(
      appBar: appBar,
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        elevation: 3,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final dest in destinations)
            NavigationDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.selectedIcon ?? dest.icon),
              label: dest.label,
            ),
        ],
      ),
    );
  }
}
