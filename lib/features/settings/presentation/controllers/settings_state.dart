import '../../domain/entities/user_settings.dart';

enum SettingsStatus { loading, ready, failure }

enum SettingsOperation { theme, notifications, analytics }

class SettingsState {
  SettingsState({
    this.status = SettingsStatus.loading,
    UserSettings? settings,
    this.activeOperation,
    this.message,
    this.feedback,
    this.feedbackIsError = false,
  }) : settings = settings ?? UserSettings.defaults();

  final SettingsStatus status;
  final UserSettings settings;
  final SettingsOperation? activeOperation;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
}
