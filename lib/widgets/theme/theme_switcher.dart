import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';

/// A compact theme switcher for AppBar [AppBar.actions]:
/// * tap the mode button to flip light <-> dark
/// * tap the palette button to choose a primary hue (teal or orange)
class ThemeSwitcher extends StatelessWidget {
  /// When true, controls are rendered in the AppBar's `onPrimary` color.
  /// When false, controls adopt the ambient foreground color (useful on light
  /// scaffolds without a colored AppBar).
  final bool onAppBar;
  final bool compact;

  const ThemeSwitcher({super.key, this.onAppBar = true, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final theme = Theme.of(context);
    final controlColor =
        onAppBar
            ? theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
    final modeLabel = controller.isDarkResolved ? 'Light' : 'Dark';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: controlColor,
            minimumSize: compact ? const Size(44, 36) : const Size(56, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(modeLabel),
          onPressed: () => controller.toggleMode(),
        ),
        PopupMenuButton<AppPrimary>(
          tooltip: 'Primary color',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              'Color',
              style: TextStyle(
                color: controlColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          position: PopupMenuPosition.under,
          onSelected: (p) => controller.setPrimary(p),
          itemBuilder:
              (context) => [
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
          if (selected)
            Text('Selected', style: TextStyle(fontSize: 12, color: swatch)),
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
