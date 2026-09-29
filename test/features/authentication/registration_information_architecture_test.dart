import 'dart:async';

import 'package:facetune/app/app.dart';
import 'package:facetune/core/constants/app_constants.dart';
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
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_account_repositories.dart';

const _privacyNotice =
    'By continuing, you agree to protect the privacy of any images you upload.';
const _signInLink = 'Already have an account? Sign in';

/// Records every call that crosses the auth repository boundary.
class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.pendingRegistration});

  /// When set, registration waits on it, so a test can look at the screen
  /// while the request is in flight.
  final Completer<void>? pendingRegistration;
  final calls = <String>[];
  final registrations =
      <({String displayName, String email, String password})>[];
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> bootstrapProfile(AuthUser user) async =>
      calls.add('bootstrapProfile');

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    calls.add('registerWithEmail');
    registrations.add((
      displayName: displayName,
      email: email,
      password: password,
    ));
    await pendingRegistration?.future;
    // No session: the email-confirmation path, which keeps this screen up.
    return RegistrationResult(
      user: AuthUser(id: 'new', email: email, isAnonymous: false),
      hasActiveSession: false,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('sendPasswordReset');

  @override
  Future<AuthUser> signInAnonymously() async {
    calls.add('signInAnonymously');
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail');
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('signInWithGoogle');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> updatePassword(String password) async =>
      calls.add('updatePassword');

  Future<void> dispose() => _events.close();
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 873);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_RecordingAuthRepository> _pumpPage(
  WidgetTester tester, {
  Completer<void>? pendingRegistration,
}) async {
  _usePhone(tester);
  final repository = _RecordingAuthRepository(
    pendingRegistration: pendingRegistration,
  );
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RegistrationPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_field('Name'), 'Ada Lovelace');
  await tester.enterText(_field('Email'), 'ada@example.com');
  await tester.enterText(_field('Password'), 'Password1');
  await tester.enterText(_field('Confirm password'), 'Password1');
}

void main() {
  group('AUTHUX-P2 Sign Up information architecture', () {
    testWidgets('reads top to bottom in the target order', (tester) async {
      await _pumpPage(tester);

      final order = [
        find.byType(BrandMark),
        find.text('Create your account'),
        find.text('Save your looks securely and return anytime.'),
        _field('Name'),
        _field('Email'),
        _field('Password'),
        find.byType(PasswordRequirementsChecklist),
        _field('Confirm password'),
        find.byType(AuthSubmitButton),
        find.text(_signInLink),
        find.text(_privacyNotice),
      ];
      for (final finder in order) {
        expect(finder, findsOneWidget);
      }
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      for (var i = 1; i < order.length; i++) {
        expect(
          top(order[i]),
          greaterThan(top(order[i - 1])),
          reason: '${order[i]} should sit below ${order[i - 1]}',
        );
      }
      // Still exactly the four original fields.
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('Create account sends exactly what was typed, once', (
      tester,
    ) async {
      final repository = await _pumpPage(tester);

      await _fill(tester);
      await _tap(tester, find.byType(AuthSubmitButton));

      expect(repository.calls, ['registerWithEmail']);
      expect(repository.registrations.single.displayName, 'Ada Lovelace');
      expect(repository.registrations.single.email, 'ada@example.com');
      expect(repository.registrations.single.password, 'Password1');
      // The email-confirmation notice still comes from the controller.
      expect(
        find.text('Check your email to confirm your account, then sign in.'),
        findsOneWidget,
      );
    });

    testWidgets('the existing validators still gate the request', (
      tester,
    ) async {
      final repository = await _pumpPage(tester);

      await _tap(tester, find.byType(AuthSubmitButton));
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      // Password and its confirmation share the same empty-value message.
      expect(find.text('Enter your password.'), findsNWidgets(2));

      await tester.enterText(_field('Name'), 'x' * 81);
      await tester.enterText(_field('Email'), 'not-an-email');
      await tester.enterText(_field('Password'), 'letters-only');
      await tester.enterText(_field('Confirm password'), 'Password2');
      await _tap(tester, find.byType(AuthSubmitButton));
      expect(find.text('Name must be 80 characters or fewer.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(
        find.text('Include at least one letter and one number.'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match.'), findsOneWidget);

      expect(repository.calls, isEmpty);
    });

    testWidgets('lays out on a narrow screen at large text', (tester) async {
      await _pumpPage(tester);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      // The frame is a lazily built list, so the notice has to be scrolled to
      // before it exists.
      await tester.scrollUntilVisible(
        find.text(_privacyNotice),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(_signInLink), findsOneWidget);
    });

    testWidgets('Name keeps its display-name semantics', (tester) async {
      await _pumpPage(tester);

      final name = tester.widget<TextField>(
        find.descendant(of: _field('Name'), matching: find.byType(TextField)),
      );
      expect(name.decoration?.labelText, 'Name');
      expect(name.autofillHints, [AutofillHints.name]);
      expect(find.textContaining('Full name'), findsNothing);
      expect(find.textContaining('Legal'), findsNothing);
    });

    testWidgets('the Sign in link is disabled while an account is created', (
      tester,
    ) async {
      final pending = Completer<void>();
      await _pumpPage(tester, pendingRegistration: pending);

      await _fill(tester);
      await tester.ensureVisible(find.byType(AuthSubmitButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AuthSubmitButton));
      await tester.pump();

      final link = tester.widget<TertiaryButton>(
        find.widgetWithText(TertiaryButton, _signInLink),
      );
      expect(link.onPressed, isNull);

      pending.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Sign in returns to the sign-in screen it came from', (
      tester,
    ) async {
      _usePhone(tester);
      final repository = _RecordingAuthRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(repository),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
          ],
          child: const FaceTuneApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text('New here? Create an account'));
      expect(find.byType(RegistrationPage), findsOneWidget);

      await _tap(tester, find.text(_signInLink));

      // A pop, the same as the top bar's Back: registration is gone, and no
      // second sign-in screen was stacked on the first.
      expect(find.byType(RegistrationPage), findsNothing);
      expect(find.byType(AuthenticationPage), findsOneWidget);
      expect(
        GoRouter.of(tester.element(find.byType(AuthenticationPage))).canPop(),
        isFalse,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('with nothing beneath it, Sign in goes to the auth route', (
      tester,
    ) async {
      _usePhone(tester);
      final repository = _RecordingAuthRepository();
      addTearDown(repository.dispose);
      final router = GoRouter(
        initialLocation: AppConstants.registerRoute,
        routes: [
          GoRoute(
            path: AppConstants.authRoute,
            builder: (context, state) => const Text('auth route'),
          ),
          GoRoute(
            path: AppConstants.registerRoute,
            builder: (context, state) => const RegistrationPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text(_signInLink));

      expect(find.text('auth route'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });
  });
}
