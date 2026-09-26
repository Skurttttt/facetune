import 'package:facetune/admin/audit/data/admin_audit_gateway_provider.dart';
import 'package:facetune/admin/audit/domain/admin_audit_gateway.dart';
import 'package:facetune/admin/audit/domain/admin_audit_models.dart';
import 'package:facetune/admin/audit/presentation/pages/admin_audit_detail_page.dart';
import 'package:facetune/admin/audit/presentation/pages/admin_audit_page.dart';
import 'package:facetune/admin/audit/presentation/pages/admin_entitlement_history_page.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/shared/admin_form_widgets.dart';
import 'package:facetune/admin/shared/admin_keyset_list_controller.dart';
import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_router_test.dart' show FrozenAuthorization, identity;

const adminId = '80000000-0000-4000-8000-000000000a00';
const targetId = '80000000-0000-4000-8000-000000000001';
const entitlementId = '81000000-0000-4000-8000-000000000001';
const eventId = '82000000-0000-4000-8000-000000000001';

Map<String, Object?> snapshot({
  String status = 'active',
  int allowance = 30,
  int adjustment = 0,
  int version = 1,
}) => {
  'status': status,
  'planCode': 'salon_pilot',
  'effectiveAllowance': allowance,
  'allowanceAdjustmentTotal': adjustment,
  'expiresAt': '2026-11-20T00:00:00Z',
  'version': version,
};

Map<String, Object?> auditSummary({
  String id = eventId,
  String action = 'increase_allowance',
  String createdAt = '2026-09-22T10:00:00Z',
}) => {
  'id': id,
  'source': 'admin',
  'adminUserId': adminId,
  'adminEmail': 'ops@example.invalid',
  'action': action,
  'targetUserId': targetId,
  'targetEmail': 'artist@example.invalid',
  'targetEntitlementId': entitlementId,
  'createdAt': createdAt,
};

Map<String, Object?> auditPage({List<Object?>? items, String? nextCursor}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'pageSize': 25,
  'sort': {'field': 'createdAt', 'direction': 'desc'},
  'items': items ?? [auditSummary()],
  'nextCursor': nextCursor,
};

Map<String, Object?> detailEnvelope() => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'event': {
    ...auditSummary(),
    'beforeState': snapshot(),
    'afterState': snapshot(allowance: 40, adjustment: 10, version: 2),
    'reason': 'Panel extension',
    'requestCorrelationId': '83000000-0000-4000-8000-000000000001',
    'idempotencyKey': 'request-retry-key',
  },
};

Map<String, Object?> historyEvent({
  required String id,
  required String eventType,
  String source = 'admin',
  String? action,
  String? provider,
  String occurredAt = '2026-09-22T10:00:00Z',
  Map<String, Object?>? before,
  Map<String, Object?>? after,
}) => {
  'id': id,
  'source': source,
  'eventType': eventType,
  'action': action,
  'actorUserId': source == 'admin' ? adminId : null,
  'actorEmail': source == 'admin' ? 'ops@example.invalid' : null,
  'reason': source == 'admin' ? 'Operational reason' : null,
  'beforeState': before,
  'afterState': after,
  'requestCorrelationId': source == 'admin'
      ? '83000000-0000-4000-8000-000000000001'
      : null,
  'provider': provider,
  'occurredAt': occurredAt,
};

Map<String, Object?> historyPage(List<Object?> items) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'pageSize': 25,
  'sort': {'field': 'createdAt', 'direction': 'desc'},
  'items': items,
  'nextCursor': null,
};

class FakeAuditGateway implements AdminAuditGateway {
  FakeAuditGateway({
    List<AdminListPage<AdminAuditListItem>>? auditPages,
    this.detail,
    List<AdminListPage<AdminEntitlementHistoryEvent>>? historyPages,
  }) : auditPages = [...?auditPages],
       historyPages = [...?historyPages];

