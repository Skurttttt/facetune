import 'package:facetune/admin/app/admin_app.dart';
import 'package:facetune/admin/app/admin_router.dart';
import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/domain/admin_identity.dart';
import 'package:facetune/admin/auth/domain/admin_session_gateway.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A controller frozen in one state, so the router and pages can be tested
/// against every authorization outcome without a server or a session.
class FrozenAuthorization extends AdminAuthorizationController {
  FrozenAuthorization(AdminAuthorizationState frozen)
    : super(
        authRepository: _NoAuth(),
        gateway: _NoGateway(),
        isSupabaseAvailable: false,
      ) {
    state = frozen;
  }

  int signOuts = 0;
  int refreshes = 0;

  @override
  Future<void> signOut() async {
    signOuts++;
    state = const AdminUnauthenticated();
  }

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  /// Simulates the server's answer arriving after a pending check.
  void resolve(AdminAuthorizationState next) => state = next;
}

// Never used: the controller returns before touching either collaborator when
// Supabase is unavailable, and the frozen state is set directly afterwards.
class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('auth repository must not be touched');
}

class _NoGateway implements AdminSessionGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('gateway must not be touched');
}

const identity = AdminIdentity(userId: 'admin-1', email: 'ops@example.invalid');
const detailPath = '/users/20000000-0000-4000-8000-000000000001';

Uri at(String location) => Uri.parse(location);

