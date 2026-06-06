import 'dart:html' as html;

import '../theme/app_colors.dart';

/// Syncs the browser tab favicon and `theme-color` meta with the active theme.
void syncWebBrand({
  required AppPrimary primary,
  required bool isDark,
}) {
  final mode = isDark ? 'dark' : 'light';
  final faviconHref = 'favicons/${primary.name}_$mode.png';

  final favicon =
      html.document.getElementById('app-favicon') as html.LinkElement?;
  if (favicon != null) {
    favicon.href = faviconHref;
  } else {
    final link = html.LinkElement()
      ..id = 'app-favicon'
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = faviconHref;
    html.document.head?.append(link);
  }

  final themeColor = _themeColorHex(primary: primary, isDark: isDark);
  final themeMeta =
      html.document.getElementById('app-theme-color') as html.MetaElement?;
  if (themeMeta != null) {
    themeMeta.content = themeColor;
  } else {
    final meta = html.MetaElement()
      ..id = 'app-theme-color'
      ..name = 'theme-color'
      ..content = themeColor;
    html.document.head?.append(meta);
  }
}

String _themeColorHex({required AppPrimary primary, required bool isDark}) {
  if (isDark) {
    return '#0F1414';
  }
  return switch (primary) {
    AppPrimary.teal => '#1A5F5F',
    AppPrimary.orange => '#C65A1F',
  };
}
