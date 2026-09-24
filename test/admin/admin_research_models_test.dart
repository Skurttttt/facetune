import 'package:facetune/admin/research/domain/admin_research_models.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// The aggregate exactly as `admin_salon_pilot_research_metrics` returns it
/// for the WA-13 pgTAP fixture (two pilots, 40 committed, 31 attempts …).
Map<String, Object?> researchPayload({
  Map<String, Object?> overrides = const {},
  Map<String, Object?>? cost,
}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'asOf': '2026-09-22T10:15:00+00:00',
  'pilots': {
    'users': 2,
    'entitlements': 2,
    'inForce': 2,
    'suspended': 0,
    'lapsedOrExpired': 0,
    'revoked': 0,
    'expiringWithin14Days': 1,
  },
  'aiLooks': {
    'grantedBase': 40,
    'adminAdjustmentsTotal': 10,
    'effectiveAllowance': 50,
    'committed': 31,
    'reserved': 1,
    'released': 3,
    'remaining': 19,
  },
  'operations': {
    'finalPreview': {'succeeded': 31, 'failed': 3, 'denied': 0, 'duplicate': 0},
    'tutorialManifest': {
      'succeeded': 2,
      'failed': 1,
      'denied': 0,
      'duplicate': 0,
    },
    'tutorialStep': {'succeeded': 0, 'failed': 0, 'denied': 0, 'duplicate': 0},
    'telemetryEvents': 37,
  },
  'billableUsage': {
    'providerAttempts': 41,
    'inputTokens': 27000,
    'outputTokens': 3200,
    'totalTokens': 30200,
    'cachedTokens': 0,
    'thoughtsTokens': 0,
    'inputImageTokens': 24000,
    'outputImageTokens': 2700,
    'outputImages': 31,
    'eventsWithTokenData': 33,
    'eventsWithoutTokenData': 4,
  },
  'cost':
      cost ??
      {
        'available': false,
        'reason': 'NO_PROVIDER_COST_DATA',
        'currency': null,
        'totalBillableCost': null,
        'effectiveCostPerDeliveredAiLook': null,
      },
  ...overrides,
};

Map<String, Object?> pilotRow({
  String id = '31000000-0000-4000-8000-000000000001',
  String userId = '20000000-0000-4000-8000-000000000001',
  String? email = 'pilot@example.invalid',
  String storedStatus = 'active',
  String effectiveStatus = 'active',
  Map<String, Object?> overrides = const {},
}) => {
  'entitlementId': id,
  'userId': userId,
  'email': email,
  'storedStatus': storedStatus,
  'effectiveStatus': effectiveStatus,
  'initialAllowance': 30,
  'adminAdjustmentsTotal': 10,
  'effectiveAllowance': 40,
  'committed': 27,
  'reserved': 0,
  'remaining': 13,
  'available': 13,
  'deliveredFinalPreviews': 27,
  'releasedOperations': 3,
  'finalPreviewFailures': 3,
  'tutorialOperations': 3,
  'tutorialFailures': 1,
  'providerAttempts': 37,
  'totalTokens': 28200,
  'outputImages': 27,
  'startsAt': '2026-09-01T00:00:00+00:00',
  'expiresAt': '2026-10-01T00:00:00+00:00',
  'lastActivityAt': '2026-09-21T18:00:00+00:00',
  'createdAt': '2026-09-01T00:00:00+00:00',
  ...overrides,
};

Map<String, Object?> pilotsPayload(
  List<Map<String, Object?>> items, {
  String? nextCursor,
}) => {
  'ok': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'items': items,
  'pageSize': 25,
  'nextCursor': nextCursor,
  'sort': {'field': 'createdAt', 'direction': 'desc'},
};

