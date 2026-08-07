import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../features/settings/presentation/controllers/theme_mode_controller.dart';
import '../theme/app_theme.dart';
import 'router/app_router.dart';

class FaceTuneApp extends ConsumerWidget {
  const FaceTuneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appConfig = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: appConfig.debugShowCheckedModeBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
