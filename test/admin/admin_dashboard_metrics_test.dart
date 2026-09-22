import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_metrics.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// A payload shaped exactly like `public.admin_dashboard_metrics()` returns.
Map<String, Object?> payload({
  Map<String, Object?> overrides = const {},
  Map<String, Object?>? inForceByPlan,
}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'asOf': '2026-09-22T10:15:00+00:00',
  'todayStartsAt': '2026-09-22T00:00:00+00:00',
  'monthStartsAt': '2026-09-01T00:00:00+00:00',
  'expiringSoonWindowDays': 14,
  'accounts': {'totalUsers': 13, 'anonymousGuests': 2},
  'entitlements': {
    'inForceByPlan':
        inForceByPlan ??
        {
          'free': 15,
          'plus': 3,
          'plus_preview': 1,
          'pro': 4,
          'pro_preview': 0,
          'salon_pro': 1,
          'salon_preview': 0,
          'salon_pilot': 2,
        },
    'pending': 1,
    'suspended': 0,
  },
  'aiLooks': {
    'committedToday': {'subscription': 6, 'purchasedCredit': 1},
    'committedThisMonth': {'subscription': 41, 'purchasedCredit': 3},
    'reservedOpen': 2,
    'releasedToday': 1,
    'releasedThisMonth': 5,
  },
  'salonPilot': {'inForce': 2, 'expiringSoon': 1},
  'purchasedCredits': {'activeGrants': 5},
  ...overrides,
};

Matcher failsWith(SubscriptionErrorCode code) =>
    throwsA(isA<AdminAuthFailure>().having((f) => f.code, 'code', code));

void main() {
  group('AdminDashboardMetrics.decode', () {
    test('decodes every figure verbatim', () {
      final m = AdminDashboardMetrics.decode(payload());
      expect(m.asOf, DateTime.utc(2026, 9, 22, 10, 15));
      expect(m.todayStartsAt, DateTime.utc(2026, 9, 22));
      expect(m.monthStartsAt, DateTime.utc(2026, 9, 1));
      expect(m.expiringSoonWindowDays, 14);
      expect(m.accounts.totalUsers, 13);
      expect(m.accounts.anonymousGuests, 2);
      expect(m.entitlements.inForceByPlan[SubscriptionPlanCode.free], 15);
      expect(m.entitlements.inForceByPlan[SubscriptionPlanCode.proPreview], 0);
      expect(m.entitlements.inForceByPlan.length, 8);
      expect(m.entitlements.pending, 1);
      expect(m.aiLooks.committedToday.subscription, 6);
      expect(m.aiLooks.committedToday.purchasedCredit, 1);
      expect(m.aiLooks.committedThisMonth.subscription, 41);
      expect(m.aiLooks.reservedOpen, 2);
      expect(m.aiLooks.releasedThisMonth, 5);
      expect(m.salonPilot.expiringSoon, 1);
      expect(m.purchasedCredits.activeGrants, 5);
      expect(m.isEmpty, isFalse);
    });

    test('committed figures are never summed across buckets', () {
      final m = AdminDashboardMetrics.decode(payload());
      // The entity exposes the two buckets and no total field.
      expect(m.aiLooks.committedToday.subscription, 6);
      expect(m.aiLooks.committedToday.purchasedCredit, 1);
    });

    test('an empty system decodes with zeros and is reported as empty', () {
      final m = AdminDashboardMetrics.decode(
        payload(
          overrides: {
            'accounts': {'totalUsers': 0, 'anonymousGuests': 0},
          },
          inForceByPlan: {
            for (final plan in SubscriptionPlanCode.values) plan.code: 0,
          },
        ),
      );
      expect(m.isEmpty, isTrue);
      expect(m.entitlements.inForceByPlan.values.every((v) => v == 0), isTrue);
    });

    test('a refusal becomes the typed authorization failure', () {
      expect(
        () => AdminDashboardMetrics.decode({
          'ok': false,
          'errorCode': 'ADMIN_UNAUTHORIZED',
        }),
        failsWith(SubscriptionErrorCode.adminUnauthorized),
      );
      expect(
        () => AdminDashboardMetrics.decode({
          'ok': false,
          'errorCode': 'AUTH_REQUIRED',
        }),
        failsWith(SubscriptionErrorCode.authRequired),
      );
      expect(
        () => AdminDashboardMetrics.decode({'ok': false, 'errorCode': 'WHAT'}),
        failsWith(SubscriptionErrorCode.temporaryBackendFailure),
      );
    });

    test('a refusal never carries metrics through', () {
      // Even with a full body attached, ok:false is a refusal.
      expect(
        () => AdminDashboardMetrics.decode(
          payload(overrides: {'ok': false, 'errorCode': 'ADMIN_UNAUTHORIZED'}),
        ),
        failsWith(SubscriptionErrorCode.adminUnauthorized),
      );
    });

    test('malformed payloads fail closed rather than default to zero', () {
      final bad = <Object?>[
        null,
        'ok',
        <Object?>[],
        payload(overrides: {'accounts': null}),
        payload(
          overrides: {
            'accounts': {'totalUsers': 13},
          },
        ),
        payload(
          overrides: {
            'accounts': {'totalUsers': '13', 'anonymousGuests': 0},
          },
        ),
        payload(
          overrides: {
            'accounts': {'totalUsers': -1, 'anonymousGuests': 0},
          },
        ),
        payload(
          overrides: {
            'accounts': {'totalUsers': 1.5, 'anonymousGuests': 0},
          },
        ),
        payload(overrides: {'asOf': 'yesterday'}),
        payload(
          overrides: {
            'aiLooks': {'reservedOpen': 2},
          },
        ),
      ];
      for (final p in bad) {
        expect(
          () => AdminDashboardMetrics.decode(p),
          failsWith(SubscriptionErrorCode.temporaryBackendFailure),
          reason: '$p',
        );
      }
    });

    test('plan table must be complete and canonical', () {
      // A missing plan is contract drift, not zero.
      expect(
        () => AdminDashboardMetrics.decode(
          payload(inForceByPlan: {'free': 1, 'plus': 0}),
        ),
        failsWith(SubscriptionErrorCode.temporaryBackendFailure),
      );
      // An unknown plan code is drift too.
      expect(
        () => AdminDashboardMetrics.decode(
          payload(
            inForceByPlan: {
              for (final plan in SubscriptionPlanCode.values) plan.code: 0,
              'premium': 3,
            },
          ),
        ),
        failsWith(SubscriptionErrorCode.temporaryBackendFailure),
      );
    });

    test('whole-number doubles from JSON are accepted as counts', () {
      final m = AdminDashboardMetrics.decode(
        payload(
          overrides: {
            'accounts': {'totalUsers': 13.0, 'anonymousGuests': 0.0},
          },
        ),
      );
      expect(m.accounts.totalUsers, 13);
    });
  });
}
