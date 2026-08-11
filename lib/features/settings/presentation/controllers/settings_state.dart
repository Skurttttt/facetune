import '../../domain/entities/user_settings.dart';
import '../../domain/errors/settings_failure.dart';

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
    this.failureKind,
    this.retryable = true,
  }) : settings = settings ?? UserSettings.defaults();

  final SettingsStatus status;
  final UserSettings settings;
  final SettingsOperation? activeOperation;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
  final SettingsFailureKind? failureKind;
  final bool retryable;
}
