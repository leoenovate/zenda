import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light + dark [ThemeData] for the app following the
/// 60-30-20 teal + orange rule.
class AppTheme {
  AppTheme._();

  // Text sizing kept in sync with the original inline theme from main.dart.
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
  );

  static ThemeData light({required AppPrimary primary}) {
    final brand = BrandHues.forPrimary(primary);
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: brand.primary,
      onPrimary: Colors.white,
      primaryContainer: brand.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: brand.secondary,
      onSecondary: Colors.white,
      secondaryContainer: brand.secondaryContainer,
      onSecondaryContainer: AppColors.neutralLightTextPrimary,
      tertiary: brand.secondary,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.neutralLightSurface,
      onSurface: AppColors.neutralLightTextPrimary,
      surfaceContainerLowest: AppColors.neutralLightBg,
      surfaceContainerLow: AppColors.neutralLightBg,
      surfaceContainer: AppColors.neutralLightSurfaceAlt,
      surfaceContainerHigh: AppColors.neutralLightSurfaceAlt,
      onSurfaceVariant: AppColors.neutralLightTextSecondary,
      outline: AppColors.neutralLightOutline,
      outlineVariant: AppColors.neutralLightOutline,
      shadow: Colors.black26,
      scrim: Colors.black54,
      inverseSurface: AppColors.neutralDarkSurface,
      onInverseSurface: AppColors.neutralDarkTextPrimary,
      inversePrimary: brand.primaryContainer,
    );
    return _build(scheme, brightness: Brightness.light);
  }

  static ThemeData dark({required AppPrimary primary}) {
    final brand = BrandHues.forPrimary(primary);
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brand.primaryContainer,
      onPrimary: Colors.white,
      primaryContainer: brand.primary,
      onPrimaryContainer: Colors.white,
      secondary: brand.secondary,
      onSecondary: Colors.white,
      secondaryContainer: brand.secondary,
      onSecondaryContainer: Colors.white,
      tertiary: brand.secondary,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.neutralDarkSurface,
      onSurface: AppColors.neutralDarkTextPrimary,
      surfaceContainerLowest: AppColors.neutralDarkBg,
      surfaceContainerLow: AppColors.neutralDarkBg,
      surfaceContainer: AppColors.neutralDarkSurfaceAlt,
      surfaceContainerHigh: AppColors.neutralDarkSurfaceAlt,
      onSurfaceVariant: AppColors.neutralDarkTextSecondary,
      outline: AppColors.neutralDarkOutline,
      outlineVariant: AppColors.neutralDarkOutline,
      shadow: Colors.black54,
      scrim: Colors.black87,
      inverseSurface: AppColors.neutralLightSurface,
      onInverseSurface: AppColors.neutralLightTextPrimary,
      inversePrimary: brand.primary,
    );
    return _build(scheme, brightness: Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? AppColors.neutralDarkBg : AppColors.neutralLightBg;
    final cardBg = scheme.surface;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      textTheme: _textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: _textTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onPrimary),
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: isDark ? 2 : 1,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.neutralDarkSurfaceAlt
            : AppColors.neutralLightSurfaceAlt,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.secondary,
        secondarySelectedColor: scheme.secondary,
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.secondary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.secondary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.secondary.withValues(alpha: 0.5);
          }
          return scheme.surfaceContainerHigh;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
        indicatorColor: scheme.secondary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
    );
  }
}
