import 'dart:async';

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
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/plan_action.dart';

SubscriptionSummary summaryOn(
  SubscriptionPlanCode plan, {
  EntitlementStatus status = EntitlementStatus.active,
  bool autoRenew = true,
  int committed = 1,
  String? denialReason,
}) => SubscriptionSummary(
  hasEntitlement: true,
  planCode: plan,
  planDisplayName: 'FaceTune Plus',
  usage: SubscriptionUsageSummary(
    effectiveAllowance: 3,
    committedUsage: committed,
  ),
  // The server never names a refusal it did not make.
  generationAuthorized: denialReason == null,
  resolvedAt: DateTime.utc(2026, 9, 19, 12),
  status: status,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
  resetAt: DateTime.utc(2026, 10, 7),
  autoRenew: autoRenew,
  denialReason: denialReason,
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
  _Prices(this.prices, {this.fails = false, this.gate});
  final Map<SubscriptionPlanCode, PlanPrice> prices;
  final bool fails;

  /// When set, the load does not answer until the test completes it — so the
  /// loading state can be observed instead of flashing past.
  final Completer<void>? gate;

  @override
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices() async {
    await gate?.future;
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
  // Tall enough that every section of the eight-plan paywall is built at
  // once; tests that want a real viewport pass their own size.
  Size size = const Size(393, 7000),
  double textScale = 1.0,
  ThemeData? theme,
  bool reduceMotion = false,
  Completer<void>? pricesGate,
  bool settle = true,
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
          _Prices(prices, fails: pricesFail, gate: pricesGate),
        ),
        purchaseAvailableProvider.overrideWithValue(purchaseAvailable),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: const SubscriptionPage(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  sectionAndUtilityTests();
  stateAndMotionTests();
  hardeningTests();

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
        SubscriptionPlanCode.plusPreview,
        SubscriptionPlanCode.pro,
        SubscriptionPlanCode.proPreview,
        SubscriptionPlanCode.salonPro,
        SubscriptionPlanCode.salonPreview,
      ]);
    });

    testWidgets('each plan states its allowance', (tester) async {
      await pumpPaywall(tester);

      expect(find.text('1 one-time AI Look'), findsOneWidget);
      expect(find.text('3 AI Looks per month'), findsOneWidget);
      expect(find.text('8 AI Looks per month'), findsOneWidget);
      expect(find.text('35 AI Looks per month'), findsOneWidget);
      // The Preview-only siblings count a different unit, and say so.
      expect(find.text('30 Final Preview Credits per month'), findsOneWidget);
      expect(find.text('80 Final Preview Credits per month'), findsOneWidget);
      expect(find.text('350 Final Preview Credits per month'), findsOneWidget);
    });

    testWidgets('both Salon offers name the makeup artist account', (
      tester,
    ) async {
      await pumpPaywall(tester);
      // Salon Pro and Salon Preview: one makeup artist account each.
      expect(find.text('1 Makeup Artist Account'), findsNWidgets(2));
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

    testWidgets('an exhausted subscription is still the current plan', (
      tester,
    ) async {
      // Out of AI Looks is not out of subscription. The plan is still held,
      // so it must not be offered for sale a second time.
      await pumpPaywall(
        tester,
        summary: summaryOn(
          SubscriptionPlanCode.plus,
          committed: 3,
          denialReason: 'AI_LOOK_LIMIT_REACHED',
        ),
        purchaseAvailable: true,
      );

      expect(find.byKey(const ValueKey('plan-current-plus')), findsOneWidget);
      final current = tester.widget<SecondaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(current.onPressed, isNull);
    });

    testWidgets(
      'cancelled but paid through stays current until the verified period ends',
      (tester) async {
        // auto_renew off is a statement about the future, not about now: the
        // period the user paid for is still running, and Google would refuse
        // to sell the same subscription again.
        await pumpPaywall(
          tester,
          summary: summaryOn(SubscriptionPlanCode.plus, autoRenew: false),
          purchaseAvailable: true,
        );

        expect(find.byKey(const ValueKey('plan-current-plus')), findsOneWidget);
        final current = tester.widget<SecondaryButton>(
          find.byKey(const ValueKey('plan-action-plus')),
        );
        expect(current.onPressed, isNull);
      },
    );

    testWidgets(
      'a plan whose verified period has ended can be purchased again',
      (tester) async {
        // The stored status can still read `active` until a verified provider
        // read moves it; the server nonetheless refuses generation on the
        // lapsed period_end. That refusal is what decides "current": an ended
        // plan is history, and its card must sell the plan again rather than
        // sit disabled behind "Your current plan".
        await pumpPaywall(
          tester,
          summary: summaryOn(
            SubscriptionPlanCode.plus,
            status: EntitlementStatus.active,
            denialReason: 'ENTITLEMENT_EXPIRED',
          ),
          purchaseAvailable: true,
          prices: {
            SubscriptionPlanCode.plus: const PlanPrice(
              formattedPrice: '₱399.00',
              currencyCode: 'PHP',
            ),
          },
        );

        expect(find.byKey(const ValueKey('plan-current-plus')), findsNothing);
        expect(find.textContaining('Current plan'), findsNothing);
        final action = tester.widget<PrimaryButton>(
          find.byKey(const ValueKey('plan-action-plus')),
        );
        expect(
          action.onPressed,
          isNotNull,
          reason: 'an ended subscription must be purchasable again',
        );
      },
    );

    testWidgets('a revoked plan can be purchased again', (tester) async {
      await pumpPaywall(
        tester,
        summary: summaryOn(
          SubscriptionPlanCode.plus,
          status: EntitlementStatus.revoked,
          denialReason: 'ENTITLEMENT_REVOKED',
        ),
        purchaseAvailable: true,
        prices: {
          SubscriptionPlanCode.plus: const PlanPrice(
            formattedPrice: '₱399.00',
            currencyCode: 'PHP',
          ),
        },
      );

      expect(find.byKey(const ValueKey('plan-current-plus')), findsNothing);
      final action = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(action.onPressed, isNotNull);
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

      // One per purchasable plan: the three V1 plans and their three
      // Preview-only siblings.
      expect(find.text('Price shown at checkout'), findsNWidgets(6));
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
        expect(
          await planActionOf(tester, plan),
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

  const plusPrice = PlanPrice(
    formattedPrice: 'XTS 1.00',
    currencyCode: 'XTS',
    billingPeriodLabel: 'month',
  );

  group('page lead', () {
    testWidgets('leads with the product promise, as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(tester);

      expect(find.byKey(const ValueKey('paywall-lead')), findsOneWidget);
      expect(
        find.text('Create more looks. Keep every result.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Same FaceTune AI on every plan'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Create more looks. Keep every result.')),
        containsSemantics(isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('uses only the existing rose gradient, with no shadow', (
      tester,
    ) async {
      await pumpPaywall(tester);

      final lead = tester.widget<Container>(
        find.byKey(const ValueKey('paywall-lead')),
      );
      final decoration = lead.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect((decoration.gradient! as LinearGradient).colors, [
        AppColors.roseDark,
        AppColors.rose,
      ]);
      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.xl));
    });

    testWidgets('keeps a white foreground on the fixed ground in dark mode', (
      tester,
    ) async {
      await pumpPaywall(tester, theme: AppTheme.darkTheme);

      final headline = tester.widget<Text>(
        find.text('Create more looks. Keep every result.'),
      );
      expect(headline.style?.color, Colors.white);
    });
  });

  group('plan information hierarchy', () {
    testWidgets('the store amount leads and the period follows, verbatim', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        prices: const {SubscriptionPlanCode.plus: plusPrice},
      );

      final span = _priceSpan(tester, 'plus')!;
      final children = span.children!.cast<TextSpan>();
      expect(children.map((s) => s.text).toList(), ['XTS 1.00', ' / month']);
      // The amount is set in the price role; the period steps back.
      final text = _textThemeOf(tester);
      expect(span.style?.fontSize, text.headlineSmall?.fontSize);
      expect(span.style?.fontWeight, text.headlineSmall?.fontWeight);
      expect(children[1].style?.fontSize, text.bodyMedium?.fontSize);
      expect(
        children[1].style!.fontSize!,
        lessThan(span.style!.fontSize!),
        reason: 'the period must step back from the amount',
      );
      expect(children[1].style?.color, AppColors.taupe);
      // And read as one string, the way the provider's display price reads.
      expect(span.toPlainText(), plusPrice.displayPrice);
    });

    testWidgets('a non-recurring price has no period span', (tester) async {
      await pumpPaywall(
        tester,
        prices: const {
          SubscriptionPlanCode.pro: PlanPrice(
            formattedPrice: 'XTS 5.00',
            currencyCode: 'XTS',
          ),
        },
      );

      final span = _priceSpan(tester, 'pro')!;
      expect(span.toPlainText(), 'XTS 5.00');
      expect(find.textContaining(' / '), findsNothing);
    });

    testWidgets('Free is a plain word in the price role', (tester) async {
      await pumpPaywall(tester);

      final free = tester.widget<Text>(
        find.byKey(const ValueKey('plan-price-free')),
      );
      expect(free.data, 'Free');
      final text = _textThemeOf(tester);
      expect(free.style?.fontSize, text.headlineSmall?.fontSize);
      expect(free.style?.fontWeight, text.headlineSmall?.fontWeight);
    });

    testWidgets('the fallback is not dressed up as a price', (tester) async {
      await pumpPaywall(tester);

      final fallback = tester.widget<Text>(
        find.byKey(const ValueKey('plan-price-plus')),
      );
      expect(fallback.data, 'Price shown at checkout');
      expect(
        fallback.style?.fontSize,
        isNot(AppTheme.lightTheme.textTheme.headlineSmall?.fontSize),
      );
      expect(fallback.style?.color, AppColors.taupe);
    });

    testWidgets('a long localized price survives a small phone at 2x', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        prices: const {
          SubscriptionPlanCode.salonPro: PlanPrice(
            formattedPrice: r'MX$ 1,234,567.89',
            currencyCode: 'MXN',
            billingPeriodLabel: 'month',
          ),
        },
      );
      // The list is lazy and the test font is wide, so Salon Pro's card is
      // below the fold: scroll to it as a user would, then check it laid out.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('plan-price-salon_pro')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(r'MX$ 1,234,567.89 / month'), findsOneWidget);
    });

    testWidgets('every plan puts its allowance on its own tinted row', (
      tester,
    ) async {
      await pumpPaywall(tester);
      final info = AppTheme.lightTheme.extension<AppSemantics>()!.info;

      for (final plan in ['free', 'plus', 'pro', 'salon_pro']) {
        final allowance = find.byKey(ValueKey('plan-allowance-$plan'));
        expect(allowance, findsOneWidget);
        final row = find
            .ancestor(of: allowance, matching: find.byType(Container))
            .first;
        final decoration =
            tester.widget<Container>(row).decoration! as BoxDecoration;
        expect(decoration.color, info.surface);
        expect(decoration.boxShadow, isNull);
        expect(decoration.borderRadius, BorderRadius.circular(AppRadii.sm));
      }
    });

    testWidgets('feature rows render one check per benefit', (tester) async {
      await pumpPaywall(tester);

      final expected = PlanPresentation.comparisonPlans
          .map((plan) => PlanPresentation.features(plan).length)
          .fold<int>(0, (a, b) => a + b);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(expected));
      expect(find.text('Step-by-Step Tutorial included'), findsWidgets);
    });

    testWidgets('accents resolve to the contrast-safe tone per theme', (
      tester,
    ) async {
      await pumpPaywall(tester, theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
      final darkCheck = tester.widget<Icon>(
        find.byIcon(Icons.check_rounded).first,
      );
      expect(darkCheck.color, AppColors.roseLight);

      await pumpPaywall(tester);
      final lightCheck = tester.widget<Icon>(
        find.byIcon(Icons.check_rounded).first,
      );
      expect(lightCheck.color, AppColors.rose);
    });

    testWidgets('the card still reads as one statement, now with its purpose', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.plus),
        prices: const {SubscriptionPlanCode.plus: plusPrice},
      );

      expect(
        find.bySemanticsLabel(
          'FaceTune Plus. Your current plan. 3 AI Looks per month. '
          'Tutorial included with every AI Look. XTS 1.00 / month. '
          'For refining a look you already have in mind.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('purchase wiring is untouched by the new layout', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        purchaseAvailable: true,
        prices: const {SubscriptionPlanCode.plus: plusPrice},
      );

      expect(await planActionOf(tester, 'plus'), isNotNull);
      // Pro has no store product, so it must still be unbuyable.
      expect(await planActionOf(tester, 'pro'), isNull);
    });
  });

  group('plan hierarchy', () {
    const prices = {
      SubscriptionPlanCode.plus: plusPrice,
      SubscriptionPlanCode.pro: PlanPrice(
        formattedPrice: 'XTS 2.00',
        currencyCode: 'XTS',
        billingPeriodLabel: 'month',
      ),
      SubscriptionPlanCode.salonPro: PlanPrice(
        formattedPrice: 'XTS 9.00',
        currencyCode: 'XTS',
        billingPeriodLabel: 'month',
      ),
    };

    AppCard cardOf(WidgetTester tester, String plan) =>
        tester.widget<AppCard>(find.byKey(ValueKey('plan-card-$plan')));

    /// The themed Chip inside a badge, found through the badge's key.
    Chip chipOf(WidgetTester tester, String badgeKey) => tester.widget<Chip>(
      find.descendant(
        of: find.byKey(ValueKey(badgeKey)),
        matching: find.byType(Chip),
      ),
    );

    testWidgets('Free is a quiet card with no badge and no action', (
      tester,
    ) async {
      await pumpPaywall(tester, prices: prices, purchaseAvailable: true);

      expect(cardOf(tester, 'free').emphasized, isFalse);
      expect(find.byKey(const ValueKey('plan-current-free')), findsNothing);
      expect(find.byKey(const ValueKey('plan-recommended-free')), findsNothing);
      expect(find.byKey(const ValueKey('plan-action-free')), findsNothing);
    });

    testWidgets('Plus is recommended: badge, emphasis, and the one primary', (
      tester,
    ) async {
      await pumpPaywall(tester, prices: prices, purchaseAvailable: true);

      expect(
        find.byKey(const ValueKey('plan-recommended-plus')),
        findsOneWidget,
      );
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.byIcon(Icons.recommend_outlined), findsOneWidget);
      expect(cardOf(tester, 'plus').emphasized, isTrue);
      expect(find.byKey(const ValueKey('plan-action-plus')), findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey('plan-action-plus'))),
        isA<PrimaryButton>(),
      );
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('Pro is plain: no badge, outlined action, still buyable', (
      tester,
    ) async {
      await pumpPaywall(tester, prices: prices, purchaseAvailable: true);

      expect(cardOf(tester, 'pro').emphasized, isFalse);
      expect(find.byKey(const ValueKey('plan-recommended-pro')), findsNothing);
      expect(
        tester.widget(find.byKey(const ValueKey('plan-action-pro'))),
        isA<SecondaryButton>(),
      );
      expect(await planActionOf(tester, 'pro'), isNotNull);
      expect(find.text('Choose FaceTune Pro'), findsOneWidget);
    });

    testWidgets('current Free: Free is marked, Plus is still recommended', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: prices,
        purchaseAvailable: true,
      );

      expect(find.byKey(const ValueKey('plan-current-free')), findsOneWidget);
      expect(cardOf(tester, 'free').emphasized, isTrue);
      expect(
        find.byKey(const ValueKey('plan-recommended-plus')),
        findsOneWidget,
      );
      expect(cardOf(tester, 'plus').emphasized, isTrue);
      expect(
        tester.widget(find.byKey(const ValueKey('plan-action-plus'))),
        isA<PrimaryButton>(),
      );
    });

    testWidgets('current Plus: the current badge replaces the recommendation', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.plus),
        prices: prices,
        purchaseAvailable: true,
      );

      expect(find.byKey(const ValueKey('plan-current-plus')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-recommended-plus')), findsNothing);
      expect(find.text('Recommended'), findsNothing);
      expect(cardOf(tester, 'plus').emphasized, isTrue);
      final action = tester.widget<SecondaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(action.onPressed, isNull);
      expect(action.label, 'Your current plan');
      // No plan is drawn as the primary action while the recommended plan is
      // already the account's own.
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('current Pro: Pro is marked and Plus keeps its badge', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.pro),
        prices: prices,
        purchaseAvailable: true,
      );

      expect(find.byKey(const ValueKey('plan-current-pro')), findsOneWidget);
      expect(cardOf(tester, 'pro').emphasized, isTrue);
      expect(await planActionOf(tester, 'pro'), isNull);
      expect(
        find.byKey(const ValueKey('plan-recommended-plus')),
        findsOneWidget,
      );
      expect(cardOf(tester, 'plus').emphasized, isTrue);
      expect(await planActionOf(tester, 'plus'), isNotNull);
      // Exactly one badge per card, never two.
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets(
      'current Salon Pro: marked under its section, Plus still leads',
      (tester) async {
        await pumpPaywall(
          tester,
          summary: summaryOn(SubscriptionPlanCode.salonPro),
          prices: prices,
          purchaseAvailable: true,
        );

        expect(
          find.byKey(const ValueKey('plan-current-salon_pro')),
          findsOneWidget,
        );
        expect(cardOf(tester, 'salon_pro').emphasized, isTrue);
        final action = tester.widget<SecondaryButton>(
          find.byKey(const ValueKey('plan-action-salon_pro')),
        );
        expect(action.onPressed, isNull);
        expect(action.label, 'Your current plan');
        // The professional heading still precedes it, and the consumer
        // recommendation is unchanged: a professional on Salon Pro is not
        // being sold Plus, but the page's structure does not shift under them.
        expect(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('paywall-professional-section')),
              )
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const ValueKey('plan-card-salon_pro')))
                .dy,
          ),
        );
        expect(
          find.byKey(const ValueKey('plan-recommended-plus')),
          findsOneWidget,
        );
        expect(await planActionOf(tester, 'plus'), isNotNull);
        expect(find.byType(Chip), findsNWidgets(2));
      },
    );

    testWidgets('badges carry a glyph and a word, never tint alone', (
      tester,
    ) async {
      await pumpPaywall(tester, summary: summaryOn(SubscriptionPlanCode.pro));

      final current = chipOf(tester, 'plan-current-pro');
      expect(current.avatar, isA<Icon>());
      expect(
        (current.avatar! as Icon).icon,
        Icons.check_circle_outline_rounded,
      );
      expect(current.backgroundColor, isNull, reason: 'a fact, on the card');

      final recommended = chipOf(tester, 'plan-recommended-plus');
      expect(recommended.avatar, isA<Icon>());
      expect((recommended.avatar! as Icon).icon, Icons.recommend_outlined);
      expect(
        recommended.backgroundColor,
        AppTheme.lightTheme.extension<AppSemantics>()!.info.surface,
      );
    });

    testWidgets('dark theme resolves badge and emphasis colours', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        theme: AppTheme.darkTheme,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: prices,
      );
      expect(tester.takeException(), isNull);

      final dark = AppTheme.darkTheme.extension<AppSemantics>()!.info;
      final recommended = chipOf(tester, 'plan-recommended-plus');
      expect(recommended.backgroundColor, dark.surface);
      expect(recommended.labelStyle?.color, dark.onSurface);
      expect((recommended.avatar! as Icon).color, AppColors.roseLight);
    });

    testWidgets('semantics distinguish current from recommended', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: prices,
      );

      final free = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^FaceTune Free\. Your current plan\.')),
      );
      expect(free, containsSemantics(isSelected: true));

      final plus = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^FaceTune Plus\. Recommended\.')),
      );
      expect(plus, isNot(containsSemantics(isSelected: true)));

      expect(
        find.bySemanticsLabel(RegExp(r'Your current plan\. Recommended')),
        findsNothing,
        reason: 'no card claims both states',
      );
      handle.dispose();
    });

    testWidgets('a badge and a long name stack on a small phone at 2x', (
      tester,
    ) async {
      await pumpPaywall(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: prices,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

void hardeningTests() {
  // The fullest page: a current plan, a recommended plan, every price present
  // and one of them long, every action live.
  const fullPrices = {
    SubscriptionPlanCode.plus: PlanPrice(
      formattedPrice: 'XTS 1.00',
      currencyCode: 'XTS',
      billingPeriodLabel: 'month',
    ),
    SubscriptionPlanCode.pro: PlanPrice(
      formattedPrice: 'XTS 2.00',
      currencyCode: 'XTS',
      billingPeriodLabel: 'month',
    ),
    SubscriptionPlanCode.salonPro: PlanPrice(
      formattedPrice: r'MX$ 1,234,567.89',
      currencyCode: 'MXN',
      billingPeriodLabel: 'month',
    ),
  };

  /// Brings [target] into the lazy list's build window.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the page end to end so every lazily built row is laid out.
  Future<void> walkToBottom(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('paywall-restore-purchases')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('responsive matrix', () {
    const viewports = <String, Size>{
      'narrow phone 320': Size(320, 640),
      'POCO X3 GT 393x873': Size(393, 873),
      'large phone 412x915': Size(412, 915),
      'tablet-constrained 1024x1400': Size(1024, 1400),
    };
    final themes = <String, ThemeData>{
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    };

    for (final viewport in viewports.entries) {
      for (final theme in themes.entries) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            '${viewport.key}, ${theme.key}, ${scale}x: no overflow end to end',
            (tester) async {
              await pumpPaywall(
                tester,
                size: viewport.value,
                theme: theme.value,
                textScale: scale,
                summary: summaryOn(SubscriptionPlanCode.free),
                prices: fullPrices,
                purchaseAvailable: true,
              );
              // The list is lazy, so each critical row is checked while it
              // is on screen, then the walk continues to the end.
              await scrollTo(tester, find.text(r'MX$ 1,234,567.89 / month'));
              expect(find.text('35 AI Looks per month'), findsOneWidget);
              await scrollTo(
                tester,
                find.byKey(const ValueKey('paywall-ai-look-info')),
              );
              await walkToBottom(tester);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('a wide screen keeps the readable column, not a wide card', (
      tester,
    ) async {
      await pumpPaywall(tester, size: const Size(1024, 1400));

      final card = tester.getSize(find.byKey(const ValueKey('plan-card-free')));
      expect(card.width, PageFrame.defaultMaxWidth - 2 * AppSpacing.gutter);
      final lead = tester.getSize(find.byKey(const ValueKey('paywall-lead')));
      expect(lead.width, card.width);
    });

    testWidgets('critical text is never truncated', (tester) async {
      await pumpPaywall(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: fullPrices,
      );

      void neverTruncated(String key) {
        final text = tester.widget<Text>(find.byKey(ValueKey(key)));
        expect(text.maxLines, isNull, reason: '$key must be free to wrap');
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: key);
        expect(text.softWrap, isNot(false), reason: key);
      }

      await scrollTo(tester, find.byKey(const ValueKey('plan-allowance-free')));
      neverTruncated('plan-allowance-free');
      await scrollTo(tester, find.byKey(const ValueKey('plan-price-plus')));
      neverTruncated('plan-price-plus');
      await scrollTo(
        tester,
        find.byKey(const ValueKey('plan-price-salon_pro')),
      );
      neverTruncated('plan-price-salon_pro');
      neverTruncated('plan-allowance-salon_pro');
      expect(find.byType(FittedBox), findsNothing);
    });

    // One pump per test on purpose: pumping the page twice in one test
    // updates the same element tree, and the scroll position survives it.
    for (final scale in [1.0, 2.0]) {
      testWidgets('actions keep their touch size at ${scale}x', (tester) async {
        await pumpPaywall(
          tester,
          size: const Size(320, 640),
          textScale: scale,
          prices: fullPrices,
          purchaseAvailable: true,
        );
        for (final key in [
          'plan-action-plus',
          'plan-action-pro',
          'plan-action-salon_pro',
          'paywall-restore-purchases',
        ]) {
          await scrollTo(tester, find.byKey(ValueKey(key)));
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.height, greaterThanOrEqualTo(48), reason: key);
          expect(size.width, greaterThanOrEqualTo(48), reason: key);
        }
      });
    }
  });

  group('semantics coherence', () {
    testWidgets('the purchase action is a reachable, labelled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(tester, prices: fullPrices, purchaseAvailable: true);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Choose FaceTune Plus')),
        containsSemantics(
          label: 'Choose FaceTune Plus',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Choose FaceTune Pro')),
        containsSemantics(label: 'Choose FaceTune Pro', isButton: true),
      );
      handle.dispose();
    });

    testWidgets(
      'the current plan is one selected statement plus a disabled button',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpPaywall(
          tester,
          summary: summaryOn(SubscriptionPlanCode.plus),
          prices: fullPrices,
          purchaseAvailable: true,
        );

        expect(
          tester.getSemantics(
            find.bySemanticsLabel(
              RegExp(
                r'^FaceTune Plus\. Your current plan\. 3 AI Looks per month',
              ),
            ),
          ),
          containsSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Your current plan')),
          containsSemantics(
            label: 'Your current plan',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('a recommended plan is never announced as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(
        tester,
        summary: summaryOn(SubscriptionPlanCode.free),
        prices: fullPrices,
      );

      // Neither the description, nor the card's own node, nor the list.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(RegExp(r'^FaceTune Plus\. Recommended\.')),
        ),
        isNot(containsSemantics(isSelected: true)),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('plan-card-plus'))),
        isNot(containsSemantics(isSelected: true)),
      );
      expect(
        tester.getSemantics(find.byType(ListView)),
        isNot(containsSemantics(isSelected: true)),
      );
      handle.dispose();
    });

    testWidgets('Restore purchases is a labelled, disabled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(tester);
      await walkToBottom(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Restore purchases')),
        containsSemantics(
          label: 'Restore purchases',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('decoration stays out of the semantics tree', (tester) async {
      await pumpPaywall(tester, summary: summaryOn(SubscriptionPlanCode.free));

      // Icons on the page carry no semantic label of their own: the plan
      // glyphs, checks, allowance mark and badge avatars sit inside the
      // described statement, and the lead glyph is decoration.
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.semanticLabel, isNull);
      }
    });
  });
}

