import 'package:facetune/admin/app/admin_app.dart';
import 'package:facetune/admin/app/admin_router.dart';
import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/domain/admin_identity.dart';
import 'package:facetune/admin/auth/domain/admin_session_gateway.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/shell/admin_shell.dart';
import 'package:facetune/admin/shell/admin_sidebar.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Future<void> signOut() async {
    signOuts++;
    state = const AdminUnauthenticated();
  }

  void resolve(AdminAuthorizationState next) => state = next;
}

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

Future<(FrozenAuthorization, ProviderContainer)> pumpAdmin(
  WidgetTester tester, {
  AdminAuthorizationState state = const AdminAuthorized(identity),
  Size size = const Size(1400, 900),
  String? initialLocation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = FrozenAuthorization(state);
  final container = ProviderContainer(
    overrides: [
      adminAuthorizationControllerProvider.overrideWith((ref) => controller),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const FaceTuneAdminApp(),
    ),
  );
  await tester.pump();
  if (initialLocation != null) {
    container.read(adminRouterProvider).go(initialLocation);
    await tester.pump();
  }
  await tester.pump();
  return (controller, container);
}

String locationOf(ProviderContainer container) =>
    container.read(adminRouterProvider).state.uri.toString();

void main() {
  group('AdminShell navigation', () {
    testWidgets(
      'every section is reachable from the rail and marks itself active',
      (tester) async {
        final (_, container) = await pumpAdmin(tester);
        for (final section in AdminSection.values) {
          await tester.tap(find.byKey(Key('admin-nav-${section.name}')));
          await tester.pumpAndSettle();
          expect(locationOf(container), section.path, reason: section.label);
          expect(
            find.byKey(Key('admin-section-${section.name}')),
            findsOneWidget,
          );
          // The page names itself once, in its own header. Since UI-4 the top
          // utility bar no longer repeats it.
          expect(
            tester.widget<Text>(find.byKey(const Key('admin-page-title'))).data,
            section.label,
          );
          expect(
            find.byKey(const Key('admin-breadcrumb')),
            findsNothing,
            reason: 'a section root needs no trail',
          );
          final sidebar = tester.widget<AdminSidebar>(
            find.byKey(const Key('admin-nav-rail')),
          );
          expect(sidebar.selected, section);
        }
        // The identity chip and sign-out survive every section change.
        expect(find.byKey(const Key('admin-identity')), findsOneWidget);
        expect(find.byKey(const Key('admin-sign-out')), findsOneWidget);
      },
    );

    testWidgets('the rail shows all five sections in order', (tester) async {
      await pumpAdmin(tester);
      final sidebar = tester.widget<AdminSidebar>(
        find.byKey(const Key('admin-nav-rail')),
      );
      expect(AdminSidebar.sections.map((section) => section.label), [
        'Dashboard',
        'Users',
        'Entitlements',
        'Usage',
        'Audit',
      ]);
      expect(
        sidebar.extended,
        isTrue,
        reason: 'labels visible at desktop width',
      );
      // The labels are rendered, in that order, top to bottom.
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('admin-nav-rail')),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(
        labels,
        containsAllInOrder(const [
          'Dashboard',
          'Users',
          'Entitlements',
          'Usage',
          'Audit',
        ]),
      );
    });

    testWidgets('a compact window keeps the rail; a narrow one uses a drawer', (
      tester,
    ) async {
      final (_, container) = await pumpAdmin(
        tester,
        size: const Size(900, 800),
      );
      final sidebar = tester.widget<AdminSidebar>(
        find.byKey(const Key('admin-nav-rail')),
      );
      expect(sidebar.extended, isFalse);
      // Icon-only at this width; the label lives in the tooltip and in the
      // semantic label instead (asserted in admin_sidebar_test.dart).
      expect(
        find.descendant(
          of: find.byKey(const Key('admin-nav-rail')),
          matching: find.text('Entitlements'),
        ),
        findsNothing,
      );

      tester.view.physicalSize = const Size(600, 800);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-nav-drawer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-nav-usage')));
      await tester.pumpAndSettle();
      expect(locationOf(container), AdminSection.usage.path);
      expect(find.byKey(const Key('admin-section-usage')), findsOneWidget);
    });

    testWidgets('a long identity truncates while Sign out stays reachable', (
      tester,
    ) async {
      const longIdentity = AdminIdentity(
        userId: 'admin-1',
        email:
            'operations-administrator-with-an-intentionally-long-address@example.invalid',
      );
      await pumpAdmin(
        tester,
        state: const AdminAuthorized(longIdentity),
        size: const Size(768, 800),
      );

      final identityText = tester.widget<Text>(
        find.byKey(const Key('admin-identity')),
      );
      expect(identityText.maxLines, 1);
      expect(identityText.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.byKey(const Key('admin-identity'))).width,
        lessThanOrEqualTo(180),
      );
      final signOut = find.byKey(const Key('admin-sign-out'));
      expect(signOut.hitTestable(), findsOneWidget);
      expect(tester.getRect(signOut).right, lessThanOrEqualTo(768));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'all five sections are implemented without future placeholders',
      (tester) async {
        final (_, container) = await pumpAdmin(tester);
        for (final section in AdminSection.values) {
          container.read(adminRouterProvider).go(section.path);
          await tester.pump();
          await tester.pump();
          expect(
            find.byKey(Key('admin-section-${section.name}')),
            findsOneWidget,
          );
          expect(
            find.textContaining('arrives in ${section.arrivesIn}'),
            findsNothing,
          );
        }
      },
    );
  });

  group('AdminShell keyboard', () {
    testWidgets('sections are reachable and activatable from the keyboard', (
      tester,
    ) async {
      final (_, container) = await pumpAdmin(tester);
      // Walk focus with Tab until the Users destination holds it, then
      // activate it with Enter — the whole rail must be operable without a
      // pointer.
      var hops = 0;
      while (!_focusIsWithinDestination(const Key('admin-nav-users'))) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (++hops > 20) fail('Users destination never received focus');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(locationOf(container), AdminSection.users.path);
      expect(find.byKey(const Key('admin-section-users')), findsOneWidget);
    });
  });

  group('AdminShell session', () {
    testWidgets('sign-out from the shell removes access', (tester) async {
      final (controller, container) = await pumpAdmin(tester);
      await tester.tap(find.byKey(const Key('admin-sign-out')));
      await tester.pumpAndSettle();
      expect(controller.signOuts, 1);
      // Login, remembering the section for after the next sign-in.
      expect(locationOf(container), '/login?from=%2Fdashboard');
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.byKey(const Key('admin-identity')), findsNothing);
      expect(find.byKey(const Key('admin-sign-in')), findsOneWidget);
    });

    testWidgets('an expired session mid-use returns to the secure state', (
      tester,
    ) async {
      final (controller, container) = await pumpAdmin(
        tester,
        initialLocation: AdminSection.entitlements.path,
      );
      expect(
        find.byKey(const Key('admin-section-entitlements')),
        findsOneWidget,
      );
      controller.resolve(const AdminUnauthenticated(sessionExpired: true));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.byKey(const Key('admin-session-expired')), findsOneWidget);
      // The section is remembered for after re-authentication, and nothing
      // privileged is left on screen.
      expect(locationOf(container), '/login?from=%2Fentitlements');
      expect(find.byKey(const Key('admin-identity')), findsNothing);
    });

    testWidgets('a revocation mid-use stops at the unauthorized page', (
      tester,
    ) async {
      final (controller, container) = await pumpAdmin(
        tester,
        initialLocation: AdminSection.audit.path,
      );
      controller.resolve(const AdminUnauthorized());
      await tester.pump();
      await tester.pump();
      expect(locationOf(container), AdminRoutes.unauthorized);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.text('Not authorized'), findsOneWidget);
    });

    testWidgets(
      'a refresh on a section returns there once the server answers',
      (tester) async {
        // A browser refresh on /usage: the app starts pending at that URL.
        final (controller, container) = await pumpAdmin(
          tester,
          state: const AdminAuthorizationPending(),
          initialLocation: AdminSection.usage.path,
        );
        expect(locationOf(container), '/loading?from=%2Fusage');
        expect(find.text('Checking authorization…'), findsOneWidget);
        expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
        controller.resolve(const AdminAuthorized(identity));
        await tester.pump();
        await tester.pump();
        expect(locationOf(container), AdminSection.usage.path);
        expect(find.byKey(const Key('admin-section-usage')), findsOneWidget);
      },
    );

    testWidgets(
      'a refresh on a section with no session returns there after sign-in',
      (tester) async {
        final (controller, container) = await pumpAdmin(
          tester,
          state: const AdminUnauthenticated(),
          initialLocation: AdminSection.audit.path,
        );
        expect(locationOf(container), '/login?from=%2Faudit');
        expect(find.byKey(const Key('admin-sign-in')), findsOneWidget);
        controller.resolve(const AdminAuthorized(identity));
        await tester.pump();
        await tester.pump();
        expect(locationOf(container), AdminSection.audit.path);
      },
    );

    testWidgets(
      'the shell renders nothing if reached in a non-authorized state',
      (tester) async {
        final controller = FrozenAuthorization(const AdminUnauthorized());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAuthorizationControllerProvider.overrideWith(
                (ref) => controller,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) =>
                        const AdminShell(child: Text('PRIVILEGED')),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('PRIVILEGED'), findsNothing);
        expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
        expect(find.byKey(const Key('admin-sign-out')), findsNothing);
      },
    );
  });
}

/// True when the primary focus sits on exactly one rail destination — the
/// one containing [iconKey] — rather than on a scope enclosing all of them.
bool _focusIsWithinDestination(Key iconKey) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final keysSeen = <Key>{};
  void visit(Element element) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('admin-nav-')) {
      keysSeen.add(key);
    }
    element.visitChildren(visit);
  }

  (focused as Element).visitChildren(visit);
  return keysSeen.length == 1 && keysSeen.single == iconKey;
}
