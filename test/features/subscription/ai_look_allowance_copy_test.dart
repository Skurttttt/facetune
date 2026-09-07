import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_state.dart';
import 'package:facetune/features/subscription/presentation/utils/ai_look_allowance_copy.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// All dates come from the server, so the fixtures supply them explicitly.
SubscriptionSummary summary({
  required SubscriptionPlanCode plan,
  required String displayName,
  required int allowance,
  int committed = 0,
  int reserved = 0,
  EntitlementStatus status = EntitlementStatus.active,
  ResetPolicy resetPolicy = ResetPolicy.billingPeriod,
  BillingProvider provider = BillingProvider.googlePlay,
  DateTime? resetAt,
  DateTime? expiresAt,
  bool hasEntitlement = true,
}) => SubscriptionSummary(
  hasEntitlement: hasEntitlement,
  planCode: plan,
  planDisplayName: displayName,
  usage: SubscriptionUsageSummary(
    effectiveAllowance: allowance,
    committedUsage: committed,
    reservedUsage: reserved,
  ),
  generationAuthorized:
      status == EntitlementStatus.active &&
      allowance - committed - reserved > 0,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: status,
  billingProvider: provider,
  resetPolicy: resetPolicy,
  resetAt: resetAt,
  expiresAt: expiresAt,
);

SubscriptionSummary plus({int committed = 0}) => summary(
  plan: SubscriptionPlanCode.plus,
  displayName: 'FaceTune Plus',
  allowance: 3,
  committed: committed,
  resetAt: DateTime.utc(2026, 10, 7),
);

SubscriptionSummary free({int committed = 0}) => summary(
  plan: SubscriptionPlanCode.free,
  displayName: 'FaceTune Free',
  allowance: 1,
  committed: committed,
  resetPolicy: ResetPolicy.none,
  provider: BillingProvider.none,
);

SubscriptionSummary salonPilot({int committed = 0, int allowance = 30}) =>
    summary(
      plan: SubscriptionPlanCode.salonPilot,
      displayName: 'Salon Pilot',
      allowance: allowance,
      committed: committed,
      resetPolicy: ResetPolicy.none,
      provider: BillingProvider.adminGranted,
      expiresAt: DateTime.utc(2026, 11, 7),
    );