void stateAndMotionTests() {
  group('state slots and motion', () {
    /// The switcher inside a state slot, by the slot's key.
    AnimatedSwitcher switcherOf(WidgetTester tester, String slot) =>
        tester.widget<AnimatedSwitcher>(
          find.descendant(
            of: find.byKey(ValueKey(slot)),
            matching: find.byType(AnimatedSwitcher),
          ),
        );

    testWidgets('prices loading is a LoadingState until the store answers', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpPaywall(tester, pricesGate: gate, settle: false);

      expect(
        find.byKey(const ValueKey('paywall-prices-loading')),
        findsOneWidget,
      );
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Loading plan prices…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paywall-prices-unavailable')),
        findsNothing,
      );
      // The plans are already comparable while prices load.
      expect(find.byKey(const ValueKey('plan-card-plus')), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('paywall-prices-loading')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('paywall-prices-unavailable')),
        findsOneWidget,
        reason: 'an empty answer is the honest "unavailable" state',
      );
    });

    testWidgets('a price failure is the AppNotice with a retry', (
      tester,
    ) async {
      await pumpPaywall(tester, pricesFail: true);

      final notice = tester.widget<AppNotice>(
        find.descendant(
          of: find.byKey(const ValueKey('paywall-prices-unavailable')),
          matching: find.byType(AppNotice),
        ),
      );
      expect(notice.title, 'Prices are not available right now');
      expect(find.text('Try again'), findsOneWidget);
      // Guidance, not the result of a user action: it does not interrupt.
      expect(notice.liveRegion, isFalse);
    });

    testWidgets('purchase unavailable is the store notice, disabled actions', (
      tester,
    ) async {
      await pumpPaywall(tester, purchaseAvailable: false);

      expect(
        find.byKey(const ValueKey('paywall-purchases-unavailable')),
        findsOneWidget,
      );
      for (final plan in ['plus', 'pro', 'salon_pro']) {
        expect(await planActionOf(tester, plan), isNull);
      }
      // Nothing is spinning: unavailable is a settled state.
      expect(find.byType(ButtonProgress), findsNothing);
      expect(find.byType(AppProgress), findsNothing);
    });

    testWidgets('slots animate with the global duration and curves', (
      tester,
    ) async {
      await pumpPaywall(tester);

      for (final slot in ['paywall-price-slot', 'paywall-purchase-slot']) {
        final switcher = switcherOf(tester, slot);
        expect(switcher.duration, AppDurations.standard);
        expect(switcher.switchInCurve, AppCurves.decelerate);
        expect(switcher.switchOutCurve, AppCurves.accelerate);
        final size = tester.widget<AnimatedSize>(
          find.descendant(
            of: find.byKey(ValueKey(slot)),
            matching: find.byType(AnimatedSize),
          ),
        );
        expect(size.duration, AppDurations.standard);
        expect(size.curve, AppCurves.standard);
      }
      // The badge slot uses the quick step.
      final badge = tester.widget<AnimatedSwitcher>(
        find
            .descendant(
              of: find.byKey(const ValueKey('plan-card-plus')),
              matching: find.byType(AnimatedSwitcher),
            )
            .first,
      );
      expect(badge.duration, AppDurations.quick);
    });

    testWidgets('reduced motion collapses every transition to zero', (
      tester,
    ) async {
      await pumpPaywall(tester, reduceMotion: true);

      // The slots drop their animation widgets entirely — a zero-duration
      // AnimatedSize would mutate itself during layout, so "off" means off.
      for (final slot in ['paywall-price-slot', 'paywall-purchase-slot']) {
        expect(find.byKey(ValueKey(slot)), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey(slot)),
            matching: find.byType(AnimatedSize),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(ValueKey(slot)),
            matching: find.byType(AnimatedSwitcher),
          ),
          findsNothing,
        );
      }
      // Every badge slot too. (Material's own Chip carries an internal
      // AnimatedSwitcher for its avatar; that one is the framework's, not the
      // page's, and is not asserted here.)
      for (final plan in ['free', 'plus', 'pro', 'salon_pro']) {
        final badgeSlot = tester.widget<AnimatedSwitcher>(
          find
              .descendant(
                of: find.byKey(ValueKey('plan-card-$plan')),
                matching: find.byType(AnimatedSwitcher),
              )
              .first,
        );
        expect(badgeSlot.duration, Duration.zero);
      }
      // And the page is still complete and correct without any of it.
      expect(
        find.byKey(const ValueKey('plan-recommended-plus')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('paywall-prices-unavailable')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no decorative animation runs on a settled page', (
      tester,
    ) async {
      // pumpAndSettle inside pumpPaywall would time out if anything looped.
      await pumpPaywall(
        tester,
        prices: const {
          SubscriptionPlanCode.plus: PlanPrice(
            formattedPrice: 'XTS 1.00',
            currencyCode: 'XTS',
            billingPeriodLabel: 'month',
          ),
        },
        purchaseAvailable: true,
      );
      expect(find.byType(ButtonProgress), findsNothing);
      expect(find.byType(AppProgress), findsNothing);
      expect(find.byType(SkeletonCard), findsNothing);
    });
  });
}

