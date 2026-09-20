import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/plan_price.dart';
import 'package:facetune/features/subscription/domain/entities/purchased_credit_summary.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/entities/top_up_pack.dart';
import 'package:facetune/features/subscription/domain/repositories/plan_price_source.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/domain/repositories/top_up_price_source.dart';
import 'package:facetune/features/subscription/presentation/controllers/paywall_controller.dart';
import 'package:facetune/features/subscription/presentation/pages/subscription_page.dart';
import 'package:facetune/features/subscription/presentation/widgets/top_up_pack_card.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

/// SUB-13B — where the paywall offers top-up packs, and to whom.
///
/// Packs are offered only to an account the server says may spend them, and
/// only the packs its plan can spend. Free and Salon Pilot never see one.
/// Nothing here grants: the page only asks the store to open a sheet.
SubscriptionSummary summary({
  required SubscriptionPlanCode plan,
  required bool tutorialEnabled,
  required PurchasedCreditSummary credits,
  BillingProvider provider = BillingProvider.googlePlay,
}) => SubscriptionSummary(
  hasEntitlement: true,
  planCode: plan,
  planDisplayName: 'Plan',
  usage: const SubscriptionUsageSummary(
    effectiveAllowance: 3,
    committedUsage: 0,
  ),
  generationAuthorized: true,
  resolvedAt: DateTime.utc(2026, 9, 20, 12),
  status: EntitlementStatus.active,
  billingProvider: provider,
  resetPolicy: ResetPolicy.billingPeriod,
  allowanceUnit: tutorialEnabled
      ? AllowanceUnit.aiLook
      : AllowanceUnit.finalPreviewCredit,
  tutorialEnabled: tutorialEnabled,
  purchasedCredits: credits,
);

const usable = PurchasedCreditSummary(
  tutorialCapableRemaining: 1,
  previewOnlyRemaining: 10,
  usable: true,
  availableCompatible: 11,
);

class _Subscriptions implements SubscriptionRepository {
  _Subscriptions(this.value);
  final SubscriptionSummary value;
  @override
  Future<SubscriptionSummary> resolve() async => value;
}

class _NoPlanPrices implements PlanPriceSource {
  @override
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices() async => const {};
}

class PackPrices implements TopUpPriceSource {
  PackPrices(this.prices);
  final Map<TopUpPack, PlanPrice> prices;
  int loads = 0;
  @override
  Future<Map<TopUpPack, PlanPrice>> loadPrices() async {
    loads++;
    return prices;
  }
}

const price = PlanPrice(formattedPrice: 'PHP 149.00', currencyCode: 'PHP');

