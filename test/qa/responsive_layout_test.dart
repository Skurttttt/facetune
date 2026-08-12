import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/home/presentation/pages/home_page.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_history_repository.dart';

/// Logical sizes that bracket the supported Android range.
///
/// The primary QA target is the POCO X3 GT (1080x2400 at ~2.75x, so roughly
/// 393x873 logical pixels).
const _screens = <String, Size>{
  'small phone': Size(320, 640),
  'POCO X3 GT': Size(393, 873),
  'large tablet': Size(800, 1280),
};

void _useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _scoped({required Widget page, required FakeAuthRepository auth}) =>
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        savedLooksRepositoryProvider.overrideWithValue(
          const UnavailableSavedLooksRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    );

void main() {
  for (final entry in _screens.entries) {
    group('${entry.key} (${entry.value.width}x${entry.value.height})', () {
      testWidgets('home lays out without overflow', (tester) async {
        _useScreen(tester, entry.value);
        final auth = FakeAuthRepository(
          user: const AuthUser(id: 'test-user', isAnonymous: false),
        );
        addTearDown(auth.dispose);

        await tester.pumpWidget(_scoped(page: const HomePage(), auth: auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Start Scan'), findsOneWidget);
      });

      testWidgets('profile lays out without overflow', (tester) async {
        _useScreen(tester, entry.value);
        final auth = FakeAuthRepository(
          user: const AuthUser(id: 'test-user', isAnonymous: false),
        );
        addTearDown(auth.dispose);

        await tester.pumpWidget(_scoped(page: const ProfilePage(), auth: auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('settings lays out without overflow', (tester) async {
        _useScreen(tester, entry.value);
        final auth = FakeAuthRepository(
          user: const AuthUser(id: 'test-user', isAnonymous: false),
        );
        addTearDown(auth.dispose);

        await tester.pumpWidget(
          _scoped(page: const SettingsPage(), auth: auth),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('a guest sees the settings notice without overflow', (
        tester,
      ) async {
        _useScreen(tester, entry.value);
        final auth = FakeAuthRepository(
          user: const AuthUser(id: 'guest-user', isAnonymous: true),
        );
        addTearDown(auth.dispose);

        await tester.pumpWidget(
          _scoped(page: const SettingsPage(), auth: auth),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  }
}
