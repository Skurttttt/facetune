import 'package:facetune/app/app.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/presentation/pages/analysis_result_page.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/presentation/pages/email_login_page.dart';
import 'package:facetune/features/authentication/presentation/pages/registration_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/features/authentication/presentation/widgets/brand_mark.dart';
import 'package:facetune/features/makeup_styles/presentation/pages/style_selection_page.dart';
import 'package:facetune/features/makeup_styles/presentation/widgets/makeup_style_card.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';

void _expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'an entry-flow screen overflowed its constraints',
  );
}

/// Drives the real app, overriding only the repository boundary — so every
/// assertion below goes through the same controllers and guards production uses.
Future<FakeAuthRepository> _pumpApp(WidgetTester tester) async {
  final repository = FakeAuthRepository();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
      child: const FaceTuneApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  group('entry screen', () {
    testWidgets('keeps its copy and its two committing actions', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.text('Meet the look\nmade for you.'), findsOneWidget);
      expect(find.text('Sign in with email'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Explore as a guest'), findsOneWidget);
    });

    testWidgets('no longer shows a stock photograph of a face', (tester) async {
      // A stock portrait on the entry screen of a face-analysis app reads as an
      // example result rather than as branding — and it was the project's only
      // asset, at ~2 MB.
      await _pumpApp(tester);
      expect(find.byType(BeautyImage), findsNothing);
      expect(find.byType(BrandMark), findsOneWidget);
    });

    testWidgets('does not imitate the Google mark', (tester) async {
      // `Icons.g_mobiledata_rounded` is Material's generic letter G. Google's
      // terms require the official asset when a mark is shown at all, so a
      // lookalike is both off-brand and a store-review risk.
      await _pumpApp(tester);
      expect(find.byIcon(Icons.g_mobiledata_rounded), findsNothing);
    });

    testWidgets('lays out on a narrow screen at large text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpApp(tester);
      _expectNoOverflow(tester);
    });
  });

  group('auth forms still drive the auth logic', () {
    /// Pumps one auth page on its own.
    ///
    /// Deliberately not the whole app: a successful sign-in flips the router's
    /// auth guard and it navigates to Home, which reaches for a real Supabase
    /// instance. That redirect is correct behaviour and is covered by
    /// `auth_guard_test`; here it would only obscure what is being asserted.
    Future<FakeAuthRepository> pumpPage(
      WidgetTester tester,
      Widget page,
    ) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: page),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('registration passes the typed values through', (tester) async {
      final repository = await pumpPage(tester, const RegistrationPage());

      await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'ada@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'Password1');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password1');

      // Tap the button, not its label: the label's centre can sit outside the
      // viewport when the form is scrolled to its last field, and the tap then
      // silently lands on nothing.
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();

      // The fake records the registration by adopting the user, so this proves
      // the controller ran with exactly what was typed — through the same
      // validators, the same form key, and the same notifier as production.
      expect(repository.user?.email, 'ada@example.com');
      expect(repository.user?.displayName, 'Ada Lovelace');
    });

    testWidgets('an invalid email is refused before any request', (
      tester,
    ) async {
      final repository = await pumpPage(tester, const EmailLoginPage());

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'whatever');
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();

      // Validation is domain logic and is untouched; this asserts the screen
      // still honours it rather than submitting anyway.
      expect(repository.user, isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('the submit button blocks a second tap while in flight', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AuthSubmitButton(
              label: 'Create account',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      // The label stays: "Create account" with a spinner says which action is
      // running, where the old "Please wait…" said only that something was.
      expect(find.text('Create account'), findsOneWidget);
      expect(find.byType(ButtonProgress), findsOneWidget);

      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('analysis screen', () {
    testWidgets('without an analysis it reports a failure, not an absence', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AnalysisResultPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analysis unavailable'), findsOneWidget);
      expect(find.text('Return to scan'), findsOneWidget);
      // Reaching this screen with no analysis means something went wrong
      // upstream, so it announces itself rather than sitting quietly.
      expect(
        tester
            .getSemantics(find.byType(StatusState))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });
  });

  group('style selection', () {
    Future<void> pumpStyles(
      WidgetTester tester, {
      ThemeData? theme,
      double textScale = 1,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme ?? AppTheme.lightTheme,
            home: const StyleSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('selection identity is unchanged', (tester) async {
      await pumpStyles(tester);
      expect(find.text('Select a style to continue'), findsOneWidget);

      await tester.tap(find.text('Natural'));
      await tester.pumpAndSettle();

      // The chosen style still round-trips by name into the CTA, and the card
      // still reports itself selected to a screen reader.
      expect(find.text('Continue with Natural'), findsOneWidget);
      final selected = tester.widgetList<MakeupStyleCard>(
        find.byType(MakeupStyleCard),
      );
      expect(selected.where((card) => card.isSelected).length, 1);
    });

    testWidgets('a selected card stays readable in dark mode', (tester) async {
      // The defect this guards: the selected surface was the fixed
      // `AppColors.petal`, which stays light in dark mode while the label
      // inside it followed the theme to near-white — invisible text.
      await pumpStyles(tester, theme: AppTheme.darkTheme);
      await tester.tap(find.text('Natural'));
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('Natural'));
      expect(title.style?.color, AppSemantics.dark.info.onSurface);
      expect(
        title.style?.color,
        isNot(AppTheme.darkTheme.colorScheme.onSurface),
      );
    });

    testWidgets('the grid absorbs large text without clipping', (tester) async {
      // The cell was a flat 190pt regardless of text size.
      await pumpStyles(tester, textScale: 1.6);
      _expectNoOverflow(tester);
      expect(find.byType(MakeupStyleCard), findsWidgets);
    });

    testWidgets('renders in light and dark without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await pumpStyles(tester, theme: theme);
        _expectNoOverflow(tester);
      }
    });
  });
}