Future<PackPrices> pump(
  WidgetTester tester,
  SubscriptionSummary value, {
  bool purchaseAvailable = true,
  Map<TopUpPack, PlanPrice> packPrices = const {
    TopUpPack.extraAiLook: price,
    TopUpPack.previewBoost: price,
  },
}) async {
  final auth = FakeAuthRepository(
    user: const AuthUser(
      id: 'registered-user',
      email: 'mia@example.com',
      displayName: 'Mia Chen',
      isAnonymous: false,
    ),
  );
  addTearDown(auth.dispose);
  tester.view.physicalSize = const Size(393, 7000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prices = PackPrices(packPrices);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(_Subscriptions(value)),
        planPriceSourceProvider.overrideWithValue(_NoPlanPrices()),
        topUpPriceSourceProvider.overrideWithValue(prices),
        purchaseAvailableProvider.overrideWithValue(purchaseAvailable),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SubscriptionPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prices;
}

void main() {
  testWidgets('a Tutorial plan is offered Extra AI Look only, with its price', (
    tester,
  ) async {
    final prices = await pump(
      tester,
      summary(
        plan: SubscriptionPlanCode.plus,
        tutorialEnabled: true,
        credits: usable,
      ),
    );

    expect(
      find.byKey(const ValueKey('paywall-top-up-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('top-up-card-extra_ai_look')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('top-up-card-preview_boost')),
      findsNothing,
      reason: 'Preview Boost is sold to Preview-only plans only',
    );
    expect(find.text('PHP 149.00'), findsOneWidget);
    // Scoped to the cards: the plan cards say similar things about plans.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('top-up-card-extra_ai_look')),
        matching: find.text('Includes the Step-by-Step Tutorial'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Plus 1 purchased AI Look and 10 purchased Final Preview Credits',
      ),
      findsOneWidget,
    );
    expect(prices.loads, 1);
  });

  testWidgets('a Preview-only plan is offered Preview Boost only', (
    tester,
  ) async {
    await pump(
      tester,
      summary(
        plan: SubscriptionPlanCode.plusPreview,
        tutorialEnabled: false,
        credits: usable,
      ),
    );

    expect(
      find.byKey(const ValueKey('top-up-card-preview_boost')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('top-up-card-extra_ai_look')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('top-up-card-preview_boost')),
        matching: find.text('Final Previews only — no Tutorial'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'every paid plan is offered exactly one pack, and only paid plans',
    (tester) async {
      for (final plan in SubscriptionPlanCode.values) {
        final offered = TopUpPack.values.where(
          (pack) => pack.isOfferedTo(plan),
        );
        switch (plan) {
          case SubscriptionPlanCode.plus:
          case SubscriptionPlanCode.pro:
          case SubscriptionPlanCode.salonPro:
            expect(offered, [TopUpPack.extraAiLook], reason: plan.code);
          case SubscriptionPlanCode.plusPreview:
          case SubscriptionPlanCode.proPreview:
          case SubscriptionPlanCode.salonPreview:
            expect(offered, [TopUpPack.previewBoost], reason: plan.code);
          case SubscriptionPlanCode.free:
          case SubscriptionPlanCode.salonPilot:
            expect(offered, isEmpty, reason: plan.code);
        }
      }
    },
  );

  testWidgets('Free sees no pack and never queries pack prices', (
    tester,
  ) async {
    final prices = await pump(
      tester,
      summary(
        plan: SubscriptionPlanCode.free,
        tutorialEnabled: true,
        provider: BillingProvider.none,
        credits: const PurchasedCreditSummary(
          tutorialCapableRemaining: 0,
          previewOnlyRemaining: 0,
          usable: false,
          availableCompatible: 0,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('paywall-top-up-section')), findsNothing);
    expect(find.byType(TopUpPackCard), findsNothing);
    expect(prices.loads, 0);
  });

  testWidgets('Salon Pilot sees no pack', (tester) async {
    await pump(
      tester,
      summary(
        plan: SubscriptionPlanCode.salonPilot,
        tutorialEnabled: true,
        provider: BillingProvider.adminGranted,
        credits: const PurchasedCreditSummary(
          tutorialCapableRemaining: 0,
          previewOnlyRemaining: 0,
          usable: false,
          availableCompatible: 0,
        ),
      ),
    );

    expect(find.byType(TopUpPackCard), findsNothing);
  });

  testWidgets(
    'a lapsed plan keeps its stored credits visible but sells nothing',
    (tester) async {
      await pump(
        tester,
        summary(
          plan: SubscriptionPlanCode.free,
          tutorialEnabled: true,
          provider: BillingProvider.none,
          credits: const PurchasedCreditSummary(
            tutorialCapableRemaining: 0,
            previewOnlyRemaining: 9,
            usable: false,
            availableCompatible: 0,
          ),
        ),
      );

      expect(find.byType(TopUpPackCard), findsNothing);
      // The Profile card, not the paywall, carries the "kept for you" line;
      // the paywall simply does not offer a pack the account cannot spend.
      expect(
        find.byKey(const ValueKey('paywall-purchased-credits')),
        findsNothing,
      );
    },
  );

  testWidgets('a pack with no store price cannot be tapped', (tester) async {
    await pump(
      tester,
      summary(
        plan: SubscriptionPlanCode.pro,
        tutorialEnabled: true,
        credits: usable,
      ),
      // The store returned no price for the pack this plan is offered.
      packPrices: const {TopUpPack.previewBoost: price},
    );

    final extra = tester.widget<SecondaryButton>(
      find.byKey(const ValueKey('top-up-action-extra_ai_look')),
    );
    expect(extra.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byType(TopUpPackCard),
        matching: find.text(TopUpPackCard.priceFallback),
      ),
      findsOneWidget,
    );
  });
}
