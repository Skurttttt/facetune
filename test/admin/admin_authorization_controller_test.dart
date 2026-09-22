import 'dart:async';

import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/domain/admin_identity.dart';
import 'package:facetune/admin/auth/domain/admin_role.dart';
import 'package:facetune/admin/auth/domain/admin_session_gateway.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/errors/auth_failure.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// A gateway whose answer is scripted per call. Records how often it was
/// asked, so a test can prove the server was (or was not) consulted.
class ScriptedGateway implements AdminSessionGateway {
  ScriptedGateway(this._answers);

  final List<Future<AdminIdentity> Function()> _answers;
  int calls = 0;
  Completer<AdminIdentity>? pending;

  @override
  Future<AdminIdentity> verifyAdminSession() {
    calls++;
    if (_answers.isEmpty) {
      pending = Completer<AdminIdentity>();
      return pending!.future;
    }
    return _answers.removeAt(0)();
  }
}

const admin = AuthUser(
  id: 'admin-1',
  email: 'ops@example.invalid',
  isAnonymous: false,
);
const normal = AuthUser(
  id: 'user-1',
  email: 'user@example.invalid',
  isAnonymous: false,
);
const identity = AdminIdentity(userId: 'admin-1', email: 'ops@example.invalid');

Future<AdminIdentity> yes() async => identity;
Future<AdminIdentity> Function() refuse(
  SubscriptionErrorCode code, {
  bool retryable = false,
}) =>
    () async => throw AdminAuthFailure(code, retryable: retryable);

