import 'dart:io';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

/// PSUX-P2: Settings reads as Appearance, Preferences, Privacy, About, Account.
///
/// The regrouping is presentation-only. These tests hold what it must not
/// have moved: each control still writes the same field through the same
/// repository call, each information row still opens the same dialog, and
/// sign-out still goes through the same confirmation to the same auth call.
///
/// PSUX-P3 adds the truthfulness rules: notifications are shown as coming soon
/// rather than as a working switch, without touching the stored preference,
/// and the version is the installed package's, formatted rather than typed in.
void main() {
  group('Settings information architecture', () {
    testWidgets(
      'sections run Appearance, Preferences, Privacy, About, Account',
      (tester) async {
        await _pump(tester, tall: true);

        double top(Finder finder) => tester.getTopLeft(finder).dy;
        final headers = [
          for (final title in _sections)
            top(
              find.descendant(
                of: find.byType(SectionHeader),
                matching: find.text(title),
              ),
            ),
        ];
        for (var i = 1; i < headers.length; i++) {
          expect(headers[i], greaterThan(headers[i - 1]), reason: _sections[i]);
        }
        expect(find.text('Privacy and about'), findsNothing);

        void inSection(String row, String section) {
          final index = _sections.indexOf(section);
          final y = top(find.text(row));
          expect(y, greaterThan(headers[index]), reason: '$row under $section');
          if (index + 1 < headers.length) {
            expect(
              y,
              lessThan(headers[index + 1]),
              reason: '$row under $section',
            );
          }
        }

        inSection('Theme', 'Appearance');
        inSection('Notifications', 'Preferences');
        inSection('Image privacy', 'Privacy');
        inSection('Analytics consent', 'Privacy');
        inSection('Privacy policy', 'Privacy');
        inSection('About FaceTune', 'About');
        inSection('App version', 'About');
        inSection('Sign out', 'Account');
      },
    );

    testWidgets('theme still offers System, Light and Dark and saves each', (
      tester,
    ) async {
      final harness = await _pump(tester, tall: true);

      final segments = tester
          .widget<SegmentedButton<AppThemePreference>>(
            find.byType(SegmentedButton<AppThemePreference>),
          )
          .segments
          .map((segment) => segment.value);
      expect(segments, AppThemePreference.values);

      for (final (label, value) in [
        ('Dark', AppThemePreference.dark),
        ('Light', AppThemePreference.light),
        ('System', AppThemePreference.system),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(harness.settings.settings.theme, value);
      }
      expect(harness.settings.writes, ['theme', 'theme', 'theme']);
    });

    for (final stored in [true, false]) {
      testWidgets(
        'notifications read as coming soon and leave the stored $stored alone',
        (tester) async {
          final harness = await _pump(
            tester,
            tall: true,
            notificationsEnabled: stored,
          );

          final row = find.byKey(const ValueKey('settings-notifications'));
          expect(
            find.descendant(of: row, matching: find.text('Notifications')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.text('Coming soon')),
            findsOneWidget,
          );
          // Nothing that looks like, or acts as, a control.
          expect(tester.widget<ListTile>(row).onTap, isNull);
          expect(
            find.descendant(of: row, matching: find.byType(Switch)),
            findsNothing,
          );
          expect(_switch('Notification preference'), findsNothing);
          expect(find.byType(Switch), findsOneWidget, reason: 'analytics only');

          await tester.tap(row);
          await tester.pumpAndSettle();

          expect(harness.settings.writes, isEmpty);
          expect(harness.settings.settings.notificationsEnabled, stored);
        },
      );
    }

    testWidgets('the analytics switch writes only its own field', (
      tester,
    ) async {
      final harness = await _pump(tester, tall: true);

      await tester.tap(_switch('Analytics consent'));
      await tester.pumpAndSettle();

      expect(harness.settings.writes, ['analytics']);
      expect(harness.settings.settings.analyticsConsent, isTrue);
      expect(harness.settings.settings.notificationsEnabled, isTrue);
    });

    for (final info in _dialogs) {
      testWidgets('${info.row} still opens the same dialog', (tester) async {
        final harness = await _pump(tester, tall: true);

        await tester.tap(find.text(info.row));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text(info.row)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text(info.message)),
          findsOneWidget,
        );
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(harness.settings.writes, isEmpty);
      });
    }

    testWidgets('the version has its own informational row', (tester) async {
      await _pump(tester, tall: true);

      final row = find.byKey(const ValueKey('settings-app-version'));
      expect(
        find.descendant(of: row, matching: find.text('1.1.0 (build 7)')),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(row).onTap, isNull);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'About FaceTune'),
          matching: find.textContaining('Version'),
        ),
        findsNothing,
      );
    });

    for (final (raw, shown) in [
      ('1.1.0+7', '1.1.0 (build 7)'),
      ('2.0.0', '2.0.0'),
      ('2.0.0+', '2.0.0+'),
    ]) {
      testWidgets('version "$raw" reads "$shown"', (tester) async {
        await _pump(tester, tall: true, version: () async => raw);

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings-app-version')),
            matching: find.text(shown),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('an unreadable version says so rather than guessing', (
      tester,
    ) async {
      await _pump(
        tester,
        tall: true,
        version: () async => throw StateError('no package info'),
      );

      expect(find.text('Version unavailable'), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('the theme control survives 2x text, narrow, ${mode.name}', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          screen: const Size(320, 640),
          textScale: 2,
          themeMode: mode,
        );

        expect(tester.takeException(), isNull);
        for (final label in ['System', 'Light', 'Dark']) {
          final segment = tester.getRect(find.text(label));
          final control = tester.getRect(
            find.byType(SegmentedButton<AppThemePreference>),
          );
          expect(
            segment.left,
            greaterThanOrEqualTo(control.left),
            reason: label,
          );
          expect(
            segment.right,
            lessThanOrEqualTo(control.right),
            reason: label,
          );
        }

        // At 2x the control starts just below the fold; reach it as a user
        // would, then it must still work.
        await tester.ensureVisible(find.text('Dark'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(harness.settings.settings.theme, AppThemePreference.dark);

        await tester.scrollUntilVisible(
          find.text('Sign out'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every control is labelled and Android-sized', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, tall: true);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('sign out is the last action and keeps its confirmation', (
      tester,
    ) async {
      // Default test surface, so the action must be scrolled to.
      final harness = await _pump(tester);

      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final view = tester.getRect(find.byType(ListView));
      final button = tester.getRect(find.byType(SecondaryButton));
      expect(button.bottom, lessThanOrEqualTo(view.bottom));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      expect(harness.auth.signOuts, 0, reason: 'nothing before confirming');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.auth.signOuts, 1);
      expect(harness.settings.writes, isEmpty);
    });

    testWidgets('loads settings once and nothing else', (tester) async {
      final harness = await _pump(tester, tall: true);

      expect(harness.settings.loads, 1);
      expect(harness.settings.writes, isEmpty);
    });

    test('the page source has no AI dependency', () {
      final source = File(
        'lib/features/settings/presentation/pages/settings_page.dart',
      ).readAsStringSync();
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!);
      for (final path in imports) {
        expect(
          path,
          isNot(
            matches(
              RegExp(
                r'features/(analysis|preview|recommendation|tutorial|makeup_kit|scan)/',
              ),
            ),
          ),
        );
      }
    });
  });
}

const _sections = ['Appearance', 'Preferences', 'Privacy', 'About', 'Account'];

const _dialogs = [
  (
    row: 'Image privacy',
    message:
        'Original selfies, generated previews, and profile photos are stored privately. FaceTune uses short-lived signed links for display. Delete a History session to remove its selfie, previews, recommendations, and saved links.',
  ),
  (
    row: 'Privacy policy',
    message:
        'A production privacy-policy link has not been published yet. This placeholder does not represent a legal policy.',
  ),
  (
    row: 'About FaceTune',
    message:
        'FaceTune creates personalized, brand-neutral makeup inspiration and identity-conscious AI previews. AI results can vary.',
  ),
];

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

class _CountingSettingsRepository extends FakeSettingsRepository {
  int loads = 0;
  final writes = <String>[];

  @override
  Future<UserSettings> load() {
    loads++;
    return super.load();
  }

  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) {
    writes.add('theme');
    return super.updateTheme(theme);
  }

  @override
  Future<UserSettings> updateNotifications(bool enabled) {
    writes.add('notifications');
    return super.updateNotifications(enabled);
  }

  @override
  Future<UserSettings> updateAnalyticsConsent(bool consented) {
    writes.add('analytics');
    return super.updateAnalyticsConsent(consented);
  }
}

class _CountingAuthRepository extends FakeAuthRepository {
  _CountingAuthRepository()
    : super(
        user: const AuthUser(
          id: 'registered-user',
          email: 'mia@example.com',
          isAnonymous: false,
        ),
      );

  int signOuts = 0;

  @override
  Future<void> signOut() {
    signOuts++;
    return super.signOut();
  }
}

typedef _Harness = ({
  _CountingSettingsRepository settings,
  _CountingAuthRepository auth,
});

Future<_Harness> _pump(
  WidgetTester tester, {
  bool tall = false,
  bool notificationsEnabled = true,
  Future<String> Function()? version,
  double textScale = 1,
  Size? screen,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  if (tall || screen != null) {
    // Tall: every section built at once, so order is asserted on the whole
    // page. A named screen is a real phone size, in logical pixels.
    tester.view
      ..physicalSize = screen == null ? const Size(1080, 7200) : screen * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  final auth = _CountingAuthRepository();
  addTearDown(auth.dispose);
  final settings = _CountingSettingsRepository()
    ..settings = UserSettings.defaults().copyWith(
      notificationsEnabled: notificationsEnabled,
    );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        settingsRepositoryProvider.overrideWithValue(settings),
        appVersionProvider.overrideWith(
          (ref) => (version ?? () async => '1.1.0+7')(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (settings: settings, auth: auth);
}
