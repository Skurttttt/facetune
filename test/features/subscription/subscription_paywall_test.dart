import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/plan_price.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/repositories/plan_price_source.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/presentation/controllers/paywall_controller.dart';
import 'package:facetune/features/subscription/presentation/pages/subscription_page.dart';
import 'package:facetune/features/subscription/presentation/utils/plan_presentation.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

SubscriptionSummary summaryOn(SubscriptionPlanCode plan) => SubscriptionSummary(
  hasEntitlement: true,
  planCode: plan,
  planDisplayName: 'FaceTune Plus',
  usage: const SubscriptionUsageSummary(
    effectiveAllowance: 3,
    committedUsage: 1,
  ),
  generationAuthorized: true,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: EntitlementStatus.active,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
  resetAt: DateTime.utc(2026, 10, 7),
);

class _Subscriptions implements SubscriptionRepository {
  _Subscriptions(this.summary);
  final SubscriptionSummary? summary;

  @override
  Future<SubscriptionSummary> resolve() async {
    final value = summary;
    if (value == null) throw Exception('no subscription');
    return value;
  }
}

class _Prices implements PlanPriceSource {
  _Prices(this.prices, {this.fails = false});
  final Map<SubscriptionPlanCode, PlanPrice> prices;
  final bool fails;

  @override
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices() async {
    if (fails) throw Exception('store unreachable');
    return prices;
  }
}