void main() {
  group('Free', () {
    test('unused reads as one complimentary look', () {
      final copy = AiLookAllowanceCopy.forSummary(free());
      expect(copy.planName, 'FaceTune Free');
      expect(copy.remainingLine, '1 of 1 complimentary AI Look remaining');
      expect(copy.compactLine, '1 AI Look remaining');
      expect(copy.renewalLine, isNull, reason: 'Free never resets or expires');
      expect(copy.headline, isNull);
    });

    test('exhausted offers the upgrade, and says nothing about resetting', () {
      final copy = AiLookAllowanceCopy.forSummary(free(committed: 1));
      expect(copy.remainingLine, '0 of 1 complimentary AI Look remaining');
      expect(copy.headline, 'You have used your complimentary AI Look');
      expect(copy.detail, 'Upgrade to create more AI Looks.');
      expect(copy.upgradePrompt, isTrue);
      expect(copy.renewalLine, isNull);
      expect(copy.tone, AppTone.warning);
    });
  });

  group('recurring plans', () {
    test('Plus normal reads with the month scope and its reset date', () {
      final copy = AiLookAllowanceCopy.forSummary(plus(committed: 1));
      expect(copy.remainingLine, '2 of 3 AI Looks remaining');
      expect(copy.compactLine, '2 AI Looks remaining this month');
      expect(copy.renewalLine, 'Resets Oct 7');
      expect(copy.tone, AppTone.info);
      expect(copy.upgradePrompt, isFalse);
    });

    test('one remaining is singular and emphasised', () {
      final copy = AiLookAllowanceCopy.forSummary(plus(committed: 2));
      expect(copy.remainingLine, '1 of 3 AI Looks remaining');
      expect(copy.compactLine, '1 AI Look remaining this month');
      expect(copy.tone, AppTone.warning);
    });

    test('zero states the verified reset date, not a computed one', () {
      final copy = AiLookAllowanceCopy.forSummary(plus(committed: 3));
      expect(copy.remainingLine, '0 of 3 AI Looks remaining');
      expect(copy.headline, 'You have used all your AI Looks');
      expect(copy.detail, 'Your allowance resets on Oct 7.');
      // A recurring plan replenishes; it must not be sold an upgrade as if it
      // were exhausted Free.
      expect(copy.upgradePrompt, isFalse);
    });

    test('Pro carries its own allowance', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.pro,
          displayName: 'FaceTune Pro',
          allowance: 8,
          committed: 3,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(copy.remainingLine, '5 of 8 AI Looks remaining');
      expect(copy.compactLine, '5 AI Looks remaining this month');
    });

    test('Salon Pro carries its own allowance', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.salonPro,
          displayName: 'Salon Pro',
          allowance: 35,
          committed: 7,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(copy.planName, 'Salon Pro');
      expect(copy.remainingLine, '28 of 35 AI Looks remaining');
    });

    test('a missing reset date degrades gracefully', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          committed: 3,
        ),
      );
      expect(copy.renewalLine, isNull);
      expect(
        copy.detail,
        'Your allowance will replenish with your next billing period.',
        reason: 'never invent a date the server did not supply',
      );
    });
  });

  group('Salon Pilot', () {
    test('active reads as research access that expires', () {
      final copy = AiLookAllowanceCopy.forSummary(salonPilot(committed: 11));
      expect(copy.planName, 'Salon Pilot');
      expect(copy.planQualifier, 'Research Access');
      expect(copy.remainingLine, '19 of 30 AI Looks remaining');
      expect(copy.renewalLine, 'Expires Nov 7');
      // Not a recurring plan, so no month scope.
      expect(copy.compactLine, '19 AI Looks remaining');
    });

    test('an adjusted grant reports its effective allowance', () {
      final copy = AiLookAllowanceCopy.forSummary(
        salonPilot(allowance: 40, committed: 40),
      );
      expect(copy.remainingLine, '0 of 40 AI Looks remaining');
      expect(copy.headline, 'Salon Pilot allowance used');
    });

    test('exhausted never shows a store purchase prompt', () {
      final copy = AiLookAllowanceCopy.forSummary(salonPilot(committed: 30));
      expect(copy.headline, 'Salon Pilot allowance used');
      expect(
        copy.upgradePrompt,
        isFalse,
        reason: 'Salon Pilot is admin granted, not a store product',
      );
      expect(copy.detail, isNot(contains('Upgrade')));
      expect(copy.detail, contains('Contact the FaceTune team'));
    });

    test('expired reports the lapse, not an exhausted allowance', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.salonPilot,
          displayName: 'Salon Pilot',
          allowance: 30,
          committed: 5,
          status: EntitlementStatus.expired,
          resetPolicy: ResetPolicy.none,
          provider: BillingProvider.adminGranted,
          expiresAt: DateTime.utc(2026, 8, 1),
        ),
      );
      // Capacity remains, but access does not — saying "you ran out" would be
      // wrong and would point at the wrong remedy.
      expect(copy.remainingLine, '25 of 30 AI Looks remaining');
      expect(copy.headline, 'Your subscription has ended');
      expect(copy.upgradePrompt, isFalse);
    });
  });

  group('blocked entitlements outrank the count', () {
    test('suspended', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.pro,
          displayName: 'FaceTune Pro',
          allowance: 8,
          status: EntitlementStatus.suspended,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(copy.headline, 'Your subscription is suspended');
      expect(copy.compactLine, 'Your subscription is suspended');
      expect(copy.upgradePrompt, isFalse);
    });

    test('revoked', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.pro,
          displayName: 'FaceTune Pro',
          allowance: 8,
          status: EntitlementStatus.revoked,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(copy.headline, 'Your subscription is no longer active');
    });

    test('pending', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          status: EntitlementStatus.pending,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
      );
      expect(copy.headline, 'Your subscription is being confirmed');
    });
  });

  group('reset versus expiration wording', () {
    test('a recurring plan resets and never expires', () {
      final copy = AiLookAllowanceCopy.forSummary(plus());
      expect(copy.renewalLine, startsWith('Resets'));
      expect(copy.renewalLine, isNot(contains('Expires')));
    });

    test('an admin grant expires and never resets', () {
      final copy = AiLookAllowanceCopy.forSummary(salonPilot());
      expect(copy.renewalLine, startsWith('Expires'));
      expect(copy.renewalLine, isNot(contains('Resets')));
    });

    test('a date in another year carries the year', () {
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          resetAt: DateTime.utc(2027, 1, 4),
        ),
      );
      // Compared against the server's own resolvedAt year, never the device
      // clock.
      expect(copy.renewalLine, 'Resets Jan 4, 2027');
    });

    test('the date is rendered in UTC, matching what the server billed', () {
      // 23:30 UTC would be the next day in some device timezones. The billing
      // calendar is the server's, so the label must not drift with the device.
      final copy = AiLookAllowanceCopy.forSummary(
        summary(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          resetAt: DateTime.utc(2026, 10, 7, 23, 30),
        ),
      );
      expect(copy.renewalLine, 'Resets Oct 7');
    });
  });

  group('nothing is invented when the server has not answered', () {
    test('loading shows no quota', () {
      expect(
        AiLookAllowanceCopy.forState(
          const SubscriptionState(status: SubscriptionStatus.loading),
        ),
        isNull,
      );
    });

    test('initial shows no quota', () {
      expect(AiLookAllowanceCopy.forState(const SubscriptionState()), isNull);
    });

    test('a failure with nothing cached shows no quota', () {
      expect(
        AiLookAllowanceCopy.forState(
          const SubscriptionState(
            status: SubscriptionStatus.failure,
            message: 'offline',
            failureKind: SubscriptionStateFailureKind.offline,
          ),
        ),
        isNull,
      );
    });

    test('signed out shows no quota even if a summary lingers', () {
      expect(
        AiLookAllowanceCopy.forState(
          SubscriptionState(
            status: SubscriptionStatus.signedOut,
            summary: plus(),
          ),
        ),
        isNull,
      );
    });

    test('an unprovisioned account shows no quota', () {
      expect(
        AiLookAllowanceCopy.forState(
          SubscriptionState(
            status: SubscriptionStatus.ready,
            summary: summary(
              plan: SubscriptionPlanCode.free,
              displayName: 'FaceTune Free',
              allowance: 0,
              hasEntitlement: false,
              resetPolicy: ResetPolicy.none,
              provider: BillingProvider.none,
            ),
          ),
        ),
        isNull,
        reason: 'no entitlement is not the same as a Free grant',
      );
    });

    test(
      'a failure with a cached summary still shows the last known answer',
      () {
        final copy = AiLookAllowanceCopy.forState(
          SubscriptionState(
            status: SubscriptionStatus.failure,
            summary: plus(committed: 1),
            message: 'offline',
            failureKind: SubscriptionStateFailureKind.offline,
          ),
        );
        expect(copy, isNotNull);
        expect(copy!.remainingLine, '2 of 3 AI Looks remaining');
      },
    );
  });

  group('no internal identifiers ever reach the copy', () {
    test('nothing carries an operation, entitlement, or preview id', () {
      final copy = AiLookAllowanceCopy.forSummary(plus(committed: 1));
      final rendered = [
        copy.planName,
        copy.planQualifier,
        copy.remainingLine,
        copy.renewalLine,
        copy.headline,
        copy.detail,
        copy.compactLine,
      ].whereType<String>().join(' ');

      for (final leak in ['operation', 'entitlement_id', 'uuid', '-4', 'id=']) {
        expect(rendered.toLowerCase(), isNot(contains(leak)));
      }
    });
  });
}