  final List<AdminListPage<AdminAuditListItem>> auditPages;
  final List<AdminListPage<AdminEntitlementHistoryEvent>> historyPages;
  final AdminAuditDetail? detail;
  final List<(AdminAuditFilters, String?)> auditCalls = [];
  final List<(String, String?)> historyCalls = [];

  @override
  Future<AdminListPage<AdminAuditListItem>> listAudit(
    AdminAuditFilters filters, {
    String? cursor,
  }) async {
    auditCalls.add((filters, cursor));
    return auditPages.removeAt(0);
  }

  @override
  Future<AdminAuditDetail?> getAuditEvent(String eventId) async => detail;

  @override
  Future<AdminListPage<AdminEntitlementHistoryEvent>> listEntitlementHistory(
    String entitlementId, {
    String? cursor,
  }) async {
    historyCalls.add((entitlementId, cursor));
    return historyPages.removeAt(0);
  }
}

Future<void> pumpAuditWidget(
  WidgetTester tester, {
  required Widget child,
  required FakeAuditGateway gateway,
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
        adminAuditGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  test('audit/detail/history wire models are strict and privacy-shaped', () {
    final page = AdminAuditListItem.decodePage(auditPage());
    expect(page.items.single.action, AdminAuditAction.increaseAllowance);
    expect(page.items.single.adminEmail, 'ops@example.invalid');

    final detail = AdminAuditDetail.decodeEnvelope(detailEnvelope());
    expect(detail, isNotNull);
    expect(detail!.beforeState!.effectiveAllowance, 30);
    expect(detail.afterState!.effectiveAllowance, 40);
    expect(detail.requestCorrelationId, isNotNull);

    final history = AdminEntitlementHistoryEvent.decodePage(
      historyPage([
        historyEvent(
          id: '1',
          eventType: 'provider_state_change',
          source: 'provider',
          provider: 'google_play',
        ),
      ]),
    );
    expect(
      history.items.single.eventType,
      AdminEntitlementHistoryEventType.providerStateChange,
    );
    expect(history.items.single.action, isNull);
  });

  testWidgets(
    'audit list applies filters and pages only through server cursors',
    (tester) async {
      final gateway = FakeAuditGateway(
        auditPages: [
          AdminAuditListItem.decodePage(auditPage(nextCursor: 'cursor-2')),
          AdminAuditListItem.decodePage(
            auditPage(
              items: [
                auditSummary(
                  id: '82000000-0000-4000-8000-000000000002',
                  action: 'revoke_entitlement',
                ),
              ],
            ),
          ),
          AdminAuditListItem.decodePage(auditPage(items: [])),
          AdminAuditListItem.decodePage(auditPage()),
        ],
      );
      await pumpAuditWidget(
        tester,
        child: const AdminAuditPage(),
        gateway: gateway,
      );
      expect(find.byKey(const Key('admin-audit-results')), findsOneWidget);
      expect(find.byKey(const Key('admin-audit-filter-panel')), findsOneWidget);
      expect(find.byType(AdminLabeledField), findsNWidgets(6));
      expect(find.byKey(const Key('admin-audit-table')), findsOneWidget);
      expect(find.byType(AdminTable), findsOneWidget);
      expect(find.byType(AdminIdentityCell), findsNWidgets(2));
      expect(find.text('Allowance increased'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-audit-next')));
      await tester.pump();
      await tester.pump();
      expect(gateway.auditCalls[1].$2, 'cursor-2');
      expect(find.text('Entitlement revoked'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin-audit-filter-admin')),
        adminId,
      );
      await tester.tap(find.byKey(const Key('admin-audit-filter-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entitlement suspended').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-audit-apply')));
      await tester.pump();
      await tester.pump();
      expect(gateway.auditCalls.last.$2, isNull);
      expect(gateway.auditCalls.last.$1.adminUserId, adminId);
      expect(
        gateway.auditCalls.last.$1.action,
        AdminAuditAction.suspendEntitlement,
      );
      expect(find.byKey(const Key('admin-audit-empty')), findsOneWidget);
      expect(find.text('No matching audit events'), findsOneWidget);
      expect(
        find.text('No audit events matched these filters.'),
        findsOneWidget,
      );
      expect(find.byType(AdminTable), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('admin-audit-empty')),
          matching: find.byType(AdminTable),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('admin-audit-clear')));
      await tester.pump();
      await tester.pump();
      final (cleared, clearCursor) = gateway.auditCalls.last;
      expect(clearCursor, isNull);
      expect(cleared, AdminAuditFilters.none);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('admin-audit-filter-admin')),
            )
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'audit detail is complete, read-only, and shows no secret fields',
    (tester) async {
      final gateway = FakeAuditGateway(
        detail: AdminAuditDetail.decodeEnvelope(detailEnvelope()),
      );
      await pumpAuditWidget(
        tester,
        child: const AdminAuditDetailPage(eventId: eventId),
        gateway: gateway,
      );
      for (final value in [
        'ops@example.invalid',
        'Allowance increased',
        'artist@example.invalid',
        'Panel extension',
        '83000000-0000-4000-8000-000000000001',
        'Admin',
        'Before state',
        'After state',
      ]) {
        expect(find.text(value), findsWidgets, reason: value);
      }
      final visible = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .join(' ')
          .toLowerCase();
      for (final forbidden in [
        'edit audit',
        'delete audit',
        'rewrite audit',
        'purchase token',
        'signed url',
        'jwt',
        'service role',
        'selfie',
        'prompt',
        'gemini',
      ]) {
        expect(visible, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  testWidgets('entitlement history renders meaningful events in server order', (
    tester,
  ) async {
    final events = AdminEntitlementHistoryEvent.decodePage(
      historyPage([
        historyEvent(
          id: '7',
          eventType: 'revoke_entitlement',
          action: 'revoke_entitlement',
          before: snapshot(status: 'active', version: 5),
          after: snapshot(status: 'revoked', version: 6),
        ),
        historyEvent(
          id: '6',
          eventType: 'reactivate_entitlement',
          action: 'reactivate_entitlement',
          before: snapshot(status: 'suspended', version: 4),
          after: snapshot(status: 'active', version: 5),
        ),
        historyEvent(
          id: '5',
          eventType: 'suspend_entitlement',
          action: 'suspend_entitlement',
          before: snapshot(status: 'active', version: 3),
          after: snapshot(status: 'suspended', version: 4),
        ),
        historyEvent(
          id: '4',
          eventType: 'provider_state_change',
          source: 'provider',
          provider: 'google_play',
        ),
        historyEvent(
          id: '3',
          eventType: 'extend_expiration',
          action: 'extend_expiration',
          before: snapshot(version: 2),
          after: snapshot(version: 3),
        ),
        historyEvent(
          id: '2',
          eventType: 'increase_allowance',
          action: 'increase_allowance',
          before: snapshot(),
          after: snapshot(allowance: 40, adjustment: 10, version: 2),
        ),
        historyEvent(
          id: '1',
          eventType: 'grant_salon_pilot',
          action: 'grant_salon_pilot',
          after: snapshot(),
        ),
      ]),
    );
    final gateway = FakeAuditGateway(historyPages: [events]);
    await pumpAuditWidget(
      tester,
      child: const AdminEntitlementHistoryPage(entitlementId: entitlementId),
      gateway: gateway,
    );
    for (final title in [
      'Salon Pilot granted',
      'Allowance adjusted',
      'Expiration extended',
      'Suspended',
      'Reactivated',
      'Revoked',
      'Provider-driven state change',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    final cards = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(cards, isNotEmpty);
    expect(gateway.historyCalls.single.$1, entitlementId);
    expect(find.text('Effective allowance 30 → 40'), findsOneWidget);
  });
}
