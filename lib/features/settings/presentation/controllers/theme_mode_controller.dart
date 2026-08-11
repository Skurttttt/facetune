import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_settings.dart';
import 'settings_controller.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(
    settingsControllerProvider.select((state) => state.settings.theme),
  );
  return switch (preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
});
