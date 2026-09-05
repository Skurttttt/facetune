import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/presentation/pages/analysis_result_page.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/presentation/pages/authentication_page.dart';
import 'package:facetune/features/authentication/presentation/pages/email_login_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/history/presentation/pages/history_page.dart';
import 'package:facetune/features/home/presentation/pages/home_page.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart';
import 'package:facetune/features/makeup_styles/presentation/pages/style_selection_page.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/preview/presentation/pages/preview_result_page.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/presentation/pages/saved_looks_page.dart';
import 'package:facetune/features/scan/presentation/pages/live_camera_page.dart';
import 'package:facetune/features/scan/presentation/pages/scan_page.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_history_repository.dart';
import '../helpers/fake_library_repositories.dart';

typedef _PageFactory = Widget Function();

class _ScreenCase {
  const _ScreenCase(this.name, this.page, this.landmark);

  final String name;
  final _PageFactory page;
  final String landmark;
}

class _Condition {
  const _Condition({
    required this.name,
    required this.size,
    required this.textScale,
    required this.themeMode,
    required this.platformBrightness,
  });

  final String name;
  final Size size;
  final double textScale;
  final ThemeMode themeMode;
  final Brightness platformBrightness;

  Brightness get expectedBrightness => switch (themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };
}

const _conditions = <_Condition>[
  _Condition(
    name: 'Light, 320 logical px, 2x text',
    size: Size(320, 800),
    textScale: 2,
    themeMode: ThemeMode.light,
    platformBrightness: Brightness.dark,
  ),
  _Condition(
    name: 'Dark, POCO X3 GT, default text',
    size: Size(393, 873),
    textScale: 1,
    themeMode: ThemeMode.dark,
    platformBrightness: Brightness.light,
  ),
  _Condition(
    name: 'System light, POCO X3 GT, default text',
    size: Size(393, 873),
    textScale: 1,
    themeMode: ThemeMode.system,
    platformBrightness: Brightness.light,
  ),
  _Condition(
    name: 'System dark, POCO X3 GT, default text',
    size: Size(393, 873),
    textScale: 1,
    themeMode: ThemeMode.system,
    platformBrightness: Brightness.dark,
  ),
];

final _screens = <_ScreenCase>[
  _ScreenCase('auth / entry', AuthenticationPage.new, 'Meet the look'),
  _ScreenCase('home / start', HomePage.new, 'Start Scan'),
  _ScreenCase('selfie', ScanPage.new, 'New scan'),
  // Landmarked on the app bar rather than a guidance string: with no camera
  // plugin behind a widget test the screen settles into a startup or
  // unavailable state, and which one is not the point here. What the matrix
  // checks is that the page renders and scrolls safely in every theme.
  _ScreenCase('live camera', LiveCameraPage.new, 'New scan'),
  _ScreenCase('analysis', AnalysisResultPage.new, 'Analysis unavailable'),
  _ScreenCase(
    'style selection',
    StyleSelectionPage.new,
    'Select a style to continue',
  ),
  _ScreenCase('final preview', PreviewResultPage.new, 'Result unavailable'),
  _ScreenCase('History', HistoryPage.new, 'History'),
  // POLISH-P4: two of the four top-level tabs were never in this matrix, so
  // Saved and Profile were the only screens in the app whose theme and
  // large-text behaviour nothing checked.
  _ScreenCase('Saved', SavedLooksPage.new, 'Saved looks'),
  _ScreenCase('Profile', ProfilePage.new, 'Profile'),
  _ScreenCase(
    'My Makeup Kit',
    MakeupKitOverviewPage.new,
    'My Makeup Kit unavailable',
  ),
];

void _configureView(WidgetTester tester, _Condition condition) {
  tester.view.physicalSize = condition.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = condition.textScale;
  tester.platformDispatcher.platformBrightnessTestValue =
      condition.platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

Future<void> _pumpPage(
  WidgetTester tester,
  _ScreenCase screen,
  _Condition condition,
) async {
  _configureView(tester, condition);
  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'matrix-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Keep every page on its real controller while replacing only external
        // repositories. No matrix case may reach a device picker, network, or
        // paid service merely because it was rendered.
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        savedLooksRepositoryProvider.overrideWithValue(
          FakeSavedLooksRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        faceAnalysisRepositoryProvider.overrideWithValue(
          const UnavailableFaceAnalysisRepository(),
        ),
        makeupRecommendationRepositoryProvider.overrideWithValue(
          const UnavailableMakeupRecommendationRepository(),
        ),
        makeupPreviewRepositoryProvider.overrideWithValue(
          const UnavailableMakeupPreviewRepository(),
        ),
        makeupKitProductsRepositoryProvider.overrideWithValue(
          const UnavailableMakeupKitProductsRepository(),
        ),
        makeupKitLibraryRepositoryProvider.overrideWithValue(
          FakeMakeupKitLibraryRepository(),
        ),
        appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: condition.themeMode,
        home: screen.page(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _exerciseVerticalScrolling(WidgetTester tester) async {
  // Traverse every vertical viewport. Repeating matters for lazy slivers: their
  // final extent grows as off-screen children are built.
  for (var pass = 0; pass < 12; pass++) {
    var moved = false;
    final scrollables = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where((state) => state.position.axis == Axis.vertical)
        .toList(growable: false);
    for (final state in scrollables) {
      final position = state.position;
      if (!position.hasContentDimensions ||
          position.pixels >= position.maxScrollExtent) {
        continue;
      }
      position.jumpTo(
        (position.pixels + 600).clamp(0, position.maxScrollExtent),
      );
      moved = true;
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (!moved) break;
  }
}

void main() {
  group('UI-P6 full-page responsive and theme matrix', () {
    for (final condition in _conditions) {
      group(condition.name, () {
        for (final screen in _screens) {
          testWidgets('${screen.name} renders and scrolls safely', (
            tester,
          ) async {
            await _pumpPage(tester, screen, condition);

            expect(
              find.textContaining(screen.landmark),
              findsWidgets,
              reason: '${screen.name} never reached its expected UI state',
            );
            expect(
              Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
              condition.expectedBrightness,
            );
            expect(tester.takeException(), isNull);

            await _exerciseVerticalScrolling(tester);
            expect(tester.takeException(), isNull);
          });
        }
      });
    }
  });

  group('UI-P6 full-page accessibility matrix', () {
    for (final screen in _screens) {
      testWidgets('${screen.name} has labelled Android-sized tap targets', (
        tester,
      ) async {
        await _pumpPage(tester, screen, _conditions[1]);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }

    testWidgets('email login remains focusable above a simulated keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const EmailLoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextFormField).last);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.byType(AuthSubmitButton)).dy,
        lessThanOrEqualTo(640 - 280),
      );
    });
  });
}
