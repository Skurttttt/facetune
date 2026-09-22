import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/admin/usage/domain/admin_usage_models.dart';
import 'package:facetune/features/subscription/domain/entities/purchased_credit_summary.dart'
    show AllowanceSource;
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/usage_status.dart';
import 'package:facetune/features/subscription/domain/entities/usage_type.dart';
import 'package:flutter_test/flutter_test.dart';

const usageUserId = '30000000-0000-4000-8000-000000000001';
const usageEntitlementId = '31000000-0000-4000-8000-000000000001';

/// One row exactly as `admin_list_usage` returns it (WA-6 pgTAP shape).
Map<String, Object?> committedUsagePayload({
  String id = '33000000-0000-4000-8000-000000000001',
  String operationId = '32000000-0000-4000-8000-000000000001',
  bool retained = true,
}) => {
  'usageId': id,
  'userId': usageUserId,
  'email': 'wa6-pro@example.invalid',
  'entitlementId': usageEntitlementId,
  'usageType': 'final_makeup_preview',
  'operationId': operationId,
  'status': 'committed',
  'planCode': 'pro',
  'allowanceUnit': 'ai_look',
  'allowanceSource': 'subscription',
  'sourceMode': 'standard',
  'canonicalPreviewRetained': retained,
  'periodStart': '2026-09-21T00:00:00+00:00',
  'periodEnd': '2026-10-21T00:00:00+00:00',
  'reservedAt': '2026-09-22T01:00:00+00:00',
  'committedAt': '2026-09-22T01:00:04+00:00',
  'releasedAt': null,
  'sanitizedFailureCode': null,
  'createdAt': '2026-09-22T01:00:00+00:00',
  'updatedAt': '2026-09-22T01:00:04+00:00',
};

Map<String, Object?> releasedUsagePayload({
  String id = '33000000-0000-4000-8000-000000000004',
  String operationId = '32000000-0000-4000-8000-000000000004',
  String failureCode = 'GEN_FAILED',
}) => {
  ...committedUsagePayload(id: id, operationId: operationId),
  'status': 'released',
  'sourceMode': null,
  'canonicalPreviewRetained': null,
  'committedAt': null,
  'releasedAt': '2026-09-22T01:00:09+00:00',
  'sanitizedFailureCode': failureCode,
};

Map<String, Object?> reservedUsagePayload({
  String id = '33000000-0000-4000-8000-000000000003',
  String operationId = '32000000-0000-4000-8000-000000000003',
}) => {
  ...committedUsagePayload(id: id, operationId: operationId),
  'status': 'reserved',
  'sourceMode': null,
  'canonicalPreviewRetained': null,
  'committedAt': null,
  'releasedAt': null,
  'sanitizedFailureCode': null,
};

