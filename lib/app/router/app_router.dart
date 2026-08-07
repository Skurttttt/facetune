import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/analysis/presentation/pages/analysis_result_page.dart';
import '../../features/authentication/presentation/pages/authentication_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/makeup_styles/presentation/pages/style_selection_page.dart';
import '../../features/preview/presentation/pages/preview_result_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/saved_looks/presentation/pages/saved_looks_page.dart';
import '../../features/scan/presentation/pages/scan_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.homeRoute,
    routes: [
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppConstants.authRoute,
        name: 'auth',
        builder: (context, state) => const AuthenticationPage(),
      ),
      GoRoute(
        path: AppConstants.scanRoute,
        name: 'scan',
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: AppConstants.stylesRoute,
        name: 'styles',
        builder: (context, state) => const StyleSelectionPage(),
      ),
      GoRoute(
        path: AppConstants.analysisRoute,
        name: 'analysis',
        builder: (context, state) => const AnalysisResultPage(),
      ),
      GoRoute(
        path: AppConstants.previewRoute,
        name: 'preview',
        builder: (context, state) => const PreviewResultPage(),
      ),
      GoRoute(
        path: AppConstants.savedRoute,
        name: 'saved',
        builder: (context, state) => const SavedLooksPage(),
      ),
      GoRoute(
        path: AppConstants.historyRoute,
        name: 'history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: AppConstants.profileRoute,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppConstants.settingsRoute,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route not found')),
        body: Center(
          child: Text('No route found for ${state.matchedLocation}'),
        ),
      );
    },
  );
});
