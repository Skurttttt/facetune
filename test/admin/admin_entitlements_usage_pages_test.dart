import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/entitlements/data/admin_entitlements_gateway_provider.dart';
import 'package:facetune/admin/entitlements/domain/admin_entitlement_models.dart';
import 'package:facetune/admin/entitlements/presentation/pages/admin_entitlements_page.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/admin/usage/data/admin_usage_gateway_provider.dart';
import 'package:facetune/admin/usage/domain/admin_usage_models.dart';
import 'package:facetune/admin/usage/presentation/pages/admin_usage_page.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/usage_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_entitlement_models_test.dart';
import 'admin_entitlements_controller_test.dart';
import 'admin_router_test.dart' show FrozenAuthorization, identity;
import 'admin_usage_models_test.dart';

const _forbidden = [
  'selfie',
  'preview image',
  'tutorial image',
  'signed url',
  'storage path',
  'prompt',
  'gemini',
  'makeup kit inventory',
  'image id',
];

Future<void> pumpPage(
  WidgetTester tester, {
  required Widget child,
  ScriptedEntitlementsGateway? entitlements,
  ScriptedUsageGateway? usage,
}) async {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith(
          (ref) => FrozenAuthorization(const AdminAuthorized(identity)),
        ),
        if (entitlements != null)
          adminEntitlementsGatewayProvider.overrideWithValue(entitlements),
        if (usage != null) adminUsageGatewayProvider.overrideWithValue(usage),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join('\n')
    .toLowerCase();

void main() {
  group('AdminEntitlementsPage', () {
    testWidgets('renders one server page with authoritative figures only', (
      tester,
    ) async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(
          items: [
            entitlementPayload(),
            entitlementPayload(
              id: entitlementId.replaceFirst('1', '9'),
              plan: 'salon_pilot',
              provider: 'admin_granted',
              stored: 'active',
              effective: 'expired',
              expiresAt: '2026-09-20T00:00:00+00:00',
              periodStart: null,
              periodEnd: null,
              autoRenew: false,
              base: 30,
              adjustment: 5,
              effectiveAllowance: 35,
              committed: 3,
              reserved: 0,
              available: 32,
              remaining: 32,
            ),
          ],
        ),
      ]);
      await pumpPage(
        tester,
        child: const AdminEntitlementsPage(),
        entitlements: gateway,
      );

      expect(
        find.byKey(const Key('admin-entitlements-results')),
        findsOneWidget,
      );
      for (final column in [
        'Plan',
        'Status',
        'Provider',
        'Effective allowance',
        'Committed',
        'Reserved',
        'Remaining',
        'Period',
        'Expiration',
        'Auto renew',
        'Created',
        'Updated',
      ]) {
        expect(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.text(column),
          ),
          findsOneWidget,
          reason: column,
        );
      }
      // The effective status is what is shown, as text, not the stored one.
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Admin Granted'), findsOneWidget);
      expect(find.text('Google Play'), findsOneWidget);
      // Server figures verbatim: remaining is 6 (not 8 − 2 − 1 = 5).
      expect(find.text('6'), findsOneWidget);
      expect(find.text('35 AI Looks'), findsOneWidget);
      expect(find.text('2026-09-20 UTC'), findsOneWidget);
      expect(find.text('Not applicable'), findsWidgets);

      final visible = visibleText(tester);
      for (final term in _forbidden) {
        expect(visible, isNot(contains(term)), reason: term);
      }
    });

    testWidgets('filters are sent as contract codes and restart paging', (
      tester,
    ) async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(nextCursor: 'c2'),
        (_, _) async => entitlementPage(),
        (_, _) async => entitlementPage(items: []),
      ]);
      await pumpPage(
        tester,
        child: const AdminEntitlementsPage(),
        entitlements: gateway,
      );
      await tester.tap(find.byKey(const Key('admin-entitlements-next')));
      await tester.pump();
      expect(find.textContaining('Page 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-entitlements-filter-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salon Pilot').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('admin-entitlements-filter-expiration')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expires within 14 days').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin-entitlements-filter-user')),
        userId.toUpperCase(),
      );
      await tester.tap(find.byKey(const Key('admin-entitlements-apply')));
      await tester.pump();
      await tester.pump();

      final (filters, cursor) = gateway.calls.last;
      expect(cursor, isNull);
      expect(filters.planCode, SubscriptionPlanCode.salonPilot);
      expect(filters.expiration, AdminExpirationWindow.within14Days);
      expect(filters.userId, userId);
      expect(find.byKey(const Key('admin-entitlements-empty')), findsOneWidget);
      expect(
        find.text('No entitlements matched these filters.'),
        findsOneWidget,
      );
    });

    testWidgets('a malformed user id never reaches the server', (tester) async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(),
      ]);
      await pumpPage(
        tester,
        child: const AdminEntitlementsPage(),
        entitlements: gateway,
      );
      await tester.enterText(
        find.byKey(const Key('admin-entitlements-filter-user')),
        'not-a-uuid',
      );
      await tester.tap(find.byKey(const Key('admin-entitlements-apply')));
      await tester.pump();
      expect(find.text('Enter a full User ID.'), findsOneWidget);
      expect(gateway.calls, hasLength(1));
    });

    testWidgets('a rejected request has its own state', (tester) async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async =>
            throw const AdminReadFailure(AdminReadFailureType.rejected),
      ]);
      await pumpPage(
        tester,
        child: const AdminEntitlementsPage(),
        entitlements: gateway,
      );
      expect(
        find.byKey(const Key('admin-entitlements-rejected')),
        findsOneWidget,
      );
    });
  });

  group('AdminUsagePage', () {
    testWidgets(
      'released failures are distinguishable from committed success',
      (tester) async {
        final gateway = ScriptedUsageGateway([
          (_, _) async => AdminUsageListItem.decodePage(usagePagePayload()),
        ]);
        await pumpPage(tester, child: const AdminUsagePage(), usage: gateway);

        expect(find.byKey(const Key('admin-usage-results')), findsOneWidget);
        for (final column in [
          'Created',
          'User',
          'Plan',
          'Usage type',
          'Operation ID',
          'Entitlement ID',
          'Status',
          'Unit impact',
          'Source',
          'Committed at',
          'Released at',
          'Failure code',
        ]) {
          expect(
            find.descendant(
              of: find.byType(DataTable),
              matching: find.text(column),
            ),
            findsOneWidget,
            reason: column,
          );
        }
        // Canonical statuses, written out as badges (the column headers and
        // the status filter share some of these words).
        for (final id in ['0001', '0003', '0004']) {
          expect(
            find.byKey(Key('usage-status-33000000-0000-4000-8000-00000000$id')),
            findsOneWidget,
          );
        }
        expect(find.text('Reserved'), findsOneWidget);
        // Impact follows the contract's meaning of each state.
        expect(find.text('1 AI Look consumed'), findsOneWidget);
        expect(find.text('1 AI Look held'), findsOneWidget);
        expect(find.text('0 consumed'), findsOneWidget);
        // The released row shows its sanitized failure code; others show none.
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const Key(
                    'usage-failure-33000000-0000-4000-8000-000000000004',
                  ),
                ),
              )
              .data,
          'GEN_FAILED',
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  const Key(
                    'usage-failure-33000000-0000-4000-8000-000000000001',
                  ),
                ),
              )
              .data,
          '—',
        );
        expect(
          find.text('Final Makeup Preview · Standard Mode'),
          findsOneWidget,
        );
        expect(find.text('Final Makeup Preview'), findsNWidgets(2));

        final visible = visibleText(tester);
        for (final term in _forbidden) {
          expect(visible, isNot(contains(term)), reason: term);
        }
        for (final invented in ['spent', 'used_up', 'failed_charge']) {
          expect(visible, isNot(contains(invented)), reason: invented);
        }
      },
    );

    testWidgets('filters are sent as contract codes with a fixed window', (
      tester,
    ) async {
      final gateway = ScriptedUsageGateway([
        (_, _) async => AdminUsageListItem.decodePage(usagePagePayload()),
        (_, _) async =>
            AdminUsageListItem.decodePage(usagePagePayload(items: [])),
      ]);
      await pumpPage(tester, child: const AdminUsagePage(), usage: gateway);

      await tester.tap(find.byKey(const Key('admin-usage-filter-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Released').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-usage-filter-range')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 7 days').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin-usage-filter-entitlement')),
        usageEntitlementId,
      );
      await tester.tap(find.byKey(const Key('admin-usage-apply')));
      await tester.pump();
      await tester.pump();

      final (filters, cursor) = gateway.calls.last;
      expect(cursor, isNull);
      expect(filters.status, UsageStatus.released);
      expect(filters.entitlementId, usageEntitlementId);
      expect(filters.dateRange, AdminUsageDateRange.last7Days);
      expect(filters.fromInclusive, isNotNull);
      expect(filters.toRpcParams()['p_status'], 'released');
      expect(find.byKey(const Key('admin-usage-empty')), findsOneWidget);
      expect(
        find.text('No usage records matched these filters.'),
        findsOneWidget,
      );
    });

    testWidgets('initial deep-link filters are applied to the first request', (
      tester,
    ) async {
      final gateway = ScriptedUsageGateway([
        (_, _) async => AdminUsageListItem.decodePage(usagePagePayload()),
      ]);
      await pumpPage(
        tester,
        child: const AdminUsagePage(
          initialFilters: AdminUsageFilters(userId: usageUserId),
        ),
        usage: gateway,
      );
      expect(gateway.calls.single.$1.userId, usageUserId);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('admin-usage-filter-user')))
            .controller
            ?.text,
        usageUserId,
      );
    });

    testWidgets('unavailable state offers a retry only when retryable', (
      tester,
    ) async {
      final gateway = ScriptedUsageGateway([
        (_, _) async => throw const AdminReadFailure(
          AdminReadFailureType.unavailable,
          retryable: true,
        ),
        (_, _) async => AdminUsageListItem.decodePage(usagePagePayload()),
      ]);
      await pumpPage(tester, child: const AdminUsagePage(), usage: gateway);
      expect(find.byKey(const Key('admin-usage-unavailable')), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-usage-results')), findsOneWidget);
    });
  });
}
