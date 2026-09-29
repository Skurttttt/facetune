import 'dart:async';
import 'dart:math';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/authentication/domain/services/auth_validators.dart';
import 'package:facetune/features/authentication/presentation/pages/registration_page.dart';
import 'package:facetune/features/authentication/presentation/widgets/auth_submit_button.dart';
import 'package:facetune/features/authentication/presentation/widgets/password_requirements.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call that crosses the auth repository boundary — the only
/// route from these screens to the network.
class _RecordingAuthRepository implements AuthRepository {
  final calls = <String>[];
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

/// Counts provider updates, so typing can be shown to cause none.
class _UpdateCounter extends ProviderObserver {
  int updates = 0;

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) => updates++;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<({_RecordingAuthRepository repository, _UpdateCounter counter})>
_pumpPage(WidgetTester tester, {Size size = const Size(393, 873)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingAuthRepository();
  final counter = _UpdateCounter();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      observers: [counter],
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
  return (repository: repository, counter: counter);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(AuthSubmitButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AuthSubmitButton));
  await tester.pumpAndSettle();
}

Future<void> _fillAllBut(
  WidgetTester tester, {
  required String password,
  required String confirmation,
}) async {
  await tester.enterText(_field('Name'), 'Ada Lovelace');
  await tester.enterText(_field('Email'), 'ada@example.com');
  await tester.enterText(_field('Password'), password);
  await tester.enterText(_field('Confirm password'), confirmation);
  await tester.pump();
}

bool _allMet(String password) =>
    PasswordRequirement.all.every((r) => r.isMetBy(password));

void main() {
  group('PasswordRequirement mirrors AuthValidators.password', () {
    test('exactly the three proven rules, in the validator order', () {
      expect(PasswordRequirement.all.map((r) => r.label), [
        'At least 8 characters',
        'At least one letter',
        'At least one number',
      ]);
    });

    test('agrees with the validator on hand-picked edge cases', () {
      const cases = [
        'a',
        '1',
        'abcdefg1', // exactly 8
        'abcdef1', // 7
        'abcdefgh',
        '12345678',
        'ABCDEFG1',
        'éééééé12', // non-ASCII letters do not count
        'abcdefg٣', // non-ASCII digits do not count
        '        ',
        'pass word 1',
        'Password1!',
        '!!!!!!a1',
      ];
      for (final password in cases) {
        expect(
          _allMet(password),
          AuthValidators.password(password) == null,
          reason: password,
        );
      }
    });

    test('agrees with the validator on 5000 random strings', () {
      final random = Random(20260929);
      const alphabet = 'aZ9 !é٣_-.';
      for (var i = 0; i < 5000; i++) {
        final length = 1 + random.nextInt(12);
        final password = String.fromCharCodes([
          for (var j = 0; j < length; j++)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        expect(
          _allMet(password),
          AuthValidators.password(password) == null,
          reason: password,
        );
      }
    });
  });

  group('AUTHUX-P3 Sign Up password presentation', () {
    testWidgets('criteria start neutral and update live as the user types', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final (:repository, :counter) = await _pumpPage(tester);
      final updatesBefore = counter.updates;

      expect(
        find.bySemanticsLabel('At least 8 characters, not met'),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(3),
      );

      await tester.enterText(_field('Password'), 'abc');
      await tester.pump();
      expect(
        find.bySemanticsLabel('At least 8 characters, not met'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('At least one letter, met'), findsOneWidget);
      expect(
        find.bySemanticsLabel('At least one number, not met'),
        findsOneWidget,
      );
      // Still neutral, not red, while typing.
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);

      await tester.enterText(_field('Password'), 'abcdefg1');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));

      // Keystrokes reached no repository and refreshed no provider.
      expect(repository.calls, isEmpty);
      expect(counter.updates, updatesBefore);
      semantics.dispose();
    });

    testWidgets('after a submit, unmet criteria take the error treatment', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.enterText(_field('Password'), 'abc');
      await _submit(tester);

      expect(find.byIcon(Icons.error_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('a valid password is still accepted', (tester) async {
      final (:repository, counter: _) = await _pumpPage(tester);

      await _fillAllBut(
        tester,
        password: 'beauty123',
        confirmation: 'beauty123',
      );
      await _submit(tester);

      expect(repository.calls, ['registerWithEmail']);
    });

    testWidgets('an invalid password is still refused, with the same error', (
      tester,
    ) async {
      final (:repository, counter: _) = await _pumpPage(tester);

      await _fillAllBut(
        tester,
        password: 'beautyabc',
        confirmation: 'beautyabc',
      );
      await _submit(tester);

      expect(
        find.text('Include at least one letter and one number.'),
        findsNWidgets(2),
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('match feedback follows the existing confirm validator', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.enterText(_field('Password'), 'beauty123');
      await tester.pump();
      expect(find.text('Passwords match'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);

      // A prefix is still being typed: say nothing yet.
      await tester.enterText(_field('Confirm password'), 'beauty');
      await tester.pump();
      expect(find.text('Passwords do not match'), findsNothing);

      await tester.enterText(_field('Confirm password'), 'beautx');
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);

      await tester.enterText(_field('Confirm password'), 'beauty123');
      await tester.pump();
      expect(find.text('Passwords match'), findsOneWidget);

      // Identical but not acceptable: the validator would reject it, so no
      // "match" is claimed.
      await tester.enterText(_field('Password'), 'short1');
      await tester.enterText(_field('Confirm password'), 'short1');
      await tester.pump();
      expect(find.text('Passwords match'), findsNothing);
      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('a mismatch is still refused with the original message', (
      tester,
    ) async {
      final (:repository, counter: _) = await _pumpPage(tester);

      await _fillAllBut(
        tester,
        password: 'beauty123',
        confirmation: 'beauty124',
      );
      await _submit(tester);

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('the visibility toggle is labelled and reveals both fields', (
      tester,
    ) async {
      await _pumpPage(tester);

      bool obscured(String label) => tester
          .widget<TextField>(
            find.descendant(
              of: _field(label),
              matching: find.byType(TextField),
            ),
          )
          .obscureText;

      expect(obscured('Password'), isTrue);
      expect(obscured('Confirm password'), isTrue);

      await tester.tap(find.byTooltip('Show passwords'));
      await tester.pump();
      expect(obscured('Password'), isFalse);
      expect(obscured('Confirm password'), isFalse);

      await tester.tap(find.byTooltip('Hide passwords'));
      await tester.pump();
      expect(obscured('Password'), isTrue);
    });

    testWidgets('criteria wrap rather than clip at 2x text', (tester) async {
      await _pumpPage(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(PasswordRequirementsChecklist),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final requirement in PasswordRequirement.all) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(requirement.label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, greaterThan(0));
      }
    });
  });
}