void main() {
  group('redirectFor', () {
    test('while the server has not answered, everything goes to loading', () {
      const state = AdminAuthorizationPending();
      expect(redirectFor(state, at('/')), AdminRoutes.loading);
      expect(redirectFor(state, at('/login')), AdminRoutes.loading);
      expect(redirectFor(state, at('/loading')), isNull);
      // A protected path is remembered for after the answer.
      expect(redirectFor(state, at('/users')), '/loading?from=%2Fusers');
      expect(
        redirectFor(state, at(detailPath)),
        '/loading?from=%2Fusers%2F20000000-0000-4000-8000-000000000001',
      );
      expect(redirectFor(state, at('/loading?from=%2Fusers')), isNull);
      // Carried through from a login page that was itself remembering it.
      expect(
        redirectFor(state, at('/login?from=%2Faudit')),
        '/loading?from=%2Faudit',
      );
    });

    test('with no session, everything goes to login', () {
      const state = AdminUnauthenticated();
      expect(redirectFor(state, at('/')), AdminRoutes.login);
      expect(redirectFor(state, at('/dashboard')), '/login?from=%2Fdashboard');
      expect(redirectFor(state, at('/loading')), AdminRoutes.login);
      expect(
        redirectFor(state, at('/loading?from=%2Fusage')),
        '/login?from=%2Fusage',
      );
      expect(redirectFor(state, at('/unauthorized')), AdminRoutes.login);
      expect(redirectFor(state, at('/login')), isNull);
      expect(redirectFor(state, at('/login?from=%2Fusers')), isNull);
      expect(
        redirectFor(state, at(detailPath)),
        '/login?from=%2Fusers%2F20000000-0000-4000-8000-000000000001',
      );
      expect(
        redirectFor(const AdminUnauthenticated(sessionExpired: true), at('/')),
        AdminRoutes.login,
      );
    });

    test('a refused, failed, or unconfigured session goes to unauthorized', () {
      for (final state in <AdminAuthorizationState>[
        const AdminUnauthorized(),
        const AdminAuthorizationFailed(
          SubscriptionErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
        const AdminConfigurationMissing(),
      ]) {
        expect(redirectFor(state, at('/dashboard')), AdminRoutes.unauthorized);
        expect(redirectFor(state, at('/login')), AdminRoutes.unauthorized);
        // The remembered path is dropped: a refused account has nowhere to return to.
        expect(
          redirectFor(state, at('/login?from=%2Fusers')),
          AdminRoutes.unauthorized,
        );
        expect(redirectFor(state, at('/unauthorized')), isNull);
      }
    });

    test(
      'an authorized admin reaches every section and skips public pages',
      () {
        const state = AdminAuthorized(identity);
        for (final section in AdminSection.values) {
          expect(
            redirectFor(state, at(section.path)),
            isNull,
            reason: section.path,
          );
        }
        expect(redirectFor(state, at('/')), AdminRoutes.home);
        expect(redirectFor(state, at('/login')), AdminRoutes.home);
        expect(redirectFor(state, at('/loading')), AdminRoutes.home);
        expect(redirectFor(state, at('/unauthorized')), AdminRoutes.home);
        expect(redirectFor(state, at(detailPath)), isNull);
      },
    );

    test(
      'a refresh or sign-in returns the admin to the remembered section',
      () {
        const state = AdminAuthorized(identity);
        expect(redirectFor(state, at('/loading?from=%2Fusers')), '/users');
        expect(redirectFor(state, at('/login?from=%2Faudit')), '/audit');
        expect(
          redirectFor(
            state,
            Uri(
              path: '/login',
              queryParameters: {AdminRoutes.returnToParameter: detailPath},
            ),
          ),
          detailPath,
        );
      },
    );

    test('only exact section paths are ever honoured as a return target', () {
      const state = AdminAuthorized(identity);
      for (final bad in [
        'https://evil.example/',
        '//evil.example',
        '/users/../login',
        '/users?x=1',
        '/admin',
        '/dashboard/',
        'dashboard',
        '/users/not-a-user-id',
        '',
      ]) {
        expect(
          redirectFor(
            state,
            Uri(path: '/loading', queryParameters: {'from': bad}),
          ),
          AdminRoutes.home,
          reason: bad,
        );
      }
    });

    test(
      'an unknown protected path is treated as protected, then landed home',
      () {
        expect(
          redirectFor(const AdminUnauthenticated(), at('/users/123')),
          AdminRoutes.login,
        );
        expect(
          redirectFor(const AdminAuthorizationPending(), at('/nope')),
          AdminRoutes.loading,
        );
        expect(
          redirectFor(const AdminAuthorized(identity), at('/nope')),
          AdminRoutes.home,
        );
      },
    );
  });

  group('FaceTuneAdminApp', () {
    Future<FrozenAuthorization> pump(
      WidgetTester tester,
      AdminAuthorizationState state,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = FrozenAuthorization(state);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthorizationControllerProvider.overrideWith(
              (ref) => controller,
            ),
          ],
          child: const FaceTuneAdminApp(),
        ),
      );
      // Two frames: one to build, one for the router redirect to land. Not
      // `pumpAndSettle`, because the loading page's progress indicator
      // animates forever by design.
      await tester.pump();
      await tester.pump();
      return controller;
    }

    testWidgets('renders no privileged data before the server has decided', (
      tester,
    ) async {
      await pump(tester, const AdminAuthorizationPending());
      expect(find.text('Checking authorization…'), findsOneWidget);
      expect(find.byKey(const Key('admin-identity')), findsNothing);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.byKey(const Key('admin-sign-in')), findsNothing);
      expect(find.textContaining('ops@example.invalid'), findsNothing);
    });

    testWidgets('an unauthenticated visitor sees only the login form', (
      tester,
    ) async {
      await pump(tester, const AdminUnauthenticated());
      expect(find.byKey(const Key('admin-email')), findsOneWidget);
      expect(find.byKey(const Key('admin-password')), findsOneWidget);
      expect(find.byKey(const Key('admin-sign-in')), findsOneWidget);
      expect(find.byKey(const Key('admin-session-expired')), findsNothing);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
    });

    testWidgets('an expired session is explained on the login page', (
      tester,
    ) async {
      await pump(tester, const AdminUnauthenticated(sessionExpired: true));
      expect(find.byKey(const Key('admin-session-expired')), findsOneWidget);
      expect(find.byKey(const Key('admin-identity')), findsNothing);
    });

    testWidgets(
      'a normal user is stopped at the unauthorized page with sign-out',
      (tester) async {
        final controller = await pump(tester, const AdminUnauthorized());
        expect(find.text('Not authorized'), findsOneWidget);
        expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
        expect(find.byKey(const Key('admin-retry')), findsNothing);
        await tester.tap(find.byKey(const Key('admin-sign-out')));
        await tester.pumpAndSettle();
        expect(controller.signOuts, 1);
        expect(find.byKey(const Key('admin-sign-in')), findsOneWidget);
      },
    );

    testWidgets('a backend failure offers retry and sign-out, nothing else', (
      tester,
    ) async {
      final controller = await pump(
        tester,
        const AdminAuthorizationFailed(
          SubscriptionErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
      );
      expect(find.text('Authorization could not be verified'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-retry')));
      await tester.pump();
      expect(controller.refreshes, 1);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
    });

    testWidgets('a verified admin lands in the shell on Dashboard', (
      tester,
    ) async {
      await pump(tester, const AdminAuthorized(identity));
      expect(find.byKey(const Key('admin-nav-rail')), findsOneWidget);
      expect(find.byKey(const Key('admin-identity')), findsOneWidget);
      expect(find.text('ops@example.invalid'), findsOneWidget);
      expect(find.byKey(const Key('admin-section-dashboard')), findsOneWidget);
      expect(find.byKey(const Key('admin-email')), findsNothing);
    });

    testWidgets('an authorized user-detail deep link renders in the shell', (
      tester,
    ) async {
      await pump(tester, const AdminAuthorized(identity));
      GoRouter.of(
        tester.element(find.byKey(const Key('admin-nav-rail'))),
      ).go(detailPath);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-user-detail')), findsOneWidget);
      expect(find.byKey(const Key('admin-nav-rail')), findsOneWidget);
    });

    testWidgets(
      'the server answering after a pending start lands the admin home',
      (tester) async {
        final controller = await pump(
          tester,
          const AdminAuthorizationPending(),
        );
        expect(find.text('Checking authorization…'), findsOneWidget);
        controller.resolve(const AdminAuthorized(identity));
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const Key('admin-section-dashboard')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a missing configuration cannot be signed into', (
      tester,
    ) async {
      await pump(tester, const AdminConfigurationMissing());
      expect(find.text('Admin unavailable'), findsOneWidget);
      expect(find.byKey(const Key('admin-sign-out')), findsNothing);
      expect(find.byKey(const Key('admin-sign-in')), findsNothing);
    });
  });
}
