import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_v2_metrics.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> dashboardV2Payload({
  Map<String, Object?> overrides = const {},
  List<Object?>? daily,
  List<Object?>? plans,
}) {
  final start = DateTime.utc(2026, 8, 24);
  return {
    'ok': true,
    'contractVersion': 'admin_dashboard_v2_contract_v1',
    'asOf': '2026-09-22T10:15:00Z',
    'reportingTimezone': 'UTC',
    'todayStartsAt': '2026-09-22T00:00:00Z',
    'window30dStart': '2026-08-24T00:00:00Z',
    'window30dEnd': '2026-09-23T00:00:00Z',
    'committedDaily':
        daily ??
        [
          for (var index = 0; index < 30; index++)
            {
              'day': _date(
                DateTime.utc(start.year, start.month, start.day + index),
              ),
              'aiLook': index,
              'finalPreviewCredit': index == 29 ? 9 : 0,
              'unattributed': 0,
            },
        ],
    'finalPreviewsByPlan30d':
        plans ??
        [
          for (
            var index = 0;
            index < SubscriptionPlanCode.values.length;
            index++
          )
            {
              'planCode': SubscriptionPlanCode.values[index].code,
              'delivered': index,
            },
        ],
    'finalPreviewsUnattributed30d': 3,
    'committedTodayByUnit': {
      'aiLook': 7,
      'finalPreviewCredit': 9,
      'unattributed': 2,
    },
    'entitlementStatusDistribution': {
      'total': 13,
      'byStoredStatus': {
        'pending': 1,
        'active': 7,
        'grace_period': 1,
        'expired': 1,
        'suspended': 2,
        'revoked': 1,
      },
      'byEffectiveStatus': {
        'pending': 1,
        'active': 6,
        'grace_period': 1,
        'expired': 2,
        'suspended': 2,
        'revoked': 1,
      },
    },
    ...overrides,
  };
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

Matcher malformedV2() => throwsA(
  isA<AdminAuthFailure>().having(
    (failure) => failure.code,
    'code',
    SubscriptionErrorCode.temporaryBackendFailure,
  ),
);

void main() {
  group('AdminDashboardV2Metrics.decode', () {
    test('accepts the exact V2 contract and 30 authoritative daily points', () {
      final metrics = AdminDashboardV2Metrics.decode(dashboardV2Payload());
      expect(metrics.reportingTimezone, 'UTC');
      expect(metrics.committedDaily, hasLength(30));
      expect(metrics.committedDaily.first.day, DateTime.utc(2026, 8, 24));
      expect(metrics.committedDaily.last.day, DateTime.utc(2026, 9, 22));
      expect(metrics.committedDaily.last.aiLook, 29);
      expect(metrics.committedTodayByUnit.aiLook, 7);
      expect(metrics.committedTodayByUnit.finalPreviewCredit, 9);
      expect(metrics.finalPreviewsByPlan30d, hasLength(8));
      expect(metrics.finalPreviewsUnattributed30d, 3);
      expect(
        metrics
            .entitlementStatusDistribution
            .byEffectiveStatus[EntitlementStatus.expired],
        2,
      );
    });

    test(
      'fails closed on an unknown contract version or reporting timezone',
      () {
        expect(
          () => AdminDashboardV2Metrics.decode(
            dashboardV2Payload(overrides: {'contractVersion': 'v2-ish'}),
          ),
          malformedV2(),
        );
        expect(
          () => AdminDashboardV2Metrics.decode(
            dashboardV2Payload(overrides: {'reportingTimezone': 'local'}),
          ),
          malformedV2(),
        );
      },
    );

    test(
      'rejects missing, extra, duplicated, or nonconsecutive daily points',
      () {
        final valid = dashboardV2Payload()['committedDaily']! as List<Object?>;
        for (final bad in <List<Object?>>[
          valid.take(29).toList(),
          [...valid, valid.last],
          [valid[1], valid[0], ...valid.skip(2)],
          [valid.first, valid.first, ...valid.skip(2)],
        ]) {
          expect(
            () =>
                AdminDashboardV2Metrics.decode(dashboardV2Payload(daily: bad)),
            malformedV2(),
          );
        }
      },
    );

    test('requires all eight canonical plans exactly once', () {
      final valid =
          dashboardV2Payload()['finalPreviewsByPlan30d']! as List<Object?>;
      expect(
        () => AdminDashboardV2Metrics.decode(
          dashboardV2Payload(plans: valid.take(7).toList()),
        ),
        malformedV2(),
      );
      expect(
        () => AdminDashboardV2Metrics.decode(
          dashboardV2Payload(
            plans: [valid.first, valid.first, ...valid.skip(2)],
          ),
        ),
        malformedV2(),
      );
    });

    test('accepts an all-zero plan distribution safely', () {
      final metrics = AdminDashboardV2Metrics.decode(
        dashboardV2Payload(
          plans: [
            for (final plan in SubscriptionPlanCode.values)
              {'planCode': plan.code, 'delivered': 0},
          ],
        ),
      );
      expect(
        metrics.finalPreviewsByPlan30d.values.every((count) => count == 0),
        isTrue,
      );
    });

    test(
      'requires both status category sums to match the authoritative total',
      () {
        final status = Map<String, Object?>.from(
          dashboardV2Payload()['entitlementStatusDistribution']! as Map,
        );
        status['total'] = 99;
        expect(
          () => AdminDashboardV2Metrics.decode(
            dashboardV2Payload(
              overrides: {'entitlementStatusDistribution': status},
            ),
          ),
          malformedV2(),
        );
      },
    );

    test('maps authorization refusals without accepting attached metrics', () {
      expect(
        () => AdminDashboardV2Metrics.decode({
          ...dashboardV2Payload(),
          'ok': false,
          'errorCode': 'ADMIN_UNAUTHORIZED',
        }),
        throwsA(
          isA<AdminAuthFailure>().having(
            (failure) => failure.code,
            'code',
            SubscriptionErrorCode.adminUnauthorized,
          ),
        ),
      );
    });
  });
}
