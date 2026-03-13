import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_storage_keys.dart';

final appPreferencesServiceProvider = Provider<AppPreferencesService>(
  (ref) => AppPreferencesService(),
);

class AppPreferencesService {
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(AppStorageKeys.themeMode);
    return _themeModeFromStorage(rawValue);
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStorageKeys.themeMode, _themeModeToStorage(mode));
  }

  ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
