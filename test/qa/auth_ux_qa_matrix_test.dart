import 'dart:async';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/authentication/presentation/pages/authentication_page.dart';
import 'package:facetune/features/authentication/presentation/pages/registration_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/features/authentication/presentation/widgets/brand_mark.dart';
import 'package:facetune/features/authentication/presentation/widgets/password_requirements.dart';
import 'package:facetune/shared/widgets/navigation/facetune_back_button.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AUTHUX-P5: Login and Sign Up across the device, text-size and theme matrix
/// the track calls for. Validation only — it asserts the accepted P1–P4 UI.

class _HoldingAuthRepository implements AuthRepository {
  final calls = <String>[];
  Completer<void>? hold;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> bootstrapProfile(AuthUser user) async {}

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    calls.add('registerWithEmail');
    await hold?.future;
    return RegistrationResult(
      user: AuthUser(id: 'new', email: email, isAnonymous: false),
      hasActiveSession: false,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthUser> signInAnonymously() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail');
    await hold?.future;
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updatePassword(String password) async {}

  Future<void> dispose() => _events.close();
}

class _Condition {
  const _Condition(
    this.name,
    this.size, {
    this.textScale = 1,
    this.themeMode = ThemeMode.light,
    this.platformBrightness = Brightness.light,
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

const _poco = Size(393, 873);
const _conditions = <_Condition>[
  _Condition('POCO X3 GT, light', _poco),
  _Condition('POCO X3 GT, dark', _poco, themeMode: ThemeMode.dark),
  _Condition('POCO X3 GT, system light', _poco, themeMode: ThemeMode.system),
  _Condition(
    'POCO X3 GT, system dark',
    _poco,
    themeMode: ThemeMode.system,
    platformBrightness: Brightness.dark,
  ),
  _Condition('narrow Android 320, light', Size(320, 640)),
  _Condition(
    'short Android 393×560, dark',
    Size(393, 560),
    themeMode: ThemeMode.dark,
  ),
  _Condition('POCO X3 GT, 2x text', _poco, textScale: 2),
  _Condition(
    'narrow Android 320, 2x text, dark',
    Size(320, 640),
    textScale: 2,
    themeMode: ThemeMode.dark,
  ),
];

enum _Screen { login, signUp }

final _navigatorKey = GlobalKey<NavigatorState>();

Future<_HoldingAuthRepository> _pump(
  WidgetTester tester,
  _Screen screen,
  _Condition condition,
) async {
  tester.view.physicalSize = condition.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = condition.textScale;
  tester.platformDispatcher.platformBrightnessTestValue =
      condition.platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final repository = _HoldingAuthRepository();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: condition.themeMode,
        home: const AuthenticationPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (screen == _Screen.signUp) {
    // Pushed over Login, as in the app, so the top bar has its Back.
    unawaited(
      _navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const RegistrationPage()),
      ),
    );
    await tester.pumpAndSettle();
  }
  return repository;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

/// Scrolls [finder] into view and proves it is on screen and tappable.
Future<void> _expectReachable(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  final rect = tester.getRect(finder);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final bottomInset =
      tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder above screen');
  expect(
    rect.bottom,
    lessThanOrEqualTo(screen.height - bottomInset + 0.5),
    reason: '$finder is hidden below the screen or keyboard',
  );
  expect(finder.hitTestable(), findsWidgets, reason: '$finder not tappable');
}

/// Field labels, which Material always draws on one line with an ellipsis.
///
/// Excluded from the clipping check because the test font cannot judge them:
/// it draws every glyph as a full em square, so "Password" at 2x measures
/// 256px here and about 130px in Roboto on the device. Real-device QA covers
/// them.
const _fieldLabels = {'Name', 'Email', 'Password', 'Confirm password'};

/// Every [RenderParagraph] on screen fits its box: no clipped or ellipsised
/// text, no overflow. Field errors are included: they may wrap to
/// `authFieldErrorMaxLines` lines, and must not need more.
void _expectNoClipping(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  for (final paragraph
      in tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .where((p) => !_fieldLabels.contains(p.text.toPlainText()))) {
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"${paragraph.text.toPlainText()}" is clipped',
    );
  }
}

final _loginTargets = <String, Finder>{
  'Email': _field('Email'),
  'Password': _field('Password'),
  'Forgot password': find.text('Forgot password?'),
  'Sign in': find.byType(AuthSubmitButton),
  'Google': find.text('Continue with Google'),
  'Create account': find.text('New here? Create an account'),
};

final _signUpTargets = <String, Finder>{
  'Back': find.byType(FaceTuneBackButton),
  'Name': _field('Name'),
  'Email': _field('Email'),
  'Password': _field('Password'),
  'Requirements': find.byType(PasswordRequirementsChecklist),
  'Confirm password': _field('Confirm password'),
  'Create account': find.byType(AuthSubmitButton),
  'Sign In link': find.text('Already have an account? Sign in'),
  'Privacy notice': find.textContaining('By continuing'),
};

void main() {
  group('AUTHUX-P5 viewport and theme matrix', () {
    for (final condition in _conditions) {
      group(condition.name, () {
        testWidgets('Login: every action reachable, nothing clipped', (
          tester,
        ) async {
          await _pump(tester, _Screen.login, condition);

          expect(
            Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
            condition.expectedBrightness,
          );
          expect(find.textContaining('guest'), findsNothing);
          expect(find.textContaining('Guest'), findsNothing);
          _expectNoClipping(tester);
          for (final entry in _loginTargets.entries) {
            await _expectReachable(tester, entry.value);
          }
          _expectNoClipping(tester);
        });

        testWidgets('Sign Up: every part reachable, nothing clipped', (
          tester,
        ) async {
          await _pump(tester, _Screen.signUp, condition);

          expect(
            Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
            condition.expectedBrightness,
          );
          _expectNoClipping(tester);
          for (final entry in _signUpTargets.entries) {
            await _expectReachable(tester, entry.value);
          }
          _expectNoClipping(tester);
        });

        testWidgets('Sign Up with long input and every error showing', (
          tester,
        ) async {
          await _pump(tester, _Screen.signUp, condition);

          // Longest accepted name, a long address, and all validation text
          // (field errors plus red criteria) at once.
          // Scrolled to first: at 2x on a narrow screen the form starts below
          // the part of the lazy list that has been built.
          Future<void> type(String label, String text) async {
            await tester.scrollUntilVisible(
              _field(label),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.enterText(_field(label), text);
          }

          await type('Name', 'Maximiliana ' * 6 + 'Lovelace');
          await type(
            'Email',
            'maximiliana.alexandra.lovelace-byron.1815@analytical-engine.example.com',
          );
          await type('Password', 'abc');
          await type('Confirm password', 'abd');
          await tester.scrollUntilVisible(
            find.byType(AuthSubmitButton),
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(AuthSubmitButton));
          await tester.pumpAndSettle();

          expect(
            find.text('Name must be 80 characters or fewer.'),
            findsNothing,
          );
          expect(find.text('Use at least 8 characters.'), findsWidgets);
          _expectNoClipping(tester);
          for (final entry in _signUpTargets.entries) {
            await _expectReachable(tester, entry.value);
          }
          _expectNoClipping(tester);
        });
      });
    }
  });

  group('AUTHUX-P5 keyboard open', () {
    for (final condition in [_conditions[0], _conditions[5]]) {
      testWidgets('${condition.name}: Login final actions stay reachable', (
        tester,
      ) async {
        await _pump(tester, _Screen.login, condition);
        await tester.showKeyboard(_field('Password'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        for (final finder in [
          find.byType(AuthSubmitButton),
          find.text('Continue with Google'),
          find.text('New here? Create an account'),
        ]) {
          await _expectReachable(tester, finder);
        }
        _expectNoClipping(tester);
      });

      testWidgets('${condition.name}: Sign Up final actions stay reachable', (
        tester,
      ) async {
        await _pump(tester, _Screen.signUp, condition);
        await tester.showKeyboard(_field('Confirm password'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        for (final finder in [
          find.byType(AuthSubmitButton),
          find.text('Already have an account? Sign in'),
          find.textContaining('By continuing'),
        ]) {
          await _expectReachable(tester, finder);
        }
        _expectNoClipping(tester);
      });
    }
  });

  group('AUTHUX-P5 visual hierarchy', () {
    testWidgets('Login branding is compact and subordinate to the task', (
      tester,
    ) async {
      await _pump(tester, _Screen.login, _conditions[0]);

      final brand = tester.getRect(find.byType(BrandMark));
      final title = tester.getRect(find.text('Welcome back'));
      final email = tester.getRect(_field('Email'));
      // The mark takes well under a sixth of the POCO screen, and the form
      // starts in the upper half — the task, not the brand, fills the screen.
      expect(brand.height, lessThan(_poco.height / 6));
      expect(email.top, lessThan(_poco.height / 2));
      expect(title.top, greaterThan(brand.bottom));

      final titleStyle = tester.widget<Text>(find.text('Welcome back')).style!;
      final bodyStyle = tester
          .widget<Text>(find.text('Sign in to continue your beauty journey.'))
          .style!;
      expect(titleStyle.fontSize, greaterThan(bodyStyle.fontSize!));
    });

    testWidgets('Login and Sign Up share one field, button, and title style', (
      tester,
    ) async {
      await _pump(tester, _Screen.signUp, _conditions[0]);
      final signUpTitle = tester
          .widget<Text>(find.text('Create your account'))
          .style;
      final signUpField = tester.getSize(_field('Email'));
      final signUpButton = tester.getSize(find.byType(AuthSubmitButton));

      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      final loginTitle = tester.widget<Text>(find.text('Welcome back')).style;

      expect(loginTitle?.fontSize, signUpTitle?.fontSize);
      expect(loginTitle?.fontWeight, signUpTitle?.fontWeight);
      expect(tester.getSize(_field('Email')).height, signUpField.height);
      expect(
        tester.getSize(find.byType(AuthSubmitButton)).height,
        signUpButton.height,
      );
    });
  });

  group('AUTHUX-P5 accessibility', () {
    for (final condition in [_conditions[0], _conditions[1], _conditions[6]]) {
      for (final screen in _Screen.values) {
        testWidgets('${screen.name}, ${condition.name}: '
            'labelled 44dp targets and readable contrast', (tester) async {
          await _pump(tester, screen, condition);

          // The track's floor is 44dp. Login also meets Android's 48dp; Sign
          // Up's only smaller target is the app-wide FaceTuneBackButton
          // (44×44), which is shared, accepted UI outside this track.
          await expectLater(
            tester,
            meetsGuideline(
              const MinimumTapTargetGuideline(
                size: Size(44, 44),
                link: 'FACETUNE_AUTH_UX_SOURCE_OF_TRUTH.md §34',
              ),
            ),
          );
          if (screen == _Screen.login) {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }
    }

    testWidgets('the visibility toggles name their action', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Screen.login, _conditions[0]);

      // The toggle's name is its tooltip, which TalkBack reads with the
      // button role.
      Matcher named(String name) =>
          containsSemantics(tooltip: name, isButton: true);
      expect(
        tester.getSemantics(find.byTooltip('Show password')),
        named('Show password'),
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byTooltip('Hide password')),
        named('Hide password'),
      );

      unawaited(
        _navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const RegistrationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byTooltip('Show passwords')),
        named('Show passwords'),
      );
      semantics.dispose();
    });

    testWidgets('focus order follows the reading order', (tester) async {
      await _pump(tester, _Screen.signUp, _conditions[0]);

      // Hardware-keyboard traversal: the fields come in the order they read.
      final order = <String>[];
      final labels = ['Name', 'Email', 'Password', 'Confirm password'];
      FocusNode node(String label) => tester
          .widget<EditableText>(
            find.descendant(
              of: _field(label),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode;
      node('Name').requestFocus();
      await tester.pump();
      for (var i = 0; i < 12 && order.length < labels.length; i++) {
        for (final label in labels) {
          if (node(label).hasFocus && !order.contains(label)) {
            order.add(label);
          }
        }
        FocusManager.instance.primaryFocus!.nextFocus();
        await tester.pump();
      }
      expect(order, labels);
    });

    testWidgets('field errors are exposed to assistive technology', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Screen.login, _conditions[0]);

      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Enter your email address')),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(RegExp('Enter your password')),
        findsWidgets,
      );
      semantics.dispose();
    });

    testWidgets('a busy button says what it is doing and reads as disabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = await _pump(tester, _Screen.login, _conditions[0]);
      repository.hold = Completer<void>();

      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'Password1');
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pump();

      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(AuthSubmitButton),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        ),
        containsSemantics(
          label: 'Signing in…',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      repository.hold!.complete();
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  });
}
