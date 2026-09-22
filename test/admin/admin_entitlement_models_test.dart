import 'package:facetune/admin/entitlements/domain/admin_entitlement_models.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

const userId = '30000000-0000-4000-8000-000000000001';
const entitlementId = '31000000-0000-4000-8000-000000000001';

/// One row exactly as `admin_list_entitlements` returns it (WA-6 pgTAP shape).
Map<String, Object?> entitlementPayload({
  String id = entitlementId,
  String plan = 'pro',
  String stored = 'active',
  String effective = 'active',
  String provider = 'google_play',
  int base = 8,
  int adjustment = 0,
  int effectiveAllowance = 8,
  int committed = 2,
  int reserved = 1,
  int available = 5,
  int remaining = 6,
  String? expiresAt,
  String? periodStart = '2026-09-21T00:00:00+00:00',
  String? periodEnd = '2026-10-21T00:00:00+00:00',
  bool autoRenew = true,
}) => {
  'entitlementId': id,
  'userId': userId,
  'email': 'wa6-pro@example.invalid',
  'planCode': plan,
  'planDisplayName': 'Pro',
  'storedStatus': stored,
  'effectiveStatus': effective,
  'billingProvider': provider,
  'allowanceUnit': 'ai_look',
  'baseAllowance': base,
  'allowanceAdjustmentTotal': adjustment,
  'effectiveAllowance': effectiveAllowance,
  'committedUsage': committed,
  'reservedUsage': reserved,
  'availableAiLooks': available,
  'remainingAiLooks': remaining,
  'periodStart': periodStart,
  'periodEnd': periodEnd,
  'startsAt': '2026-09-21T00:00:00+00:00',
  'expiresAt': expiresAt,
  'autoRenew': autoRenew,
  'version': 1,
  'createdAt': '2026-09-21T00:00:00+00:00',
  'updatedAt': '2026-09-21T00:00:00+00:00',
};

Map<String, Object?> entitlementPagePayload({
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'pageSize': 25,
  'sort': {'field': 'createdAt', 'direction': 'desc'},
  'filters': {
    'userId': null,
    'planCode': null,
    'status': null,
    'billingProvider': null,
    'expiresWithinDays': null,
  },
  'items': items ?? [entitlementPayload()],
  'nextCursor': nextCursor,
};

void main() {
  group('AdminEntitlementListItem.decode', () {
    test('copies every server figure verbatim and derives nothing', () {
      final row = AdminEntitlementListItem.decode(
        entitlementPayload(
          base: 30,
          adjustment: -5,
          effectiveAllowance: 25,
          committed: 20,
          reserved: 2,
          available: 3,
          remaining: 5,
        ),
      );
      expect(row.planCode, SubscriptionPlanCode.pro);
      expect(row.billingProvider, BillingProvider.googlePlay);
      expect(row.baseAllowance, 30);
      expect(row.allowanceAdjustmentTotal, -5);
      expect(row.effectiveAllowance, 25);
      expect(row.committedUsage, 20);
      expect(row.reservedUsage, 2);
      expect(row.availableAiLooks, 3);
      expect(row.remainingAiLooks, 5);
      expect(row.periodStart, DateTime.utc(2026, 9, 21));
      expect(row.expiresAt, isNull);
      expect(row.autoRenew, isTrue);
    });

    test('keeps stored and effective status as two distinct fields', () {
      final row = AdminEntitlementListItem.decode(
        entitlementPayload(
          plan: 'salon_pilot',
          provider: 'admin_granted',
          stored: 'active',
          effective: 'expired',
          expiresAt: '2026-09-20T00:00:00+00:00',
          periodStart: null,
          periodEnd: null,
          autoRenew: false,
        ),
      );
      expect(row.storedStatus, EntitlementStatus.active);
      expect(row.effectiveStatus, EntitlementStatus.expired);
      expect(row.planCode, SubscriptionPlanCode.salonPilot);
      expect(row.billingProvider, BillingProvider.adminGranted);
    });

    test('a value outside the contract vocabulary fails closed', () {
      for (final broken in [
        entitlementPayload(plan: 'premium'),
        entitlementPayload(effective: 'inactive'),
        entitlementPayload(provider: 'stripe'),
        {...entitlementPayload(), 'allowanceUnit': 'credits'},
        {...entitlementPayload(), 'committedUsage': -1},
        {...entitlementPayload(), 'effectiveAllowance': '8'},
        {...entitlementPayload()}..remove('expiresAt'),
      ]) {
        expect(
          () => AdminEntitlementListItem.decode(broken),
          throwsA(isA<AdminReadFailure>()),
          reason: broken.toString(),
        );
      }
    });
  });

  group('AdminEntitlementListItem.decodePage', () {
    test('accepts the fixed envelope and exposes the cursor', () {
      final page = AdminEntitlementListItem.decodePage(
        entitlementPagePayload(nextCursor: 'c2'),
      );
      expect(page.items, hasLength(1));
      expect(page.nextCursor, 'c2');
    });

    test('rejects a foreign contract version, page size, or sort', () {
      for (final broken in [
        {...entitlementPagePayload(), 'contractVersion': 'v2'},
        {...entitlementPagePayload(), 'pageSize': 100},
        {
          ...entitlementPagePayload(),
          'sort': {'field': 'remaining', 'direction': 'asc'},
        },
        {...entitlementPagePayload(), 'ok': false},
      ]) {
        expect(
          () => AdminEntitlementListItem.decodePage(broken),
          throwsA(isA<AdminReadFailure>()),
        );
      }
    });
  });

  group('AdminEntitlementFilters', () {
    test('maps to the RPC parameters with contract codes', () {
      const filters = AdminEntitlementFilters(
        userId: userId,
        planCode: SubscriptionPlanCode.salonPilot,
        status: EntitlementStatus.gracePeriod,
        billingProvider: BillingProvider.adminGranted,
        expiration: AdminExpirationWindow.within14Days,
      );
      expect(filters.toRpcParams(), {
        'p_user_id': userId,
        'p_plan_code': 'salon_pilot',
        'p_status': 'grace_period',
        'p_billing_provider': 'admin_granted',
        'p_expires_within_days': 14,
      });
      expect(AdminEntitlementFilters.none.isEmpty, isTrue);
      expect(filters.isEmpty, isFalse);
    });

    test('is value-equal so it can key a provider family', () {
      expect(
        const AdminEntitlementFilters(planCode: SubscriptionPlanCode.pro),
        const AdminEntitlementFilters(planCode: SubscriptionPlanCode.pro),
      );
      expect(
        const AdminEntitlementFilters(planCode: SubscriptionPlanCode.pro),
        isNot(
          const AdminEntitlementFilters(planCode: SubscriptionPlanCode.plus),
        ),
      );
    });
  });
}
