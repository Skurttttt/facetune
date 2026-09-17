import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../features/settings/presentation/controllers/theme_mode_controller.dart';
import '../features/subscription/presentation/widgets/subscription_resume_refresher.dart';
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
      // Wrapped above the navigator so one listener covers the whole app: a
      // subscription can renew, lapse, or be refunded while the app is in the
      // background, and returning to the foreground re-asks the server rather
      // than trusting what was on screen before. See the widget for why this
      // is a display concern and never an entitlement decision.
      builder: (context, child) =>
          SubscriptionResumeRefresher(child: child ?? const SizedBox.shrink()),
    );
  }
}