void sectionAndUtilityTests() {
  group('professional section and page tail', () {
    double topOf(WidgetTester tester, Key key) =>
        tester.getTopLeft(find.byKey(key)).dy;

    testWidgets(
      'consumer plans, then the professional heading, then the Salon pair',
      (tester) async {
        await pumpPaywall(tester);

        const heading = ValueKey('paywall-professional-section');
        expect(find.byKey(heading), findsOneWidget);
        expect(find.text('For makeup professionals'), findsOneWidget);

        final headingTop = topOf(tester, heading);
        for (final plan in ['free', 'plus', 'pro']) {
          expect(
            topOf(tester, ValueKey('plan-card-$plan')),
            lessThan(headingTop),
            reason: '$plan is a consumer plan and sits above the heading',
          );
        }
        for (final plan in ['salon_pro', 'salon_preview']) {
          expect(
            topOf(tester, ValueKey('plan-card-$plan')),
            greaterThan(headingTop),
            reason: '$plan is a professional plan and sits below the heading',
          );
        }
        // The Preview-only consumer plans have a heading of their own, above
        // the professional one and below the Tutorial-enabled plans.
        final previewHeadingTop = topOf(
          tester,
          const ValueKey('paywall-previewOnly-section'),
        );
        expect(
          previewHeadingTop,
          greaterThan(topOf(tester, const ValueKey('plan-card-pro'))),
        );
        expect(
          previewHeadingTop,
          lessThan(topOf(tester, const ValueKey('plan-card-plus_preview'))),
        );
        expect(
          headingTop,
          greaterThan(topOf(tester, const ValueKey('plan-card-pro_preview'))),
        );
        // Exactly the Salon pair is professional, and no second list of plans
        // anywhere: the sections are derived from the presentation contract.
        expect(
          PlanPresentation.comparisonPlans
              .where(
                (plan) =>
                    PlanPresentation.emphasis(plan) ==
                    PlanEmphasis.professional,
              )
              .toList(),
          [SubscriptionPlanCode.salonPro, SubscriptionPlanCode.salonPreview],
        );
      },
    );

    testWidgets('the heading is a header and claims nothing invented', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPaywall(tester);

      expect(
        tester.getSemantics(find.text('For makeup professionals')),
        containsSemantics(isHeader: true),
      );
      expect(
        find.text(
          'A larger monthly pool for one makeup artist account, with the '
          'Tutorial or without it.',
        ),
        findsOneWidget,
      );
      for (final invented in [
        'client management',
        'clients per month',
        'seats',
        'licence',
        'license',
        'priority support',
        'commercial',
      ]) {
        expect(find.textContaining(invented), findsNothing);
      }
      handle.dispose();
    });

    testWidgets('Salon Pro stays a plain AppCard in the shared system', (
      tester,
    ) async {
      await pumpPaywall(tester);

      final card = tester.widget<AppCard>(
        find.byKey(const ValueKey('plan-card-salon_pro')),
      );
      expect(card.color, isNull, reason: 'no black/gold or any other theme');
      expect(card.emphasized, isFalse);
      expect(find.text('1 Makeup Artist Account'), findsNWidgets(2));
      expect(find.text('35 AI Looks per month'), findsOneWidget);
    });

    testWidgets('the AI Look explanation is an AppNotice with accurate copy', (
      tester,
    ) async {
      await pumpPaywall(tester);

      final notice = find.byKey(const ValueKey('paywall-ai-look-info'));
      expect(notice, findsOneWidget);
      expect(tester.widget(notice), isA<AppNotice>());
      expect(
        find.text('What counts as an AI Look or a Final Preview Credit'),
        findsOneWidget,
      );
      // The notice draws the one line that separates the two units.
      expect(
        find.textContaining('a Final Preview Credit does not'),
        findsOneWidget,
      );
      expect(
        find.textContaining('finished Final Makeup Preview'),
        findsOneWidget,
      );
      expect(find.textContaining('never uses another'), findsOneWidget);
      expect(find.textContaining('nothing is used'), findsOneWidget);
      // Internal vocabulary stays internal.
      for (final internal in [
        'operation',
        'reserv',
        'ledger',
        'token',
        // 'credit' is no longer internal vocabulary: "Final Preview Credit"
        // is the user-facing unit of the Preview-only plans.
        'cost',
      ]) {
        expect(
          find.textContaining(internal),
          findsNothing,
          reason: '"$internal" is implementation language',
        );
      }
    });

    testWidgets('the tail reads notice first, then the restore utility', (
      tester,
    ) async {
      await pumpPaywall(tester);

      final noticeTop = topOf(tester, const ValueKey('paywall-ai-look-info'));
      final restoreTop = topOf(
        tester,
        const ValueKey('paywall-restore-purchases'),
      );
      expect(
        topOf(tester, const ValueKey('plan-card-salon_pro')),
        lessThan(noticeTop),
      );
      expect(noticeTop, lessThan(restoreTop));
    });

    testWidgets('restore is a secondary, inline, still-disabled utility', (
      tester,
    ) async {
      await pumpPaywall(tester, purchaseAvailable: true);

      final restore = find.byKey(const ValueKey('paywall-restore-purchases'));
      final button = tester.widget<TertiaryButton>(restore);
      expect(button.onPressed, isNull, reason: 'callback preserved: not live');
      expect(button.icon, Icons.restore_rounded);
      expect(button.expand, isFalse);
      // Inline: narrower than the column it sits in, not stretched across it.
      expect(
        tester.getSize(restore).width,
        lessThan(tester.getSize(find.byType(ListView)).width),
      );
    });

    testWidgets('the page tail lays out on a small phone at 2x', (
      tester,
    ) async {
      await pumpPaywall(tester, size: const Size(320, 640), textScale: 2);
      // Eight cards at 2x on a 640-point screen is a long way down.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('paywall-restore-purchases')),
        400,
        maxScrolls: 400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('paywall-ai-look-info')),
        findsOneWidget,
      );
    });
  });
}

/// The text theme as the page actually resolved it. `MaterialApp` applies
/// script geometry at runtime, so the static `AppTheme` styles carry no font
/// size for the roles `AppTypography` leaves at Material's default.
TextTheme _textThemeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(SubscriptionPage))).textTheme;

/// The `TextSpan` tree behind a plan's price, or null where the price is a
/// plain `Text` (Free, and the store-silent fallback).
TextSpan? _priceSpan(WidgetTester tester, String plan) {
  final text = tester.widget<Text>(find.byKey(ValueKey('plan-price-$plan')));
  return text.textSpan as TextSpan?;
}
