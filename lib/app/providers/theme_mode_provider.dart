import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_preferences_service.dart';

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    return ref.read(appPreferencesServiceProvider).loadThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await ref.read(appPreferencesServiceProvider).saveThemeMode(mode);
  }

  Future<void> toggleDarkMode(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
