import 'dart:async';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/mappers/auth_error_mapper.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_state.dart';
import 'package:facetune/features/authentication/presentation/pages/authentication_page.dart';
import 'package:facetune/features/authentication/presentation/pages/registration_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Records every call that crosses the auth repository boundary. Requests can
/// be held open with [hold] or made to fail with [failWith].
class _RecordingAuthRepository implements AuthRepository {
  final calls = <String>[];
  Completer<void>? hold;
  Object? failWith;
  final _events = StreamController<AuthEvent>.broadcast();

  Future<void> _respond(String call) async {
    calls.add(call);
    await hold?.future;
    final failure = failWith;
    if (failure != null) {
      // What the production repository does with a Supabase error.
      throw AuthErrorMapper.map(failure);
    }
  }

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
    await _respond('registerWithEmail');
    return RegistrationResult(
      user: AuthUser(id: 'new', email: email, isAnonymous: false),
      hasActiveSession: false,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) => _respond('sendPasswordReset');

  @override
  Future<AuthUser> signInAnonymously() async {
    await _respond('signInAnonymously');
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _respond('signInWithEmail');
    // Stay signed out; the assertions are about the request and the screen.
    throw AuthErrorMapper.map(Exception('held'));
  }

  @override
  Future<void> signInWithGoogle() => _respond('signInWithGoogle');

  @override
  Future<void> signOut() => _respond('signOut');

  @override
  Future<void> updatePassword(String password) => _respond('updatePassword');

  Future<void> dispose() => _events.close();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

EditableText _editable(WidgetTester tester, String label) =>
    tester.widget<EditableText>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    );

bool _hasFocus(WidgetTester tester, String label) =>
    _editable(tester, label).focusNode.hasFocus;

Future<_RecordingAuthRepository> _pump(WidgetTester tester, Widget page) async {
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
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: page),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

AuthState _authState(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AuthSubmitButton)),
).read(authControllerProvider);

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(AuthSubmitButton));
  await tester.pump();
  await tester.tap(find.byType(AuthSubmitButton));
  await tester.pump();
}

Future<void> _fillSignUp(WidgetTester tester) async {
  await tester.enterText(_field('Name'), 'Ada Lovelace');
  await tester.enterText(_field('Email'), 'ada@example.com');
  await tester.enterText(_field('Password'), 'beauty123');
  await tester.enterText(_field('Confirm password'), 'beauty123');
}

