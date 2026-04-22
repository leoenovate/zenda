import 'package:flutter/material.dart';

/// Which hue the user has chosen as the dominant brand color.
///
/// The other hue is automatically assigned to the secondary/accent slot,
/// following the cinematic teal-and-orange contrast.
enum AppPrimary { teal, orange }

/// Raw palette constants for the teal + orange theme.
///
/// Organized around the 60-30-20 rule:
///   60% dominant — neutral surfaces (near-black / warm off-white)
///   30% secondary — the selected primary hue (teal or orange)
///   10% accent — the complementary hue
class AppColors {
  AppColors._();

  static const Color tealDark = Color(0xFF1A5F5F);
  static const Color tealDeep = Color(0xFF0F3D3D);
  static const Color tealMid = Color(0xFF2A8A8A);
  static const Color tealSoft = Color(0xFFB8D8D8);

  static const Color orangeDark = Color(0xFFC65A1F);
  static const Color orangeDeep = Color(0xFF8A3E11);
  static const Color orangeMid = Color(0xFFE07A3C);
  static const Color orangeSoft = Color(0xFFF5D3B8);

  static const Color neutralLightBg = Color(0xFFFAF7F2);
  static const Color neutralLightSurface = Color(0xFFFFFFFF);
  static const Color neutralLightSurfaceAlt = Color(0xFFF1EDE6);
  static const Color neutralLightOutline = Color(0xFFE0DCD3);
  static const Color neutralLightTextPrimary = Color(0xFF1F2223);
  static const Color neutralLightTextSecondary = Color(0xFF5A605F);

  static const Color neutralDarkBg = Color(0xFF0F1414);
  static const Color neutralDarkSurface = Color(0xFF172022);
  static const Color neutralDarkSurfaceAlt = Color(0xFF1E292B);
  static const Color neutralDarkOutline = Color(0xFF2E3A3C);
  static const Color neutralDarkTextPrimary = Color(0xFFE8EDEC);
  static const Color neutralDarkTextSecondary = Color(0xFFA7B1B0);

  static const Color success = Color(0xFF2E9D63);
  static const Color warning = Color(0xFFE0A23C);
  static const Color danger = Color(0xFFD14C4C);
  static const Color info = Color(0xFF3A8FB7);
}

/// A resolved pair of brand hues for a given [AppPrimary] selection.
class BrandHues {
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;

  const BrandHues({
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
  });

  static BrandHues forPrimary(AppPrimary primary) {
    switch (primary) {
      case AppPrimary.teal:
        return const BrandHues(
          primary: AppColors.tealDark,
          primaryContainer: AppColors.tealMid,
          secondary: AppColors.orangeMid,
          secondaryContainer: AppColors.orangeSoft,
        );
      case AppPrimary.orange:
        return const BrandHues(
          primary: AppColors.orangeDark,
          primaryContainer: AppColors.orangeMid,
          secondary: AppColors.tealMid,
          secondaryContainer: AppColors.tealSoft,
        );
    }
  }
}