void main() {
  group('AdminSalonPilotResearch', () {
    test('decodes every server figure verbatim', () {
      final r = AdminSalonPilotResearch.decode(researchPayload());
      expect(r.asOf, DateTime.utc(2026, 9, 22, 10, 15));
      expect(r.pilots.users, 2);
      expect(r.pilots.entitlements, 2);
      expect(r.pilots.expiringWithin14Days, 1);
      expect(r.aiLooks.grantedBase, 40);
      expect(r.aiLooks.adminAdjustmentsTotal, 10);
      expect(r.aiLooks.effectiveAllowance, 50);
      expect(r.aiLooks.committed, 31);
      expect(r.aiLooks.remaining, 19);
      expect(r.operations.finalPreview.succeeded, 31);
      expect(r.operations.finalPreview.failed, 3);
      expect(r.operations.tutorialManifest.succeeded, 2);
      expect(r.operations.telemetryEvents, 37);
      expect(r.billableUsage.providerAttempts, 41);
      expect(r.billableUsage.totalTokens, 30200);
      expect(r.billableUsage.outputImages, 31);
      expect(r.billableUsage.eventsWithoutTokenData, 4);
    });

    test('cost is reported as not available, with the server reason', () {
      final r = AdminSalonPilotResearch.decode(researchPayload());
      expect(r.cost.available, isFalse);
      expect(r.cost.reason, 'NO_PROVIDER_COST_DATA');
      expect(r.cost.currency, isNull);
      expect(r.cost.totalBillableCost, isNull);
      expect(r.cost.effectiveCostPerDeliveredAiLook, isNull);
    });

    test('a negative adjustment total is accepted; other counts are not', () {
      final r = AdminSalonPilotResearch.decode(
        researchPayload(
          overrides: {
            'aiLooks': {
              'grantedBase': 40,
              'adminAdjustmentsTotal': -5,
              'effectiveAllowance': 35,
              'committed': 0,
              'reserved': 0,
              'released': 0,
              'remaining': 35,
            },
          },
        ),
      );
      expect(r.aiLooks.adminAdjustmentsTotal, -5);
      expect(
        () => AdminSalonPilotResearch.decode(
          researchPayload(
            overrides: {
              'pilots': {
                'users': -1,
                'entitlements': 0,
                'inForce': 0,
                'suspended': 0,
                'lapsedOrExpired': 0,
                'revoked': 0,
                'expiringWithin14Days': 0,
              },
            },
          ),
        ),
        throwsA(isA<AdminReadFailure>()),
      );
    });

    test('an available cost must carry both figures, and vice versa', () {
      // Figures with availability: accepted.
      final r = AdminSalonPilotResearch.decode(
        researchPayload(
          cost: {
            'available': true,
            'reason': null,
            'currency': 'USD',
            'totalBillableCost': 12.5,
            'effectiveCostPerDeliveredAiLook': 0.4,
          },
        ),
      );
      expect(r.cost.available, isTrue);
      expect(r.cost.totalBillableCost, 12.5);
      // A figure the server says is not available is a shape the client
      // refuses: it will never show a number the server disowned.
      for (final bad in [
        {
          'available': false,
          'reason': 'NO_PROVIDER_COST_DATA',
          'currency': null,
          'totalBillableCost': 12.5,
          'effectiveCostPerDeliveredAiLook': null,
        },
        {
          'available': true,
          'reason': null,
          'currency': 'USD',
          'totalBillableCost': null,
          'effectiveCostPerDeliveredAiLook': null,
        },
        {
          'available': false,
          'reason': 'NO_PROVIDER_COST_DATA',
          'currency': null,
          'totalBillableCost': 'twelve',
          'effectiveCostPerDeliveredAiLook': null,
        },
        {'available': false, 'reason': null, 'currency': null},
      ]) {
        expect(
          () => AdminSalonPilotResearch.decode(researchPayload(cost: bad)),
          throwsA(isA<AdminReadFailure>()),
          reason: '$bad',
        );
      }
    });

    test('refuses a refusal envelope, wrong contract, or missing block', () {
      for (final bad in [
        {'ok': false, 'errorCode': 'ADMIN_UNAUTHORIZED'},
        researchPayload(overrides: {'contractVersion': 'v2'}),
        researchPayload(overrides: {'billableUsage': null}),
        researchPayload(overrides: {'operations': {}}),
        null,
        [],
      ]) {
        expect(
          () => AdminSalonPilotResearch.decode(bad),
          throwsA(isA<AdminReadFailure>()),
          reason: '$bad',
        );
      }
    });
  });

  group('AdminPilotMetricsRow', () {
    test('decodes a row and the page envelope', () {
      final page = AdminPilotMetricsRow.decodePage(
        pilotsPayload([pilotRow()], nextCursor: 'abc'),
      );
      expect(page.nextCursor, 'abc');
      final row = page.items.single;
      expect(row.entitlementId, '31000000-0000-4000-8000-000000000001');
      expect(row.email, 'pilot@example.invalid');
      expect(row.storedStatus, EntitlementStatus.active);
      expect(row.effectiveStatus, EntitlementStatus.active);
      expect(row.initialAllowance, 30);
      expect(row.adminAdjustmentsTotal, 10);
      expect(row.effectiveAllowance, 40);
      expect(row.committed, 27);
      expect(row.remaining, 13);
      expect(row.deliveredFinalPreviews, 27);
      expect(row.finalPreviewFailures, 3);
      expect(row.tutorialOperations, 3);
      expect(row.tutorialFailures, 1);
      expect(row.providerAttempts, 37);
      expect(row.totalTokens, 28200);
      expect(row.outputImages, 27);
      expect(row.expiresAt, DateTime.utc(2026, 10, 1));
      expect(row.lastActivityAt, DateTime.utc(2026, 9, 21, 18));
    });

    test('nullable fields must be present, and may be null', () {
      final row = AdminPilotMetricsRow.decode(
        pilotRow(
          email: null,
          overrides: {'expiresAt': null, 'lastActivityAt': null},
        ),
      );
      expect(row.email, isNull);
      expect(row.expiresAt, isNull);
      expect(row.lastActivityAt, isNull);
      final missing = pilotRow()..remove('lastActivityAt');
      expect(
        () => AdminPilotMetricsRow.decode(missing),
        throwsA(isA<AdminReadFailure>()),
      );
    });

    test('an unknown status or a negative count fails closed', () {
      expect(
        () => AdminPilotMetricsRow.decode(pilotRow(effectiveStatus: 'paused')),
        throwsA(isA<AdminReadFailure>()),
      );
      expect(
        () =>
            AdminPilotMetricsRow.decode(pilotRow(overrides: {'committed': -1})),
        throwsA(isA<AdminReadFailure>()),
      );
      expect(
        () => AdminPilotMetricsRow.decode(
          pilotRow(overrides: {'totalTokens': 1.5}),
        ),
        throwsA(isA<AdminReadFailure>()),
      );
    });

    test('the page envelope is checked: size, sort, contract', () {
      for (final bad in [
        {...pilotsPayload([]), 'pageSize': 50},
        {
          ...pilotsPayload([]),
          'sort': {'field': 'createdAt', 'direction': 'asc'},
        },
        {...pilotsPayload([]), 'contractVersion': 'other'},
        {'ok': false, 'errorCode': 'AUTH_REQUIRED'},
      ]) {
        expect(
          () => AdminPilotMetricsRow.decodePage(bad),
          throwsA(isA<AdminReadFailure>()),
          reason: '$bad',
        );
      }
    });
  });
}