void main() {
  group('AUTHUX-P4 loading and double submit', () {
    testWidgets('Login says "Signing in…" from the controller state and '
        'sends one request however often it is asked', (tester) async {
      final repository = await _pump(tester, const AuthenticationPage());
      repository.hold = Completer<void>();

      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'Password1');
      await _tapSubmit(tester);

      // The label is read from the existing owner — the controller's
      // activeOperation — not from any state of the page's own.
      expect(_authState(tester).activeOperation, AuthOperation.signIn);
      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);

      // A second tap and the keyboard's Done, while the first is in flight.
      await tester.tap(find.byType(AuthSubmitButton), warnIfMissed: false);
      await tester.showKeyboard(_field('Password'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repository.calls, ['signInWithEmail']);

      // Google is unavailable while the sign-in runs.
      final google = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Continue with Google'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(google.onPressed, isNull);

      repository.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Sign Up says "Creating account…" and sends one request', (
      tester,
    ) async {
      final repository = await _pump(tester, const RegistrationPage());
      repository.hold = Completer<void>();

      await _fillSignUp(tester);
      await _tapSubmit(tester);

      expect(_authState(tester).activeOperation, AuthOperation.register);
      expect(find.text('Creating account…'), findsOneWidget);

      await tester.tap(find.byType(AuthSubmitButton), warnIfMissed: false);
      await tester.showKeyboard(_field('Confirm password'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repository.calls, ['registerWithEmail']);

      repository.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
    });
  });

  group('AUTHUX-P4 errors', () {
    testWidgets('a rejected sign-in shows the existing mapped message', (
      tester,
    ) async {
      final repository = await _pump(tester, const AuthenticationPage());
      repository.failWith = const AuthException('Invalid login credentials');

      await tester.enterText(_field('Email'), 'ada@example.com');
      await tester.enterText(_field('Password'), 'wrong-password');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('a duplicate account shows the existing mapped message', (
      tester,
    ) async {
      final repository = await _pump(tester, const RegistrationPage());
      repository.failWith = const AuthException('User already registered');

      await _fillSignUp(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('An account already exists for this email.'),
        findsOneWidget,
      );
    });

    testWidgets('after a failed submit, errors clear as the user fixes them', (
      tester,
    ) async {
      final repository = await _pump(tester, const RegistrationPage());

      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);

      await tester.enterText(_field('Name'), 'Ada');
      await tester.pump();
      expect(find.text('Enter your name.'), findsNothing);
      expect(repository.calls, isEmpty);
    });

    testWidgets('a mismatch is reported once, by the field, after submit', (
      tester,
    ) async {
      await _pump(tester, const RegistrationPage());

      await tester.enterText(_field('Password'), 'beauty123');
      await tester.enterText(_field('Confirm password'), 'beautx123');
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);

      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsNothing);

      await tester.enterText(_field('Confirm password'), 'beauty123');
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsNothing);
      expect(find.text('Passwords match'), findsOneWidget);
    });
  });

  group('AUTHUX-P4 keyboard', () {
    testWidgets('Login: Next goes from email to password; nothing is sent', (
      tester,
    ) async {
      final repository = await _pump(tester, const AuthenticationPage());

      await tester.showKeyboard(_field('Email'));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(_hasFocus(tester, 'Password'), isTrue);
      expect(repository.calls, isEmpty);
    });

    testWidgets('Sign Up: Next walks the fields in order, skipping the '
        'show/hide button, and Done submits only this form', (tester) async {
      final repository = await _pump(tester, const RegistrationPage());

      await tester.showKeyboard(_field('Name'));
      for (final next in ['Email', 'Password', 'Confirm password']) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(_hasFocus(tester, next), isTrue, reason: next);
      }
      expect(repository.calls, isEmpty);

      // Done on an empty form validates this form and sends nothing.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('password fields never autocorrect, shown or hidden', (
      tester,
    ) async {
      await _pump(tester, const RegistrationPage());

      void expectNoCorrection() {
        for (final label in ['Password', 'Confirm password']) {
          final field = _editable(tester, label);
          expect(field.autocorrect, isFalse, reason: label);
          expect(field.enableSuggestions, isFalse, reason: label);
        }
      }

      expectNoCorrection();
      await tester.tap(find.byTooltip('Show passwords'));
      await tester.pump();
      expect(_editable(tester, 'Password').obscureText, isFalse);
      expectNoCorrection();
    });

    testWidgets('Login password never autocorrects either', (tester) async {
      await _pump(tester, const AuthenticationPage());

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      final field = _editable(tester, 'Password');
      expect(field.obscureText, isFalse);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
    });

    testWidgets('Name capitalises words; email does not', (tester) async {
      await _pump(tester, const RegistrationPage());

      expect(
        _editable(tester, 'Name').textCapitalization,
        TextCapitalization.words,
      );
      expect(
        _editable(tester, 'Email').textCapitalization,
        TextCapitalization.none,
      );
      expect(
        _editable(tester, 'Email').keyboardType.index,
        TextInputType.emailAddress.index,
      );
    });
  });

  group('AUTHUX-P4 autofill', () {
    testWidgets('Login fields are grouped with sign-in hints', (tester) async {
      final repository = await _pump(tester, const AuthenticationPage());

      expect(
        find.ancestor(
          of: find.byType(Form),
          matching: find.byType(AutofillGroup),
        ),
        findsOneWidget,
      );
      expect(_editable(tester, 'Email').autofillHints, [AutofillHints.email]);
      expect(_editable(tester, 'Password').autofillHints, [
        AutofillHints.password,
      ]);

      // Filled values go through the same validators as typed ones.
      await tester.enterText(_field('Email'), 'not-an-email');
      await tester.enterText(_field('Password'), 'x');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('Sign Up fields are grouped with new-account hints', (
      tester,
    ) async {
      final repository = await _pump(tester, const RegistrationPage());

      expect(
        find.ancestor(
          of: find.byType(Form),
          matching: find.byType(AutofillGroup),
        ),
        findsOneWidget,
      );
      expect(_editable(tester, 'Name').autofillHints, [AutofillHints.name]);
      expect(_editable(tester, 'Email').autofillHints, [AutofillHints.email]);
      expect(_editable(tester, 'Password').autofillHints, [
        AutofillHints.newPassword,
      ]);
      expect(_editable(tester, 'Confirm password').autofillHints, [
        AutofillHints.newPassword,
      ]);

      await _fillSignUp(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repository.calls, ['registerWithEmail']);
    });
  });
}
