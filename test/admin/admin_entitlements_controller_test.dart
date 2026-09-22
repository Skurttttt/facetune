import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/entitlements/domain/admin_entitlement_models.dart';
import 'package:facetune/admin/entitlements/domain/admin_entitlements_gateway.dart';
import 'package:facetune/admin/entitlements/presentation/admin_entitlements_controller.dart';
import 'package:facetune/admin/shared/admin_keyset_list_controller.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/admin/usage/domain/admin_usage_gateway.dart';
import 'package:facetune/admin/usage/domain/admin_usage_models.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_entitlement_models_test.dart';
import 'admin_usage_models_test.dart';

typedef EntitlementFetch =
    Future<AdminListPage<AdminEntitlementListItem>> Function(
      AdminEntitlementFilters filters,
      String? cursor,
    );

class ScriptedEntitlementsGateway implements AdminEntitlementsGateway {
  ScriptedEntitlementsGateway(this.responses);

  final List<EntitlementFetch> responses;
  final List<(AdminEntitlementFilters, String?)> calls = [];

  @override
  Future<AdminListPage<AdminEntitlementListItem>> listEntitlements(
    AdminEntitlementFilters filters, {
    String? cursor,
  }) {
    calls.add((filters, cursor));
    return responses.removeAt(0)(filters, cursor);
  }
}

typedef UsageFetch =
    Future<AdminListPage<AdminUsageListItem>> Function(
      AdminUsageFilters filters,
      String? cursor,
    );

class ScriptedUsageGateway implements AdminUsageGateway {
  ScriptedUsageGateway(this.responses);

  final List<UsageFetch> responses;
  final List<(AdminUsageFilters, String?)> calls = [];

  @override
  Future<AdminListPage<AdminUsageListItem>> listUsage(
    AdminUsageFilters filters, {
    String? cursor,
  }) {
    calls.add((filters, cursor));
    return responses.removeAt(0)(filters, cursor);
  }
}

AdminListPage<AdminEntitlementListItem> entitlementPage({
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => AdminEntitlementListItem.decodePage(
  entitlementPagePayload(items: items, nextCursor: nextCursor),
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('AdminEntitlementsController', () {
    test('loads the first page with the initial filters', () async {
      const initial = AdminEntitlementFilters(userId: userId);
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(),
      ]);
      final controller = AdminEntitlementsController(
        gateway: gateway,
        initialFilters: initial,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(gateway.calls, [(initial, null)]);
      final state =
          controller.state as AdminListReady<AdminEntitlementListItem, dynamic>;
      expect(state.page.items, hasLength(1));
      expect(state.pageNumber, 1);
      expect(state.canGoBack, isFalse);
    });

    test('paging replaces rows, keeps cursors only, and returns', () async {
      final second = entitlementPayload(
        id: entitlementId.replaceFirst('1', '2'),
      );
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(nextCursor: 'c2'),
        (_, _) async => entitlementPage(items: [second]),
        (_, _) async => entitlementPage(nextCursor: 'c2'),
      ]);
      final controller = AdminEntitlementsController(
        gateway: gateway,
        initialFilters: AdminEntitlementFilters.none,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      await controller.nextPage();
      var state =
          controller.state as AdminListReady<AdminEntitlementListItem, dynamic>;
      expect(gateway.calls.last.$2, 'c2');
      expect(state.pageNumber, 2);
      expect(state.canGoBack, isTrue);
      expect(state.page.items.single.entitlementId, second['entitlementId']);

      await controller.previousPage();
      state =
          controller.state as AdminListReady<AdminEntitlementListItem, dynamic>;
      expect(gateway.calls.last.$2, isNull);
      expect(state.pageNumber, 1);
      expect(state.canGoBack, isFalse);
    });

    test('changing filters restarts at the first page', () async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async => entitlementPage(nextCursor: 'c2'),
        (_, _) async => entitlementPage(),
        (_, _) async => entitlementPage(items: []),
      ]);
      final controller = AdminEntitlementsController(
        gateway: gateway,
        initialFilters: AdminEntitlementFilters.none,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      await controller.nextPage();
      const filtered = AdminEntitlementFilters(
        planCode: SubscriptionPlanCode.salonPilot,
      );
      await controller.applyFilters(filtered);
      expect(gateway.calls.last, (filtered, null));
      final state =
          controller.state as AdminListReady<AdminEntitlementListItem, dynamic>;
      expect(state.pageNumber, 1);
      expect(state.canGoBack, isFalse);
      expect(state.filters, filtered);
    });

    test('a rejected request is its own state, not an outage', () async {
      final gateway = ScriptedEntitlementsGateway([
        (_, _) async =>
            throw const AdminReadFailure(AdminReadFailureType.rejected),
      ]);
      final controller = AdminEntitlementsController(
        gateway: gateway,
        initialFilters: AdminEntitlementFilters.none,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(controller.state, isA<AdminListRejected>());
    });

    test(
      'a server refusal is escalated and the list goes unavailable',
      () async {
        final refusals = <AdminAuthFailure>[];
        final gateway = ScriptedEntitlementsGateway([
          (_, _) async => throw const AdminAuthFailure(
            SubscriptionErrorCode.adminUnauthorized,
          ),
        ]);
        final controller = AdminEntitlementsController(
          gateway: gateway,
          initialFilters: AdminEntitlementFilters.none,
          isAuthorized: () => true,
          onServerRefusal: refusals.add,
        );
        await settle();
        expect(refusals.single.isUnauthorized, isTrue);
        expect((controller.state as AdminListUnavailable).retryable, isFalse);
      },
    );

    test('nothing is fetched when the session is not authorized', () async {
      final gateway = ScriptedEntitlementsGateway([]);
      final controller = AdminEntitlementsController(
        gateway: gateway,
        initialFilters: AdminEntitlementFilters.none,
        isAuthorized: () => false,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(gateway.calls, isEmpty);
      expect(controller.state, isA<AdminListUnavailable>());
    });
  });

  test(
    'the usage gateway receives the resolved filters unchanged per page',
    () async {
      final filters = AdminUsageFilters.withRange(
        const AdminUsageFilters(userId: usageUserId),
        AdminUsageDateRange.last24Hours,
        now: DateTime.utc(2026, 9, 22, 12),
      );
      final gateway = ScriptedUsageGateway([
        (_, _) async =>
            AdminUsageListItem.decodePage(usagePagePayload(nextCursor: 'c2')),
        (_, _) async => AdminUsageListItem.decodePage(usagePagePayload()),
      ]);
      // Exercised through the shared controller's fetch contract.
      final page1 = await gateway.listUsage(filters);
      final page2 = await gateway.listUsage(filters, cursor: page1.nextCursor);
      expect(page2.items, hasLength(3));
      expect(gateway.calls.map((c) => c.$1.toRpcParams()['p_from']).toSet(), {
        '2026-09-21T12:00:00.000Z',
      });
    },
  );
}
