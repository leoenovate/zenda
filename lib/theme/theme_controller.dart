import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Holds the user's light/dark and primary-hue selection and persists it
/// via shared_preferences.
class ThemeController extends ChangeNotifier {
  static const String _modeKey = 'pref.theme_mode';
  static const String _primaryKey = 'pref.theme_primary';

  ThemeMode _mode = ThemeMode.dark;
  AppPrimary _primary = AppPrimary.orange;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  AppPrimary get primary => _primary;
  bool get isLoaded => _loaded;

  bool get isDarkResolved {
    if (_mode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeStr = prefs.getString(_modeKey);
      if (modeStr != null) {
        _mode = ThemeMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => ThemeMode.dark,
        );
      }

      final primaryStr = prefs.getString(_primaryKey);
      if (primaryStr != null) {
        _primary = AppPrimary.values.firstWhere(
          (p) => p.name == primaryStr,
          orElse: () => AppPrimary.orange,
        );
      }
    } catch (_) {
      // Fall back to defaults if prefs are unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setPrimary(AppPrimary primary) async {
    if (_primary == primary) return;
    _primary = primary;
    notifyListeners();
    await _save();
  }

  Future<void> toggleMode() async {
    final next =
        isDarkResolved ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  Future<void> togglePrimary() async {
    final next = _primary == AppPrimary.teal
        ? AppPrimary.orange
        : AppPrimary.teal;
    await setPrimary(next);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, _mode.name);
      await prefs.setString(_primaryKey, _primary.name);
    } catch (_) {
      // ignore
    }
  }
}
