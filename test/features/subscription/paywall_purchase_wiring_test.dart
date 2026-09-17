import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/plan_price.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/store_product.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/presentation/pages/subscription_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_billing.dart';
import '../../helpers/plan_action.dart';

/// The SUB-8 paywall driven by a real (faked) billing provider.
///
/// The paywall's own tests cover its copy, layout, and honesty rules. These
/// cover the seam SUB-9 added: which plan actions become live, what a tap
/// actually does, and — most importantly — that a completed provider purchase
/// still changes nothing on screen until a server has verified it.
class _NoSubscription implements SubscriptionRepository {
  @override
  Future<SubscriptionSummary> resolve() async =>
      throw const SubscriptionStateFailure('no subscription');
}

const _plusPrice = PlanPrice(
  formattedPrice: 'XTS 1.00',
  currencyCode: 'XTS',
  billingPeriodLabel: 'month',
);

const _plusProduct = StoreProduct(
  planCode: SubscriptionPlanCode.plus,
  providerProductId: 'facetune_plus',
  price: _plusPrice,
);

Future<FakeStoreBillingGateway> pumpPaywall(
  WidgetTester tester, {
  bool storeAvailable = true,
  List<StoreProduct> products = const [_plusProduct],
  Object? verificationFailure,
}) async {
  final auth = FakeAuthRepository(
    user: const AuthUser(
      id: 'account-uuid',
      email: 'mia@example.com',
      displayName: 'Mia Chen',
      isAnonymous: false,
    ),
  );
  addTearDown(auth.dispose);

  final store = FakeStoreBillingGateway(
    available: storeAvailable,
    products: products,
  );
  addTearDown(store.dispose);

  tester.view.physicalSize = const Size(393, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(_NoSubscription()),
        // The real gateway and the real price source, over a fake provider —
        // so the wiring under test is the production wiring.
        storeBillingGatewayProvider.overrideWithValue(store),
        purchaseVerificationGatewayProvider.overrideWithValue(
          FakePurchaseVerificationGateway(failure: verificationFailure),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SubscriptionPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Pumps through the state transition and its motion, without waiting for
/// the page to go still — it will not, because an in-flight purchase draws an
/// indeterminate spinner on its plan's button for as long as it is open.
Future<void> settleInFlight(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDurations.slow);
  await tester.pump(AppDurations.slow);
}

void main() {
  group('provider metadata feeds the paywall', () {
    testWidgets('a store price is shown verbatim on its plan card', (
      tester,
    ) async {
      await pumpPaywall(tester);

      expect(find.text('XTS 1.00 / month'), findsOneWidget);
    });

    testWidgets('a plan the store priced offers a live action', (tester) async {
      await pumpPaywall(tester);

      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a plan the store did not return stays unbuyable', (
      tester,
    ) async {
      // Pro and Salon Pro have no product in this fixture. Their buttons must
      // not be live: there is nothing to buy, and an enabled button could only
      // fail.
      await pumpPaywall(tester);

      for (final plan in ['pro', 'salon_pro']) {
        expect(
          planActionOf(tester, plan),
          isNull,
          reason: '$plan has no store product in this fixture',
        );
        expect(find.text('Price shown at checkout'), findsWidgets);
      }
    });

    testWidgets('an unavailable store disables every plan action', (
      tester,
    ) async {
      await pumpPaywall(tester, storeAvailable: false, products: const []);

      expect(
        find.byKey(const ValueKey('paywall-purchases-unavailable')),
        findsOneWidget,
      );
      for (final plan in ['plus', 'pro', 'salon_pro']) {
        expect(planActionOf(tester, plan), isNull);
      }
    });

    // Restore was a disabled seat until SUB-11 gave it a server-side
    // reconciliation path to call. It is now live, and is covered by its own
    // group at the end of this file.
  });

  group('tapping a plan starts a provider purchase and nothing else', () {
    testWidgets('the provider flow is opened for that plan only', (
      tester,
    ) async {
      final store = await pumpPaywall(tester);

      await tester.tap(find.byKey(const ValueKey('plan-action-plus')));
      await settleInFlight(tester);

      expect(store.started, [SubscriptionPlanCode.plus]);
      // The account id travels as an opaque identifier, never an email.
      expect(store.accountIds, ['account-uuid']);
      expect(store.accountIds.single, isNot(contains('@')));
    });

    testWidgets(
      'while opening, that plan shows progress and refuses a second tap',
      (tester) async {
        final store = await pumpPaywall(tester);

        await tester.tap(find.byKey(const ValueKey('plan-action-plus')));
        await settleInFlight(tester);

        // The tapped plan's button: spinner, in-progress wording, disabled.
        final plus = tester.widget<PrimaryButton>(
          find.byKey(const ValueKey('plan-action-plus')),
        );
        expect(plus.isLoading, isTrue);
        expect(plus.label, 'Opening Google Play…');
        expect(find.byType(ButtonProgress), findsOneWidget);
        // Other plans keep their own wording and show no progress.
        expect(find.text('Choose FaceTune Pro'), findsOneWidget);
        // Mid-purchase is not "purchasing is not available yet".
        expect(
          find.byKey(const ValueKey('paywall-purchases-unavailable')),
          findsNothing,
        );

        // A second tap — impatient or accidental — starts nothing.
        await tester.tap(
          find.byKey(const ValueKey('plan-action-plus')),
          warnIfMissed: false,
        );
        await settleInFlight(tester);
        expect(store.started, [SubscriptionPlanCode.plus]);
      },
    );

    testWidgets(
      'Salon Pro, under its own section, buys through the same path',
      (tester) async {
        const salonProduct = StoreProduct(
          planCode: SubscriptionPlanCode.salonPro,
          providerProductId: 'facetune_salon_pro',
          price: PlanPrice(
            formattedPrice: 'XTS 9.00',
            currencyCode: 'XTS',
            billingPeriodLabel: 'month',
          ),
        );
        final store = await pumpPaywall(
          tester,
          products: const [_plusProduct, salonProduct],
        );

        // Below the fold on this viewport; reach it the way a user would.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('plan-action-salon_pro')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('plan-action-salon_pro')));
        await settleInFlight(tester);

        expect(store.started, [SubscriptionPlanCode.salonPro]);
      },
    );

    testWidgets('a paid purchase is not shown as a granted plan', (
      tester,
    ) async {
      // Verification is unavailable in this build, so a completed Google Play
      // purchase must leave the screen claiming nothing.
      final store = await pumpPaywall(
        tester,
        verificationFailure: const SubscriptionStateFailure(
          'Purchases cannot be confirmed yet.',
          kind: SubscriptionStateFailureKind.unavailable,
          retryable: false,
        ),
      );

      store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.purchased,
          awaitingCompletion: true,
          planCode: SubscriptionPlanCode.plus,
          evidence: PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_plus',
            purchaseToken: 'super-secret-provider-token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('paywall-purchase-status')),
        findsOneWidget,
      );
      expect(find.text('Purchase not completed'), findsOneWidget);
      // No plan is claimed, and the purchase was never acknowledged.
      expect(find.textContaining('Current plan'), findsNothing);
      expect(store.completed, isEmpty);
    });

    testWidgets('the purchase token never reaches the screen', (tester) async {
      final store = await pumpPaywall(
        tester,
        verificationFailure: const SubscriptionStateFailure('nope'),
      );

      store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.purchased,
          awaitingCompletion: true,
          planCode: SubscriptionPlanCode.plus,
          evidence: PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_plus',
            purchaseToken: 'super-secret-provider-token',
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('super-secret')));
      }
    });

    testWidgets('a pending purchase says it is waiting, not that it worked', (
      tester,
    ) async {
      final store = await pumpPaywall(tester);

      store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.pending,
          awaitingCompletion: false,
          planCode: SubscriptionPlanCode.plus,
        ),
      );
      await settleInFlight(tester);

      expect(find.text('Waiting for Google Play'), findsOneWidget);
      // The notice is the result of the user's action, so it is announced.
      final notice = tester.widget<AppNotice>(
        find.descendant(
          of: find.byKey(const ValueKey('paywall-purchase-status')),
          matching: find.byType(AppNotice),
        ),
      );
      expect(notice.liveRegion, isTrue);
      // And the pending plan's own button says the same thing.
      final plus = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('plan-action-plus')),
      );
      expect(plus.isLoading, isTrue);
      expect(plus.label, 'Waiting for Google Play…');
      expect(find.textContaining('Current plan'), findsNothing);
    });

    testWidgets('a cancelled purchase leaves no alarming message', (
      tester,
    ) async {
      final store = await pumpPaywall(tester);

      store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.cancelled,
          awaitingCompletion: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('paywall-purchase-status')),
        findsNothing,
      );
    });
  });

  group('restore purchases is wired to the verification path', () {
    testWidgets('the action is live once the store is usable', (tester) async {
      await pumpPaywall(tester);

      final restore = tester.widget<TertiaryButton>(
        find.byKey(const ValueKey('paywall-restore-purchases')),
      );
      expect(restore.onPressed, isNotNull);
      expect(restore.label, 'Restore purchases');
    });

    testWidgets('an unusable store leaves it disabled', (tester) async {
      // Nothing to query, so an enabled button could only fail.
      await pumpPaywall(tester, storeAvailable: false);

      final restore = tester.widget<TertiaryButton>(
        find.byKey(const ValueKey('paywall-restore-purchases')),
      );
      expect(restore.onPressed, isNull);
    });

    testWidgets('tapping it asks the provider, and grants nothing on its own', (
      tester,
    ) async {
      final store = await pumpPaywall(tester);

      await tester.tap(find.byKey(const ValueKey('paywall-restore-purchases')));
      await settleInFlight(tester);
      // Past the window the controller gives Google Play to answer, so the
      // "nothing found" path resolves inside the test rather than leaving a
      // timer behind.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(store.restoreCount, 1);
      // The page still shows no plan as current: what the account has comes
      // from the server, and nothing has been verified here.
      expect(find.textContaining('Current plan'), findsNothing);
    });

    testWidgets('a restored purchase is verified before it is acknowledged', (
      tester,
    ) async {
      final store = await pumpPaywall(tester);

      store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.restored,
          awaitingCompletion: true,
          planCode: SubscriptionPlanCode.plus,
          evidence: PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_plus',
            purchaseToken: 'restored-token',
          ),
        ),
      );
      await settleInFlight(tester);

      expect(store.completed.single.purchaseToken, 'restored-token');
      expect(find.text('Purchase confirmed'), findsOneWidget);
    });
  });
}
