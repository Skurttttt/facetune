import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/admin_theme.dart';
import 'admin_router.dart';

/// The Web Admin application widget.
///
/// A separate app with its own router: nothing from the consumer navigation,
/// subscription refreshers, or camera flows is mounted here.
///
/// Since WA-13.5-UI-1 it also has its own theme. It no longer reads
/// `lib/theme/app_theme.dart`, because that object is the consumer
/// application's and an operations console has different needs; keeping them
/// separate means neither surface can restyle the other by accident.
class FaceTuneAdminApp extends ConsumerWidget {
  const FaceTuneAdminApp({super.key});

  static const title = 'FaceTune Admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark,
      darkTheme: AdminTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
