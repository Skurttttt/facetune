import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'admin_router.dart';

/// The Web Admin application widget.
///
/// Reuses the project theme so the two surfaces share tokens, but is a
/// separate app with its own router: nothing from the consumer navigation,
/// subscription refreshers, or camera flows is mounted here.
class FaceTuneAdminApp extends ConsumerWidget {
  const FaceTuneAdminApp({super.key});

  static const title = 'FaceTune Admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
