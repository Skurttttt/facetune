class AppConstants {
  const AppConstants._();

  static const String appName = 'FaceTune';
  static const String appTagline = 'Your AI Makeup Artist';
  static const String homeTitle = 'FaceTune';
  static const String homeSubtitle = 'Ready for your next beauty experience';
  static const String placeholderTitle = 'Coming soon';
  static const String placeholderMessage =
      'This route is reserved for a future FaceTune feature.';

  static const String homeRoute = '/';
  static const String authRoute = '/auth';
  static const String authLoadingRoute = '/auth/loading';
  static const String emailLoginRoute = '/auth/email';
  static const String registerRoute = '/auth/register';
  static const String forgotPasswordRoute = '/auth/forgot-password';
  static const String resetPasswordRoute = '/auth/reset-password';
  static const String scanRoute = '/scan';
  static const String stylesRoute = '/styles';
  static const String analysisRoute = '/analysis';
  static const String previewRoute = '/preview';
  static const String savedRoute = '/saved';
  static const String historyRoute = '/history';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';

  static const String authCallbackUrl = 'io.facetune.app://login-callback/';
  static const String passwordResetCallbackUrl =
      'io.facetune.app://reset-callback/';

  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double radiusLarge = 24;
}
