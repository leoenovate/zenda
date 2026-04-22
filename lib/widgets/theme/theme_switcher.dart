import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';

/// A compact theme switcher for AppBar [AppBar.actions]:
/// * tap the sun/moon icon to flip light <-> dark
/// * tap the palette button to choose a primary hue (teal or orange)
class ThemeSwitcher extends StatelessWidget {
  /// When true, icons are rendered in the AppBar's `onPrimary` color.
  /// When false, icons adopt the ambient icon color (useful on light
  /// scaffolds without a colored AppBar).
  final bool onAppBar;
  final bool compact;

  const ThemeSwitcher({
    super.key,
    this.onAppBar = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final theme = Theme.of(context);
    final iconColor = onAppBar
        ? theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary
        : theme.iconTheme.color;

    final modeIcon = controller.isDarkResolved
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: controller.isDarkResolved
              ? 'Switch to light theme'
              : 'Switch to dark theme',
          icon: Icon(modeIcon, color: iconColor),
          onPressed: () => controller.toggleMode(),
        ),
        PopupMenuButton<AppPrimary>(
          tooltip: 'Primary color',
          icon: Icon(Icons.palette_outlined, color: iconColor),
          position: PopupMenuPosition.under,
          onSelected: (p) => controller.setPrimary(p),
          itemBuilder: (context) => [
            _paletteItem(
              value: AppPrimary.teal,
              label: 'Teal primary',
              swatch: AppColors.tealDark,
              accent: AppColors.orangeMid,
              selected: controller.primary == AppPrimary.teal,
            ),
            _paletteItem(
              value: AppPrimary.orange,
              label: 'Orange primary',
              swatch: AppColors.orangeDark,
              accent: AppColors.tealMid,
              selected: controller.primary == AppPrimary.orange,
            ),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<AppPrimary> _paletteItem({
    required AppPrimary value,
    required String label,
    required Color swatch,
    required Color accent,
    required bool selected,
  }) {
    return PopupMenuItem<AppPrimary>(
      value: value,
      child: Row(
        children: [
          _Swatch(primary: swatch, accent: accent),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color primary;
  final Color accent;
  const _Swatch({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 12,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
