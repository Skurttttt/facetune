import 'dart:async';

import 'package:facetune/admin/app/admin_app.dart';
import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/dashboard/data/admin_dashboard_gateway_provider.dart';
import 'package:facetune/admin/research/data/admin_research_gateway_provider.dart';
import 'package:facetune/admin/research/domain/admin_research_gateway.dart';
import 'package:facetune/admin/research/domain/admin_research_models.dart';
import 'package:facetune/admin/research/presentation/admin_research_controller.dart';
import 'package:facetune/admin/research/presentation/pages/admin_salon_pilot_research_page.dart';
import 'package:facetune/admin/shared/admin_keyset_list_controller.dart';
import 'package:facetune/admin/shared/admin_cards.dart';
import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'admin_dashboard_controller_test.dart' show ScriptedDashboardGateway;
import 'admin_dashboard_page_test.dart' show fixture;
import 'admin_research_models_test.dart';
import 'admin_router_test.dart' show FrozenAuthorization, identity;

/// Answers each call from a script; records the cursors the listing sends.
class ScriptedResearchGateway implements AdminResearchGateway {
  ScriptedResearchGateway({required this.research, required this.pages});

  final List<Future<AdminSalonPilotResearch> Function()> research;
  final List<Future<AdminListPage<AdminPilotMetricsRow>> Function(String?)>
  pages;
  final cursors = <String?>[];
  int researchCalls = 0;

  @override
  Future<AdminSalonPilotResearch> fetchResearch() {
    researchCalls++;
    if (research.isEmpty) return Completer<AdminSalonPilotResearch>().future;
    return research.removeAt(0)();
  }

  @override
  Future<AdminListPage<AdminPilotMetricsRow>> listPilots({String? cursor}) {
    cursors.add(cursor);
    if (pages.isEmpty) {
      return Completer<AdminListPage<AdminPilotMetricsRow>>().future;
    }
    return pages.removeAt(0)(cursor);
  }
}

Future<AdminSalonPilotResearch> aggregate() async =>
    AdminSalonPilotResearch.decode(researchPayload());

Future<AdminSalonPilotResearch> emptyAggregate() async =>
    AdminSalonPilotResearch.decode(
      researchPayload(
        overrides: {
          'pilots': {
            'users': 0,
            'entitlements': 0,
            'inForce': 0,
            'suspended': 0,
            'lapsedOrExpired': 0,
            'revoked': 0,
            'expiringWithin14Days': 0,
          },
        },
      ),
    );

Future<AdminListPage<AdminPilotMetricsRow>> onePage(String? _) async =>
    AdminPilotMetricsRow.decodePage(
      pilotsPayload([
        pilotRow(),
        pilotRow(
          id: '31000000-0000-4000-8000-000000000002',
          userId: '20000000-0000-4000-8000-000000000002',
          email: null,
          storedStatus: 'active',
          effectiveStatus: 'expired',
          overrides: {'lastActivityAt': null},
        ),
      ]),
    );

Future<AdminListPage<AdminPilotMetricsRow>> emptyPage(String? _) async =>
    AdminPilotMetricsRow.decodePage(pilotsPayload([]));

