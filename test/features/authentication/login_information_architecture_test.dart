import 'dart:async';

import 'package:facetune/app/app.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_state.dart';
import 'package:facetune/features/authentication/presentation/pages/authentication_page.dart';
import 'package:facetune/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:facetune/features/authentication/presentation/pages/registration_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/features/authentication/presentation/widgets/brand_mark.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';

/// Records every call that crosses the auth repository boundary.
///
/// That boundary is the only way the Login screen can reach the network, so an
/// empty or exact [calls] list is the proof that the screen made no request it
/// did not make before.
class _RecordingAuthRepository implements AuthRepository {
  final calls = <String>[];
  final emails = <String>[];
  final passwords = <String>[];
  AuthUser? user;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  @override
  AuthUser? get currentUser => user;

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
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('sendPasswordReset');

  @override
  Future<AuthUser> signInAnonymously() async {
    calls.add('signInAnonymously');
    return user = const AuthUser(id: 'guest', isAnonymous: true);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail');
    emails.add(email);
    passwords.add(password);
    // Stay signed out so the router keeps this screen on top; the assertion
    // is about what was sent, not about Home.
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

/// The whole app with only the repository boundary replaced, so navigation
/// goes through the production router.
Future<_RecordingAuthRepository> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 873);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingAuthRepository();
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

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('AUTHUX-P1 Login information architecture', () {
    testWidgets('has no guest entry and no guest explanation', (tester) async {
      final repository = await _pumpApp(tester);

      expect(find.byType(AuthenticationPage), findsOneWidget);
      expect(find.text('Explore as a guest'), findsNothing);
      expect(find.text('Creating guest session…'), findsNothing);
      expect(find.textContaining('Guest sessions'), findsNothing);
      expect(find.textContaining('guest', findRichText: true), findsNothing);
      expect(repository.calls, isEmpty);
    });

    testWidgets('reads top to bottom as the sign-in task', (tester) async {
      await _pumpApp(tester);

      // The oversized landing hero and its marketing headline are gone; the
      // existing mark stays, on the theme's own ground.
      expect(find.text('Meet the look\nmade for you.'), findsNothing);
      expect(find.text('Sign in with email'), findsNothing);
      expect(find.byType(BrandMark), findsOneWidget);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final order = [
        find.byType(BrandMark),
        find.text('Welcome back'),
        find.widgetWithText(TextFormField, 'Email'),
        find.widgetWithText(TextFormField, 'Password'),
        find.text('Forgot password?'),
        find.byType(AuthSubmitButton),
        find.text('or'),
        find.text('Continue with Google'),
        find.text('New here? Create an account'),
      ];
      for (final finder in order) {
        expect(finder, findsOneWidget);
      }
      for (var i = 1; i < order.length; i++) {
        expect(
          top(order[i]),
          greaterThan(top(order[i - 1])),
          reason: '${order[i]} should sit below ${order[i - 1]}',
        );
      }
    });

    testWidgets('sign in sends exactly what was typed, once', (tester) async {
      final repository = await _pumpApp(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'ada@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password1',
      );
      await _tap(tester, find.byType(AuthSubmitButton));

      expect(repository.calls, ['signInWithEmail']);
      expect(repository.emails, ['ada@example.com']);
      expect(repository.passwords, ['Password1']);
    });

    testWidgets('invalid input is refused before any request', (tester) async {
      final repository = await _pumpApp(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'not-an-email',
      );
      await _tap(tester, find.byType(AuthSubmitButton));

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('Google calls the same controller action, once', (
      tester,
    ) async {
      final repository = await _pumpApp(tester);

      await _tap(tester, find.text('Continue with Google'));

      expect(repository.calls, ['signInWithGoogle']);
    });

    testWidgets('Forgot password opens the existing reset screen', (
      tester,
    ) async {
      final repository = await _pumpApp(tester);

      await _tap(tester, find.text('Forgot password?'));

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('Create an account opens the existing registration screen', (
      tester,
    ) async {
      final repository = await _pumpApp(tester);

      await _tap(tester, find.text('New here? Create an account'));

      expect(find.byType(RegistrationPage), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('without a backend every action is disabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [supabaseAvailableProvider.overrideWithValue(false)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AuthenticationPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppNotice), findsOneWidget);
      FilledButton submit() => tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(AuthSubmitButton),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(submit().onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Forgot password?'),
            )
            .onPressed,
        isNull,
      );
    });

    test('the guest implementation is still there and still works', () async {
      // Removing the Login entry must not remove the capability: the
      // controller action and anonymous sign-in are unchanged.
      final repository = _RecordingAuthRepository();
      final container = ProviderContainer(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);

      await container.read(authControllerProvider.notifier).continueAsGuest();

      expect(repository.calls, ['signInAnonymously']);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.isAnonymous, isTrue);
      expect(AuthOperation.values, contains(AuthOperation.guest));
    });
  });
}
