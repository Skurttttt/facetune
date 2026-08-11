import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/analysis/presentation/pages/analysis_result_page.dart';
import '../../features/authentication/presentation/pages/authentication_page.dart';
import '../../features/authentication/presentation/pages/auth_loading_page.dart';
import '../../features/authentication/presentation/pages/email_login_page.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/registration_page.dart';
import '../../features/authentication/presentation/pages/reset_password_page.dart';
import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/controllers/auth_state.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/makeup_styles/presentation/pages/style_selection_page.dart';
import '../../features/preview/presentation/pages/preview_result_page.dart';
import '../../features/recommendation/presentation/pages/makeup_recommendation_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/saved_looks/presentation/pages/saved_looks_page.dart';
import '../../features/scan/presentation/pages/scan_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/widgets/app_ui.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRouterRefreshNotifier();
  ref
    ..onDispose(refreshNotifier.dispose)
    ..listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != next.status ||
          previous?.user?.id != next.user?.id) {
        refreshNotifier.refresh();
      }
    });

  return GoRouter(
    initialLocation: AppConstants.homeRoute,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      const publicRoutes = {
        AppConstants.authRoute,
        AppConstants.authLoadingRoute,
        AppConstants.emailLoginRoute,
        AppConstants.registerRoute,
        AppConstants.forgotPasswordRoute,
        AppConstants.resetPasswordRoute,
      };
      final isPublicRoute = publicRoutes.contains(location);

      if (authState.status == AuthStatus.passwordRecovery) {
        return location == AppConstants.resetPasswordRoute
            ? null
            : AppConstants.resetPasswordRoute;
      }
      if (!authState.isAuthenticated) {
        return isPublicRoute ? null : AppConstants.authRoute;
      }
      return isPublicRoute ? AppConstants.homeRoute : null;
    },
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
        path: AppConstants.authLoadingRoute,
        name: 'authLoading',
        builder: (context, state) => const AuthLoadingPage(),
      ),
      GoRoute(
        path: AppConstants.emailLoginRoute,
        name: 'emailLogin',
        builder: (context, state) => const EmailLoginPage(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        name: 'register',
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: AppConstants.forgotPasswordRoute,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppConstants.resetPasswordRoute,
        name: 'resetPassword',
        builder: (context, state) => const ResetPasswordPage(),
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
        path: AppConstants.recommendationRoute,
        name: 'recommendation',
        builder: (context, state) => const MakeupRecommendationPage(),
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
        appBar: AppBar(title: const Text('Page unavailable')),
        body: SafeArea(
          child: PageFrame(
            child: Center(
              child: StatusState(
                title: 'Page unavailable',
                message: 'That page could not be opened.',
                icon: Icons.explore_off_outlined,
                actionLabel: 'Return Home',
                onAction: () => context.go(AppConstants.homeRoute),
              ),
            ),
          ),
        ),
      );
    },
  );
});

class _AuthRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