Future<ScriptedResearchGateway> pumpResearch(
  WidgetTester tester, {
  List<Future<AdminSalonPilotResearch> Function()>? research,
  List<Future<AdminListPage<AdminPilotMetricsRow>> Function(String?)>? pages,
  AdminAuthorizationState state = const AdminAuthorized(identity),
}) async {
  tester.view.physicalSize = const Size(1800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gateway = ScriptedResearchGateway(
    research: research ?? [aggregate],
    pages: pages ?? [onePage],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith(
          (ref) => FrozenAuthorization(state),
        ),
        adminResearchGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AdminSalonPilotResearchPage()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return gateway;
}

String tileValue(WidgetTester tester, String key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
  );
  return texts.elementAt(1).data!;
}

void main() {
  group('AdminResearchController', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('loads on construction and keeps figures while refreshing', () async {
      final gateway = ScriptedResearchGateway(
        research: [aggregate, aggregate],
        pages: const [],
      );
      final controller = AdminResearchController(
        gateway: gateway,
        onServerRefusal: (_) => fail('no refusal expected'),
        isAuthorized: () => true,
      );
      expect(controller.state, isA<AdminResearchLoading>());
      await settle();
      expect(controller.state, isA<AdminResearchReady>());
      final refresh = controller.refresh();
      expect(
        (controller.state as AdminResearchReady).refreshing,
        isTrue,
        reason: 'previous figures stay on screen during a refresh',
      );
      await refresh;
      expect((controller.state as AdminResearchReady).refreshing, isFalse);
      expect(gateway.researchCalls, 2);
    });

    test('never asks the server while the session is not administrative', () {
      final gateway = ScriptedResearchGateway(
        research: [aggregate],
        pages: const [],
      );
      final controller = AdminResearchController(
        gateway: gateway,
        onServerRefusal: (_) {},
        isAuthorized: () => false,
      );
      expect(controller.state, isA<AdminResearchUnavailable>());
      expect(gateway.researchCalls, 0);
    });

    test('a server refusal is forwarded and the page is unavailable', () async {
      final refusals = <AdminAuthFailure>[];
      final controller = AdminResearchController(
        gateway: ScriptedResearchGateway(
          research: [
            () async => throw const AdminAuthFailure(
              SubscriptionErrorCode.adminUnauthorized,
            ),
          ],
          pages: const [],
        ),
        onServerRefusal: refusals.add,
        isAuthorized: () => true,
      );
      await settle();
      expect(refusals.single.code, SubscriptionErrorCode.adminUnauthorized);
      final state = controller.state as AdminResearchUnavailable;
      expect(state.retryable, isFalse);
    });

    test(
      'a read failure or malformed answer is unavailable, retryable',
      () async {
        for (final failure in [
          () async => throw const AdminReadFailure(
            AdminReadFailureType.unavailable,
            retryable: true,
          ),
          () async => throw StateError('boom'),
        ]) {
          final controller = AdminResearchController(
            gateway: ScriptedResearchGateway(
              research: [failure],
              pages: const [],
            ),
            onServerRefusal: (_) => fail('not an authorization refusal'),
            isAuthorized: () => true,
          );
          await settle();
          final state = controller.state as AdminResearchUnavailable;
          expect(state.retryable, isTrue);
        }
      },
    );
  });

  group('AdminSalonPilotResearchPage', () {
    testWidgets('renders the aggregate verbatim: counts, usage, operations', (
      tester,
    ) async {
      await pumpResearch(tester);
      await tester.pump();
      expect(find.byKey(const Key('admin-research-metrics')), findsOneWidget);
      expect(find.byKey(const Key('admin-research-as-of')), findsOneWidget);
      expect(tileValue(tester, 'tile-pilot-users'), '2');
      expect(tileValue(tester, 'tile-pilot-grants'), '2');
      expect(tileValue(tester, 'tile-pilot-in-force'), '2');
      expect(tileValue(tester, 'tile-pilot-expiring'), '1');
      expect(tileValue(tester, 'tile-looks-granted'), '40');
      expect(tileValue(tester, 'tile-looks-adjustments'), '+10');
      expect(tileValue(tester, 'tile-looks-effective'), '50');
      expect(tileValue(tester, 'tile-looks-committed'), '31');
      expect(tileValue(tester, 'tile-looks-reserved'), '1');
      expect(tileValue(tester, 'tile-looks-released'), '3');
      expect(tileValue(tester, 'tile-looks-remaining'), '19');
      expect(tileValue(tester, 'tile-ops-final-preview'), '31');
      expect(tileValue(tester, 'tile-ops-tutorial-manifest'), '2');
      expect(tileValue(tester, 'tile-usage-attempts'), '41');
      expect(tileValue(tester, 'tile-usage-total-tokens'), '30200');
      expect(find.text('27000 in · 3200 out'), findsOneWidget);
      expect(tileValue(tester, 'tile-usage-output-images'), '31');
      expect(tileValue(tester, 'tile-usage-image-tokens'), '26700');
      expect(
        find.textContaining('4 of 37 events carried no token data'),
        findsOneWidget,
      );
      // Nothing is a rate, a percentage, or a currency.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('₱'), findsNothing);
    });

    testWidgets('cost is shown as "Not available" with the server reason', (
      tester,
    ) async {
      await pumpResearch(tester);
      await tester.pump();
      expect(tileValue(tester, 'tile-cost-total'), 'Not available');
      expect(tileValue(tester, 'tile-cost-per-look'), 'Not available');
      expect(find.text('NO_PROVIDER_COST_DATA'), findsNWidgets(2));
      expect(
        find.textContaining('records provider usage, not provider cost'),
        findsOneWidget,
      );
      // No number is ever shown next to a money label.
      final tiles = [
        find.byKey(const Key('tile-cost-total')),
        find.byKey(const Key('tile-cost-per-look')),
      ];
      for (final tile in tiles) {
        for (final text in tester.widgetList<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        )) {
          expect(RegExp(r'\d').hasMatch(text.data ?? ''), isFalse);
        }
      }
    });

    testWidgets('a cost the server does report is rendered with its currency', (
      tester,
    ) async {
      await pumpResearch(
        tester,
        research: [
          () async => AdminSalonPilotResearch.decode(
            researchPayload(
              cost: {
                'available': true,
                'reason': null,
                'currency': 'USD',
                'totalBillableCost': 12.5,
                'effectiveCostPerDeliveredAiLook': 0.4,
              },
            ),
          ),
        ],
      );
      await tester.pump();
      expect(tileValue(tester, 'tile-cost-total'), '12.5 USD');
      expect(tileValue(tester, 'tile-cost-per-look'), '0.4 USD');
      expect(find.text('Not available'), findsNothing);
    });

    testWidgets('renders one row per pilot with its own counters', (
      tester,
    ) async {
      final gateway = await pumpResearch(tester);
      await tester.pump();
      expect(gateway.cursors, [null]);
      expect(find.byKey(const Key('admin-pilots-results')), findsOneWidget);
      const a = '31000000-0000-4000-8000-000000000001';
      const b = '31000000-0000-4000-8000-000000000002';
      expect(find.byKey(const Key('pilot-status-$a')), findsOneWidget);
      expect(find.byKey(const Key('pilot-status-$b')), findsOneWidget);
      expect(find.text('pilot@example.invalid'), findsOneWidget);
      expect(find.text('No email'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-effective-$a'))).data,
        '40',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-delivered-$a'))).data,
        '27',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('pilot-tokens-$a'))).data,
        '28200',
      );
      // Effective status is written out; a stored/effective divergence too.
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Expired (stored: Active)'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.byKey(const Key('admin-pilots-page-label')), findsOneWidget);
      expect(find.text('Page 1 · 2 of up to 25'), findsOneWidget);
      final next = tester.widget<OutlinedButton>(
        find.byKey(const Key('admin-pilots-next')),
      );
      expect(next.onPressed, isNull, reason: 'no next cursor on the last page');
    });

    testWidgets('uses the shared card and operational table system', (
      tester,
    ) async {
      await pumpResearch(tester);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('tile-pilot-users')),
          matching: find.byType(AdminStatCard),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tile-ops-final-preview')),
          matching: find.byType(AdminCard),
        ),
        findsOneWidget,
      );
      expect(find.byType(AdminTable), findsOneWidget);
      expect(find.byType(AdminIdentityCell), findsNWidgets(2));
      expect(find.byType(AdminTableActions), findsNWidgets(2));
      expect(
        find.byKey(const Key('view-user-31000000-0000-4000-8000-000000000001')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('view-usage-31000000-0000-4000-8000-000000000001'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pages forward and back with the server cursor', (
      tester,
    ) async {
      Future<AdminListPage<AdminPilotMetricsRow>> first(String? _) async =>
          AdminPilotMetricsRow.decodePage(
            pilotsPayload([pilotRow()], nextCursor: 'c1'),
          );
      final gateway = await pumpResearch(
        tester,
        pages: [first, onePage, first],
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('admin-pilots-next')));
      await tester.tap(find.byKey(const Key('admin-pilots-next')));
      await tester.pump();
      await tester.pump();
      expect(gateway.cursors, [null, 'c1']);
      expect(find.text('Page 2 · 2 of up to 25'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('admin-pilots-previous')),
      );
      await tester.tap(find.byKey(const Key('admin-pilots-previous')));
      await tester.pump();
      await tester.pump();
      expect(gateway.cursors, [null, 'c1', null]);
      expect(find.text('Page 1 · 1 of up to 25'), findsOneWidget);
    });

    testWidgets('empty: no grants yet, in both sections', (tester) async {
      await pumpResearch(
        tester,
        research: [emptyAggregate],
        pages: [emptyPage],
      );
      await tester.pump();
      expect(find.byKey(const Key('admin-research-empty')), findsOneWidget);
      expect(find.byKey(const Key('admin-pilots-empty')), findsOneWidget);
      expect(find.byKey(const Key('admin-research-metrics')), findsNothing);
    });

    testWidgets('loading: both sections show progress, refresh disabled', (
      tester,
    ) async {
      await pumpResearch(tester, research: const [], pages: const []);
      expect(find.byKey(const Key('admin-research-loading')), findsOneWidget);
      expect(find.byKey(const Key('admin-pilots-loading')), findsOneWidget);
      final refresh = tester.widget<OutlinedButton>(
        find.byKey(const Key('admin-research-refresh')),
      );
      expect(refresh.onPressed, isNull);
    });

    testWidgets('unavailable: each section fails on its own, with retry', (
      tester,
    ) async {
      final gateway = await pumpResearch(
        tester,
        research: [
          () async => throw const AdminReadFailure(
            AdminReadFailureType.unavailable,
            retryable: true,
          ),
          aggregate,
        ],
        pages: [
          (_) async => throw const AdminReadFailure(
            AdminReadFailureType.unavailable,
            retryable: true,
          ),
          onePage,
        ],
      );
      await tester.pump();
      expect(
        find.byKey(const Key('admin-research-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('admin-pilots-unavailable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-research-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-research-metrics')), findsOneWidget);
      expect(find.byKey(const Key('admin-pilots-unavailable')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('admin-pilots-retry')));
      await tester.tap(find.byKey(const Key('admin-pilots-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-pilots-results')), findsOneWidget);
      expect(gateway.researchCalls, 2);
      expect(gateway.cursors, [null, null]);
    });

    testWidgets('a rejected cursor is reported, not retried', (tester) async {
      await pumpResearch(
        tester,
        pages: [
          (_) async =>
              throw const AdminReadFailure(AdminReadFailureType.rejected),
        ],
      );
      await tester.pump();
      expect(find.byKey(const Key('admin-pilots-rejected')), findsOneWidget);
      expect(find.byKey(const Key('admin-pilots-retry')), findsNothing);
    });

    testWidgets('refresh reloads both sections', (tester) async {
      final gateway = await pumpResearch(
        tester,
        research: [aggregate, aggregate],
        pages: [onePage, onePage],
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('admin-research-refresh')));
      await tester.pump();
      await tester.pump();
      expect(gateway.researchCalls, 2);
      expect(gateway.cursors, [null, null]);
    });

    testWidgets('never renders private content or a hardcoded cost', (
      tester,
    ) async {
      await pumpResearch(tester);
      await tester.pump();
      for (final forbidden in [
        'selfie',
        'preview image',
        'tutorial image',
        'signed url',
        'storage path',
        'prompt',
        'gemini',
        'makeup kit',
        'purchase token',
        '₱',
        'PHP',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
    });
  });

  group('routing', () {
    testWidgets('the dashboard links to the research page inside the shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final research = ScriptedResearchGateway(
        research: [aggregate],
        pages: [onePage],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthorizationControllerProvider.overrideWith(
              (ref) => FrozenAuthorization(const AdminAuthorized(identity)),
            ),
            adminDashboardGatewayProvider.overrideWithValue(
              ScriptedDashboardGateway([fixture]),
            ),
            adminResearchGatewayProvider.overrideWithValue(research),
          ],
          child: const FaceTuneAdminApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-section-dashboard')), findsOneWidget);
      final researchLink = find.byKey(
        const Key('admin-dashboard-research-link'),
      );
      await tester.ensureVisible(researchLink);
      await tester.tap(researchLink);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-section-research')), findsOneWidget);
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('admin-section-research'))),
      );
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AdminRoutes.salonPilotResearch,
      );
      // The shell keeps Dashboard selected for its sub-page.
      expect(
        AdminSection.fromPath(AdminRoutes.salonPilotResearch),
        AdminSection.dashboard,
      );
    });

    test('the research path is a valid return target; look-alikes are not', () {
      expect(
        AdminRoutes.sanitizedReturnTo(AdminRoutes.salonPilotResearch),
        AdminRoutes.salonPilotResearch,
      );
      for (final bad in [
        '/dashboard/salon-pilot/',
        '/dashboard/salon-pilot?x=1',
        '/dashboard/research',
        '/dashboard/salon-pilot/../login',
      ]) {
        expect(AdminRoutes.sanitizedReturnTo(bad), isNull, reason: bad);
      }
    });
  });
}