Future<void> pumpPaywall(
  WidgetTester tester, {
  SubscriptionSummary? summary,
  Map<SubscriptionPlanCode, PlanPrice> prices = const {},
  bool pricesFail = false,
  bool purchaseAvailable = false,
  Size size = const Size(393, 4000),
  double textScale = 1.0,
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

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(
          _Subscriptions(summary),
        ),
        planPriceSourceProvider.overrideWithValue(
          _Prices(prices, fails: pricesFail),
        ),
        purchaseAvailableProvider.overrideWithValue(purchaseAvailable),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const SubscriptionPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('public plans', () {
    testWidgets('shows Free, Plus, Pro, and Salon Pro', (tester) async {
      await pumpPaywall(tester);

      for (final plan in [
        SubscriptionPlanCode.free,
        SubscriptionPlanCode.plus,
        SubscriptionPlanCode.pro,
        SubscriptionPlanCode.salonPro,
      ]) {
        expect(
          find.byKey(ValueKey('plan-card-${plan.code}')),
          findsOneWidget,
          reason: '${plan.code} must appear',
        );
      }
    });

    testWidgets('never shows Salon Pilot as a purchasable card', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(find.byKey(const ValueKey('plan-card-salon_pilot')), findsNothing);
      expect(find.textContaining('Salon Pilot'), findsNothing);
      expect(find.textContaining('Research Access'), findsNothing);
    });

    testWidgets('the comparison list is derived from the catalog', (
      tester,
    ) async {
      // Not a hand-written list in presentation code, so Salon Pilot cannot be
      // added to the paywall by editing a widget.
      expect(
        PlanPresentation.purchasablePlans,
        isNot(contains(SubscriptionPlanCode.salonPilot)),
      );
      expect(
        PlanPresentation.comparisonPlans,
        isNot(contains(SubscriptionPlanCode.salonPilot)),
      );
      expect(PlanPresentation.comparisonPlans, [
        SubscriptionPlanCode.free,
        SubscriptionPlanCode.plus,
        SubscriptionPlanCode.pro,
        SubscriptionPlanCode.salonPro,
      ]);
    });

    testWidgets('each plan states its allowance', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('1 one-time AI Look'), findsOneWidget);
      expect(find.text('3 AI Looks per month'), findsOneWidget);
      expect(find.text('8 AI Looks per month'), findsOneWidget);
      expect(find.text('35 AI Looks per month'), findsOneWidget);
    });

    testWidgets('Salon Pro names the makeup artist account', (tester) async {
      await pumpPaywall(tester);
      expect(find.text('1 Makeup Artist Account'), findsOneWidget);
    });
  });

  group('current plan', () {
    testWidgets('marks the account\'s plan and disables its action', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.plus),
        purchaseAvailable: true,
      );

      expect(find.byKey(const ValueKey('plan-current-plus')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-current-pro')), findsNothing);

      final current = tester.widget<SecondaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(current.onPressed, isNull, reason: 'cannot buy the current plan');
    });

    testWidgets('no plan is marked current when none is resolved', (
      tester,
    ) async {
      await pumpPaywall(tester);
      expect(find.textContaining('Current plan'), findsNothing);
    });
  });

  group('prices come only from the provider', () {
    testWidgets('renders the provider\'s localized string verbatim', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        prices: const {
          SubscriptionPlanCode.plus: PlanPrice(
            formattedPrice: 'PHP 399.00',
            currencyCode: 'PHP',
            billingPeriodLabel: 'month',
          ),
        },
      );

      expect(find.text('PHP 399.00 / month'), findsOneWidget);
    });

    testWidgets('says so plainly when the provider supplied none', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(find.text('Price shown at checkout'), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('paywall-prices-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('Free is free, with no currency invented for it', (
      tester,
    ) async {
      await pumpPaywall(tester);
      expect(find.byKey(const ValueKey('plan-price-free')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('plan-price-free'))).data,
        'Free',
      );
    });

    testWidgets('a price failure still shows the plan comparison', (
      tester,
    ) async {
      await pumpPaywall(tester, pricesFail: true);

      expect(
        find.byKey(const ValueKey('paywall-prices-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // The allowances are accurate regardless of the store.
      expect(find.text('3 AI Looks per month'), findsOneWidget);
    });

    testWidgets('no price literal is compiled into the screen', (tester) async {
      await pumpPaywall(tester);
      // With no provider price, nothing that looks like a price may appear.
      for (final literal in ['399', '899', '2,999', '2999']) {
        expect(
          find.textContaining(literal),
          findsNothing,
          reason: 'a hardcoded price would not be what the store charges',
        );
      }
    });
  });

  group('this screen cannot grant anything', () {
    testWidgets('plan actions are disabled while purchasing is unavailable', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(
        find.byKey(const ValueKey('paywall-purchases-unavailable')),
        findsOneWidget,
      );
      for (final plan in ['plus', 'pro', 'salon_pro']) {
        final button = tester.widget<PrimaryButton>(
          find.byKey(ValueKey('plan-action-$plan')),
        );
        expect(
          button.onPressed,
          isNull,
          reason: '$plan must not offer a button that silently does nothing',
        );
      }
    });

    testWidgets('restore purchases has a seat but is not yet live', (
      tester,
    ) async {
      await pumpPaywall(tester);

      final restore = find.byKey(const ValueKey('paywall-restore-purchases'));
      expect(restore, findsOneWidget);
      final button = tester.widget<TertiaryButton>(restore);
      expect(button.onPressed, isNull);
    });
  });

  group('honest selling', () {
    testWidgets('no urgency, no invented discount, no unlimited claim', (
      tester,
    ) async {
      await pumpPaywall(tester);

      for (final forbidden in [
        'Limited time',
        'limited time',
        'Save ',
        'Was ',
        'Unlimited',
        'unlimited',
        'Most popular',
        'Best value',
        'Ends soon',
        'annual',
        'Annual',
        'trial',
        'lifetime',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: '"$forbidden" is not a real property of these plans',
        );
      }
    });

    testWidgets('no emoji appears anywhere on the screen', (tester) async {
      await pumpPaywall(tester);

      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final data = text.data;
        if (data == null) continue;
        expect(emoji.hasMatch(data), isFalse, reason: 'emoji in "$data"');
      }
    });
  });

  group('accessibility and layout', () {
    testWidgets('each plan card reads as one labelled statement', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(tester, summary: summaryOn(SubscriptionPlanCode.plus));

      expect(
        find.bySemanticsLabel(
          RegExp(r'FaceTune Plus\. Your current plan\. 3 AI Looks per month'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('lays out on POCO X3 GT without overflow', (tester) async {
      await pumpPaywall(tester, size: const Size(393, 873));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a small phone without overflow', (tester) async {
      await pumpPaywall(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives doubled text scale', (tester) async {
      await pumpPaywall(tester, size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
