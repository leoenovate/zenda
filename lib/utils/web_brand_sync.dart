import '../theme/app_colors.dart';

import 'web_brand_sync_stub.dart'
    if (dart.library.html) 'web_brand_sync_web.dart' as impl;

/// Syncs web tab favicon + `theme-color` meta with the active app theme.
void syncWebBrand({
  required AppPrimary primary,
  required bool isDark,
}) {
  impl.syncWebBrand(primary: primary, isDark: isDark);
}
