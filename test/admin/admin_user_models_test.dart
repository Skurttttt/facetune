import 'package:facetune/admin/users/domain/admin_account_status.dart';
import 'package:facetune/admin/users/domain/admin_user_models.dart';
import 'package:facetune/admin/users/domain/admin_users_failure.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

const userId = '20000000-0000-4000-8000-000000000001';

Map<String, Object?> summaryPayload({String id = userId}) => {
  'userId': id,
  'email': 'member@example.invalid',
  'accountCreatedAt': '2026-01-02T03:04:05Z',
  'accountStatus': 'active',
  'currentPlanCode': 'pro',
  'currentPlanDisplayName': 'Pro',
  'entitlementStatus': 'active',
  'remainingAiLooks': 8,
  'allowanceUnit': 'ai_look',
  'periodEnd': '2026-10-01T00:00:00Z',
  'expiresAt': null,
  'autoRenew': true,
};

Map<String, Object?> entitlementPayload() => {
  'entitlementId': '30000000-0000-4000-8000-000000000001',
  'planCode': 'pro',
  'planDisplayName': 'Pro',
  'storedStatus': 'active',
  'effectiveStatus': 'active',
  'billingProvider': 'google_play',
  'allowanceUnit': 'ai_look',
  'effectiveAllowance': 12,
  'committedUsage': 3,
  'reservedUsage': 1,
  'availableAiLooks': 8,
  'remainingAiLooks': 9,
  'periodStart': '2026-09-01T00:00:00Z',
  'periodEnd': '2026-10-01T00:00:00Z',
  'startsAt': '2026-09-01T00:00:00Z',
  'expiresAt': null,
  'autoRenew': true,
  'version': 4,
  'createdAt': '2026-09-01T00:00:00Z',
  'updatedAt': '2026-09-20T00:00:00Z',
};

Map<String, Object?> detailPayload() => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'user': {
    'userId': userId,
    'email': 'member@example.invalid',
    'accountCreatedAt': '2026-01-02T03:04:05Z',
    'accountStatus': 'active',
  },
  'entitlement': entitlementPayload(),
};

void main() {
  test('decodes the fixed-size sanitized summary page', () {
    final page = AdminUserPage.decode({
      'ok': true,
      'contractVersion': 'subscription_admin_contract_v1.1',
      'pageSize': 25,
      'sort': {'field': 'accountCreatedAt', 'direction': 'desc'},
      'items': [summaryPayload()],
      'nextCursor': 'opaque',
    });

    expect(page.pageSize, 25);
    expect(page.items, hasLength(1));
    expect(page.nextCursor, 'opaque');
    final user = page.items.single;
    expect(user.userId, userId);
    expect(user.accountStatus, AdminAccountStatus.active);
    expect(user.currentPlanCode, SubscriptionPlanCode.pro);
    expect(user.entitlementStatus, EntitlementStatus.active);
    expect(user.allowanceUnit, AllowanceUnit.aiLook);
    expect(user.remainingAiLooks, 8);
  });

  test('rejects a page size the server contract does not own', () {
    expect(
      () => AdminUserPage.decode({
        'ok': true,
        'contractVersion': 'subscription_admin_contract_v1.1',
        'pageSize': 5000,
        'sort': {'field': 'accountCreatedAt', 'direction': 'desc'},
        'items': [summaryPayload()],
        'nextCursor': null,
      }),
      throwsA(isA<AdminUsersFailure>()),
    );
  });

  test('rejects any client-visible sort outside the fixed server order', () {
    expect(
      () => AdminUserPage.decode({
        'ok': true,
        'contractVersion': 'subscription_admin_contract_v1.1',
        'pageSize': 25,
        'sort': {'field': 'email', 'direction': 'asc'},
        'items': [summaryPayload()],
        'nextCursor': null,
      }),
      throwsA(isA<AdminUsersFailure>()),
    );
  });

  test('decodes only subscription-relevant user detail', () {
    final detail = AdminUserDetail.decode(detailPayload());
    expect(detail.userId, userId);
    expect(detail.email, 'member@example.invalid');
    expect(detail.accountStatus, AdminAccountStatus.active);
    final entitlement = detail.entitlement!;
    expect(entitlement.planCode, SubscriptionPlanCode.pro);
    expect(entitlement.billingProvider, BillingProvider.googlePlay);
    expect(entitlement.committedUsage, 3);
    expect(entitlement.reservedUsage, 1);
    expect(entitlement.remainingAiLooks, 9);
    expect(entitlement.availableAiLooks, 8);
  });

  test('unknown authority vocabulary fails closed', () {
    final payload = detailPayload();
    final entitlement = Map<String, Object?>.from(
      payload['entitlement']! as Map<String, Object?>,
    )..['effectiveStatus'] = 'premium';
    payload['entitlement'] = entitlement;

    expect(
      () => AdminUserDetail.decode(payload),
      throwsA(isA<AdminUsersFailure>()),
    );
  });
}