Map<String, Object?> usagePagePayload({
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'pageSize': 25,
  'sort': {'field': 'createdAt', 'direction': 'desc'},
  'filters': {
    'userId': null,
    'entitlementId': null,
    'status': null,
    'planCode': null,
    'allowanceSource': null,
    'from': null,
    'to': null,
  },
  'items':
      items ??
      [committedUsagePayload(), reservedUsagePayload(), releasedUsagePayload()],
  'nextCursor': nextCursor,
};

void main() {
  group('AdminUsageListItem.decode', () {
    test('maps the three canonical states and nothing else', () {
      expect(
        AdminUsageListItem.decode(committedUsagePayload()).status,
        UsageStatus.committed,
      );
      expect(
        AdminUsageListItem.decode(reservedUsagePayload()).status,
        UsageStatus.reserved,
      );
      expect(
        AdminUsageListItem.decode(releasedUsagePayload()).status,
        UsageStatus.released,
      );
      for (final invented in ['spent', 'used_up', 'failed_charge', 'done']) {
        expect(
          () => AdminUsageListItem.decode({
            ...reservedUsagePayload(),
            'status': invented,
          }),
          throwsA(isA<AdminReadFailure>()),
          reason: invented,
        );
      }
    });

    test('a released failure is distinguishable from a committed success', () {
      final committed = AdminUsageListItem.decode(committedUsagePayload());
      final released = AdminUsageListItem.decode(releasedUsagePayload());

      expect(committed.committedAt, isNotNull);
      expect(committed.releasedAt, isNull);
      expect(committed.sanitizedFailureCode, isNull);
      expect(committed.sourceMode, AdminPreviewSourceMode.standard);
      expect(committed.canonicalPreviewRetained, isTrue);

      expect(released.committedAt, isNull);
      expect(released.releasedAt, isNotNull);
      expect(released.sanitizedFailureCode, 'GEN_FAILED');
      expect(released.sourceMode, isNull);
      expect(released.canonicalPreviewRetained, isNull);
    });

    test('rows that break the ledger invariants are refused', () {
      for (final broken in [
        // committed without a commit time
        {...committedUsagePayload(), 'committedAt': null},
        // committed carrying a failure code
        {...committedUsagePayload(), 'sanitizedFailureCode': 'GEN_FAILED'},
        // released without a release time
        {...releasedUsagePayload(), 'releasedAt': null},
        // reserved with a commit time
        {...reservedUsagePayload(), 'committedAt': '2026-09-22T01:00:04Z'},
      ]) {
        expect(
          () => AdminUsageListItem.decode(broken),
          throwsA(isA<AdminReadFailure>()),
          reason: broken.toString(),
        );
      }
    });

    test('carries stamped provenance and the discriminated lineage', () {
      final row = AdminUsageListItem.decode({
        ...committedUsagePayload(retained: false),
        'planCode': 'plus_preview',
        'allowanceUnit': 'final_preview_credit',
        'allowanceSource': 'purchased_credit',
        'sourceMode': 'makeup_kit',
      });
      expect(row.usageType, UsageType.finalMakeupPreview);
      expect(row.planCode, SubscriptionPlanCode.plusPreview);
      expect(row.allowanceSource, AllowanceSource.purchasedCredit);
      expect(row.sourceMode, AdminPreviewSourceMode.makeupKit);
      expect(row.canonicalPreviewRetained, isFalse);
    });

    test('unknown provenance vocabulary fails closed', () {
      for (final broken in [
        {...committedUsagePayload(), 'allowanceSource': 'gift'},
        {...committedUsagePayload(), 'sourceMode': 'tutorial'},
        {...committedUsagePayload(), 'usageType': 'tutorial_step'},
        {...committedUsagePayload(), 'planCode': 'premium'},
      ]) {
        expect(
          () => AdminUsageListItem.decode(broken),
          throwsA(isA<AdminReadFailure>()),
          reason: broken.toString(),
        );
      }
    });

    test('no image identifier is part of the row', () {
      final keys = committedUsagePayload().keys.join(' ').toLowerCase();
      expect(keys, isNot(contains('image')));
      expect(keys, isNot(contains('storage')));
      expect(keys, isNot(contains('url')));
      expect(keys, isNot(contains('prompt')));
    });
  });

  group('AdminUsageFilters', () {
    test('resolves a date range to one fixed instant when applied', () {
      final now = DateTime.utc(2026, 9, 22, 12);
      final filters = AdminUsageFilters.withRange(
        const AdminUsageFilters(
          userId: usageUserId,
          status: UsageStatus.released,
          allowanceSource: AllowanceSource.subscription,
        ),
        AdminUsageDateRange.last7Days,
        now: now,
      );
      expect(filters.fromInclusive, DateTime.utc(2026, 9, 15, 12));
      expect(filters.toRpcParams(), {
        'p_user_id': usageUserId,
        'p_entitlement_id': null,
        'p_status': 'released',
        'p_plan_code': null,
        'p_allowance_source': 'subscription',
        'p_from': '2026-09-15T12:00:00.000Z',
        'p_to': null,
      });
      // The same filters produce the same parameters on every page.
      expect(filters.toRpcParams(), filters.toRpcParams());
      expect(
        filters,
        AdminUsageFilters.withRange(
          const AdminUsageFilters(
            userId: usageUserId,
            status: UsageStatus.released,
            allowanceSource: AllowanceSource.subscription,
          ),
          AdminUsageDateRange.last7Days,
          now: now,
        ),
      );
    });

    test('a page envelope decodes with its cursor', () {
      final page = AdminUsageListItem.decodePage(
        usagePagePayload(nextCursor: 'c2'),
      );
      expect(page.items.map((r) => r.status), [
        UsageStatus.committed,
        UsageStatus.reserved,
        UsageStatus.released,
      ]);
      expect(page.nextCursor, 'c2');
    });
  });
}
