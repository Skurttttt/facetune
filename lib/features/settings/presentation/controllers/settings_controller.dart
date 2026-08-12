import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/settings_providers.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/errors/settings_failure.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_state.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      final userId = ref.watch(
        authControllerProvider.select((state) => state.user?.id),
      );
      final controller = SettingsController(
        ref.watch(settingsRepositoryProvider),
      );
      if (userId != null) {
        controller.load();
      } else {
        controller.markSignedOut();
      }
      return controller;
    });

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repository) : super(SettingsState());

  final SettingsRepository _repository;
  bool _isLoading = false;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    state = SettingsState();
    try {
      final settings = await _repository.load();
      if (mounted) {
        state = SettingsState(status: SettingsStatus.ready, settings: settings);
      }
    } on SettingsFailure catch (failure) {
      if (mounted) {
        state = SettingsState(
          status: SettingsStatus.failure,
          message: failure.message,
          failureKind: failure.kind,
          retryable: failure.retryable,
        );
      }
    } on Object {
      if (mounted) {
        state = SettingsState(
          status: SettingsStatus.failure,
          message: 'Your preferences could not be loaded. Please try again.',
          failureKind: SettingsFailureKind.unknown,
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Presents a terminal signed-out state.
  ///
  /// Without this the controller keeps its initial loading state whenever no
  /// account is active, leaving preferences behind a loader that can never
  /// resolve.
  void markSignedOut() {
    _isLoading = false;
    state = SettingsState(
      status: SettingsStatus.failure,
      message: 'Sign in again to manage your FaceTune preferences.',
      failureKind: SettingsFailureKind.sessionExpired,
      retryable: false,
    );
  }

  Future<void> updateTheme(AppThemePreference theme) => _update(
    operation: SettingsOperation.theme,
    optimistic: state.settings.copyWith(theme: theme),
    action: () => _repository.updateTheme(theme),
    successMessage: 'Theme preference saved.',
  );

  Future<void> updateNotifications(bool enabled) => _update(
    operation: SettingsOperation.notifications,
    optimistic: state.settings.copyWith(notificationsEnabled: enabled),
    action: () => _repository.updateNotifications(enabled),
    successMessage: 'Notification preference saved.',
  );

  Future<void> updateAnalyticsConsent(bool consented) => _update(
    operation: SettingsOperation.analytics,
    optimistic: state.settings.copyWith(analyticsConsent: consented),
    action: () => _repository.updateAnalyticsConsent(consented),
    successMessage: consented
        ? 'Analytics consent saved.'
        : 'Analytics consent withdrawn.',
  );

  Future<void> _update({
    required SettingsOperation operation,
    required UserSettings optimistic,
    required Future<UserSettings> Function() action,
    required String successMessage,
  }) async {
    if (state.activeOperation != null) return;
    final previous = state.settings;
    state = SettingsState(
      status: SettingsStatus.ready,
      settings: optimistic,
      activeOperation: operation,
    );
    try {
      final saved = await action();
      if (mounted) {
        state = SettingsState(
          status: SettingsStatus.ready,
          settings: saved,
          feedback: successMessage,
        );
      }
    } on SettingsFailure catch (failure) {
      if (mounted) _handleUpdateFailure(failure, previous);
    } on Object {
      if (mounted) {
        _handleUpdateFailure(
          const SettingsFailure(
            'Your preference could not be saved. Please try again.',
          ),
          previous,
        );
      }
    }
  }

  void _handleUpdateFailure(SettingsFailure failure, UserSettings previous) {
    if (failure.kind == SettingsFailureKind.sessionExpired) {
      state = SettingsState(
        status: SettingsStatus.failure,
        settings: previous,
        message: failure.message,
        failureKind: failure.kind,
        retryable: failure.retryable,
      );
      return;
    }
    state = SettingsState(
      status: SettingsStatus.ready,
      settings: previous,
      feedback: failure.message,
      feedbackIsError: true,
    );
  }

  void clearFeedback() {
    state = SettingsState(
      status: state.status,
      settings: state.settings,
      message: state.message,
      failureKind: state.failureKind,
      retryable: state.retryable,
    );
  }
}