/// An [AuthRepository] whose sign-out records itself, whose sign-in can be
/// scripted to fail, and whose auth events a test can emit.
class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({this.user});

  AuthUser? user;
  int signOuts = 0;
  AuthFailure? signInFailure;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  void emit(AuthEventType type, {AuthUser? user}) =>
      _events.add(AuthEvent(type: type, user: user));

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final failure = signInFailure;
    if (failure != null) throw failure;
    user = admin;
    return admin;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
    _events.add(const AuthEvent(type: AuthEventType.signedOut));
  }

  @override
  Future<void> bootstrapProfile(AuthUser user) async {}

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) => throw UnimplementedError('not an admin flow');

  @override
  Future<void> sendPasswordReset(String email) =>
      throw UnimplementedError('not an admin flow');

  @override
  Future<AuthUser> signInAnonymously() =>
      throw UnimplementedError('not an admin flow');

  @override
  Future<void> signInWithGoogle() =>
      throw UnimplementedError('not an admin flow');

  @override
  Future<void> updatePassword(String password) =>
      throw UnimplementedError('not an admin flow');
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('AdminAuthorizationController', () {
    test(
      'a valid admin with a persisted session is authorized by the server',
      () async {
        final gateway = ScriptedGateway([yes]);
        final controller = AdminAuthorizationController(
          authRepository: RecordingAuthRepository(user: admin),
          gateway: gateway,
          isSupabaseAvailable: true,
        );
        expect(controller.state, isA<AdminAuthorizationPending>());
        await settle();
        final state = controller.state;
        expect(state, isA<AdminAuthorized>());
        expect((state as AdminAuthorized).identity.role, AdminRole.admin);
        expect(state.identity.email, 'ops@example.invalid');
        expect(gateway.calls, 1);
        controller.dispose();
      },
    );

    test(
      'a normal user is refused by the server and never becomes authorized',
      () async {
        final controller = AdminAuthorizationController(
          authRepository: RecordingAuthRepository(user: normal),
          gateway: ScriptedGateway([
            refuse(SubscriptionErrorCode.adminUnauthorized),
          ]),
          isSupabaseAvailable: true,
        );
        await settle();
        expect(controller.state, isA<AdminUnauthorized>());
        expect(controller.state.isAuthorized, isFalse);
        controller.dispose();
      },
    );

    test(
      'with no session the server is not asked and the state is unauthenticated',
      () async {
        final gateway = ScriptedGateway([yes]);
        final controller = AdminAuthorizationController(
          authRepository: RecordingAuthRepository(),
          gateway: gateway,
          isSupabaseAvailable: true,
        );
        await settle();
        expect(controller.state, isA<AdminUnauthenticated>());
        expect(
          (controller.state as AdminUnauthenticated).sessionExpired,
          isFalse,
        );
        expect(gateway.calls, 0);
        controller.dispose();
      },
    );

    test(
      'an expired session is rejected, marked expired, and signed out locally',
      () async {
        final repository = RecordingAuthRepository(user: admin);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: ScriptedGateway([
            refuse(SubscriptionErrorCode.authRequired),
          ]),
          isSupabaseAvailable: true,
        );
        await settle();
        final state = controller.state;
        expect(state, isA<AdminUnauthenticated>());
        expect((state as AdminUnauthenticated).sessionExpired, isTrue);
        expect(repository.signOuts, 1);
        controller.dispose();
      },
    );

    test(
      'a revoked admin loses authorization on the next token refresh',
      () async {
        final repository = RecordingAuthRepository(user: admin);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: ScriptedGateway([
            yes,
            refuse(SubscriptionErrorCode.adminUnauthorized),
          ]),
          isSupabaseAvailable: true,
        );
        await settle();
        expect(controller.state, isA<AdminAuthorized>());

        repository.emit(AuthEventType.tokenRefreshed, user: admin);
        await settle();
        expect(controller.state, isA<AdminUnauthorized>());
        controller.dispose();
      },
    );

    test(
      'a server refusal reported by a later protected call wins immediately',
      () async {
        final repository = RecordingAuthRepository(user: admin);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: ScriptedGateway([yes]),
          isSupabaseAvailable: true,
        );
        await settle();
        expect(controller.state, isA<AdminAuthorized>());

        controller.handleServerRefusal(
          const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized),
        );
        expect(controller.state, isA<AdminUnauthorized>());

        controller.handleServerRefusal(
          const AdminAuthFailure(SubscriptionErrorCode.authRequired),
        );
        expect(controller.state, isA<AdminUnauthenticated>());
        expect(
          (controller.state as AdminUnauthenticated).sessionExpired,
          isTrue,
        );
        await settle();
        expect(repository.signOuts, 1);
        controller.dispose();
      },
    );

    test('a backend failure is not authorization and is retryable', () async {
      final controller = AdminAuthorizationController(
        authRepository: RecordingAuthRepository(user: admin),
        gateway: ScriptedGateway([
          refuse(
            SubscriptionErrorCode.temporaryBackendFailure,
            retryable: true,
          ),
          yes,
        ]),
        isSupabaseAvailable: true,
      );
      await settle();
      final failed = controller.state;
      expect(failed, isA<AdminAuthorizationFailed>());
      expect((failed as AdminAuthorizationFailed).retryable, isTrue);
      expect(failed.isAuthorized, isFalse);

      await controller.refresh();
      expect(controller.state, isA<AdminAuthorized>());
      controller.dispose();
    });

    test('an unexpected gateway error fails closed', () async {
      final controller = AdminAuthorizationController(
        authRepository: RecordingAuthRepository(user: admin),
        gateway: ScriptedGateway([() async => throw StateError('boom')]),
        isSupabaseAvailable: true,
      );
      await settle();
      expect(controller.state, isA<AdminAuthorizationFailed>());
      controller.dispose();
    });

    test(
      'signing in authenticates, then the server decides authorization',
      () async {
        final repository = RecordingAuthRepository();
        final gateway = ScriptedGateway([yes]);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: gateway,
          isSupabaseAvailable: true,
        );
        final signIn = AdminSignInStatusController();
        await settle();
        expect(controller.state, isA<AdminUnauthenticated>());

        await controller.signInWithEmail(
          email: 'ops@example.invalid',
          password: 'correct horse',
          signIn: signIn,
        );
        expect(signIn.state.status, AdminSignInStatus.idle);
        expect(controller.state, isA<AdminAuthorized>());
        expect(gateway.calls, 1);
        controller.dispose();
        signIn.dispose();
      },
    );

    test(
      'a correct password for a normal user still ends unauthorized',
      () async {
        final controller = AdminAuthorizationController(
          authRepository: RecordingAuthRepository(),
          gateway: ScriptedGateway([
            refuse(SubscriptionErrorCode.adminUnauthorized),
          ]),
          isSupabaseAvailable: true,
        );
        final signIn = AdminSignInStatusController();
        await settle();
        await controller.signInWithEmail(
          email: 'user@example.invalid',
          password: 'correct horse',
          signIn: signIn,
        );
        expect(controller.state, isA<AdminUnauthorized>());
        controller.dispose();
        signIn.dispose();
      },
    );

    test(
      'a failed sign-in reports to the form and leaves authorization alone',
      () async {
        final repository = RecordingAuthRepository()
          ..signInFailure = const AuthFailure('Invalid login credentials.');
        final gateway = ScriptedGateway([yes]);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: gateway,
          isSupabaseAvailable: true,
        );
        final signIn = AdminSignInStatusController();
        await settle();
        await controller.signInWithEmail(
          email: 'ops@example.invalid',
          password: 'wrong',
          signIn: signIn,
        );
        expect(signIn.state.status, AdminSignInStatus.failed);
        expect(signIn.state.errorMessage, 'Invalid login credentials.');
        expect(controller.state, isA<AdminUnauthenticated>());
        expect(gateway.calls, 0);
        controller.dispose();
        signIn.dispose();
      },
    );

    test('signing out clears authorization and the local session', () async {
      final repository = RecordingAuthRepository(user: admin);
      final controller = AdminAuthorizationController(
        authRepository: repository,
        gateway: ScriptedGateway([yes]),
        isSupabaseAvailable: true,
      );
      await settle();
      expect(controller.state, isA<AdminAuthorized>());
      await controller.signOut();
      expect(controller.state, isA<AdminUnauthenticated>());
      expect(repository.signOuts, 1);
      expect(repository.currentUser, isNull);
      controller.dispose();
    });

    test('a sign-out event from elsewhere clears authorization', () async {
      final repository = RecordingAuthRepository(user: admin);
      final controller = AdminAuthorizationController(
        authRepository: repository,
        gateway: ScriptedGateway([yes]),
        isSupabaseAvailable: true,
      );
      await settle();
      repository.emit(AuthEventType.signedOut);
      await settle();
      expect(controller.state, isA<AdminUnauthenticated>());
      controller.dispose();
    });

    test(
      'a stale server answer cannot resurrect authorization after sign-out',
      () async {
        final repository = RecordingAuthRepository(user: admin);
        final gateway = ScriptedGateway([]);
        final controller = AdminAuthorizationController(
          authRepository: repository,
          gateway: gateway,
          isSupabaseAvailable: true,
        );
        await settle();
        expect(controller.state, isA<AdminAuthorizationPending>());
        await controller.signOut();
        expect(controller.state, isA<AdminUnauthenticated>());
        // The in-flight verification now answers "admin"; it is too late.
        gateway.pending!.complete(identity);
        await settle();
        expect(controller.state, isA<AdminUnauthenticated>());
        controller.dispose();
      },
    );

    test('without Supabase configuration nobody is an admin', () async {
      final gateway = ScriptedGateway([yes]);
      final controller = AdminAuthorizationController(
        authRepository: RecordingAuthRepository(user: admin),
        gateway: gateway,
        isSupabaseAvailable: false,
      );
      await settle();
      expect(controller.state, isA<AdminConfigurationMissing>());
      expect(gateway.calls, 0);
      controller.dispose();
    });
  });

  group('vocabulary', () {
    test(
      'AdminRole matches the shared contract and rejects everything else',
      () {
        expect(AdminRole.values.map((r) => r.code), ['normal_user', 'admin']);
        expect(AdminRole.fromCode('admin'), AdminRole.admin);
        expect(AdminRole.fromCode('normal_user'), AdminRole.normalUser);
        for (final bad in [
          'Admin',
          'ADMIN',
          'superuser',
          'owner',
          'true',
          '',
        ]) {
          expect(AdminRole.fromCode(bad), isNull, reason: bad);
        }
      },
    );

    test('an AdminIdentity can only ever carry the admin role', () {
      expect(identity.role, AdminRole.admin);
      expect(identity.displayLabel, 'ops@example.invalid');
      expect(const AdminIdentity(userId: 'u', email: null).displayLabel, 'u');
    });
  });
}
