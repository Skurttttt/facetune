import 'dart:async';

import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:facetune/features/settings/domain/errors/settings_failure.dart';
import 'package:facetune/features/settings/presentation/controllers/settings_controller.dart';
import 'package:facetune/features/settings/presentation/controllers/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';

void main() {
  group('SettingsController', () {
    test('loads persisted theme and preference values', () async {
      final repository = FakeSettingsRepository(
        settings: _settings(
          theme: AppThemePreference.light,
          notificationsEnabled: false,
          analyticsConsent: true,
        ),
      );
      final controller = SettingsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, SettingsStatus.ready);
      expect(controller.state.settings.theme, AppThemePreference.light);
      expect(controller.state.settings.notificationsEnabled, isFalse);
      expect(controller.state.settings.analyticsConsent, isTrue);
      expect(controller.state.message, isNull);
    });

    test('reports a friendly settings load failure', () async {
      final controller = SettingsController(
        _FailingSettingsRepository(failLoad: true),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, SettingsStatus.failure);
      expect(controller.state.message, 'Settings could not be loaded.');
      expect(controller.state.settings.theme, AppThemePreference.system);
    });

    test(
      'applies theme optimistically and keeps the persisted result',
      () async {
        final repository = _DeferredThemeSettingsRepository();
        final controller = SettingsController(repository);
        addTearDown(controller.dispose);
        await controller.load();

        final update = controller.updateTheme(AppThemePreference.dark);

        expect(controller.state.settings.theme, AppThemePreference.dark);
        expect(controller.state.activeOperation, SettingsOperation.theme);
        repository.completeTheme();
        await update;

        expect(repository.requestedTheme, AppThemePreference.dark);
        expect(controller.state.settings.theme, AppThemePreference.dark);
        expect(controller.state.activeOperation, isNull);
        expect(controller.state.feedback, 'Theme preference saved.');
        expect(controller.state.feedbackIsError, isFalse);
      },
    );

    test('persists notification and analytics preferences', () async {
      final repository = FakeSettingsRepository();
      final controller = SettingsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.updateNotifications(false);

      expect(repository.settings.notificationsEnabled, isFalse);
      expect(controller.state.settings.notificationsEnabled, isFalse);
      expect(controller.state.feedback, 'Notification preference saved.');

      await controller.updateAnalyticsConsent(true);

      expect(repository.settings.analyticsConsent, isTrue);
      expect(controller.state.settings.analyticsConsent, isTrue);
      expect(controller.state.feedback, 'Analytics consent saved.');
    });

    test(
      'rolls back an optimistic preference when persistence fails',
      () async {
        final repository = _FailingSettingsRepository(failNotifications: true);
        final controller = SettingsController(repository);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.state.settings.notificationsEnabled, isTrue);

        await controller.updateNotifications(false);

        expect(controller.state.status, SettingsStatus.ready);
        expect(controller.state.settings.notificationsEnabled, isTrue);
        expect(controller.state.activeOperation, isNull);
        expect(
          controller.state.feedback,
          'Notification preference was not saved.',
        );
        expect(controller.state.feedbackIsError, isTrue);
      },
    );
  });
}

UserSettings _settings({
  AppThemePreference theme = AppThemePreference.system,
  bool notificationsEnabled = true,
  bool analyticsConsent = false,
}) => UserSettings(
  userId: 'test-user',
  theme: theme,
  notificationsEnabled: notificationsEnabled,
  analyticsConsent: analyticsConsent,
  createdAt: DateTime.utc(2026, 8, 11),
  updatedAt: DateTime.utc(2026, 8, 11),
);

class _DeferredThemeSettingsRepository extends FakeSettingsRepository {
  final _themeCompleter = Completer<UserSettings>();
  AppThemePreference? requestedTheme;

  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) {
    requestedTheme = theme;
    return _themeCompleter.future;
  }

  void completeTheme() {
    final theme = requestedTheme;
    if (theme == null) throw StateError('No theme update is pending.');
    settings = settings.copyWith(theme: theme);
    _themeCompleter.complete(settings);
  }
}

class _FailingSettingsRepository extends FakeSettingsRepository {
  _FailingSettingsRepository({
    this.failLoad = false,
    this.failNotifications = false,
  });

  final bool failLoad;
  final bool failNotifications;

  @override
  Future<UserSettings> load() {
    if (failLoad) {
      return Future.error(
        const SettingsFailure('Settings could not be loaded.'),
      );
    }
    return super.load();
  }

  @override
  Future<UserSettings> updateNotifications(bool enabled) {
    if (failNotifications) {
      return Future.error(
        const SettingsFailure('Notification preference was not saved.'),
      );
    }
    return super.updateNotifications(enabled);
  }
}
